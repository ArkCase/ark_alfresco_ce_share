###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/alfresco-ce-share:7.3.1 .
#
# How to run: (Docker)
# docker compose -f docker-compose.yml up -d
#
#
###########################################################################################################

ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="7.3.1"
ARG JAVA="11"
ARG PKG="alfresco-share"
ARG APP_USER="alfresco"
ARG APP_UID="33000"
ARG APP_GROUP="${APP_USER}"
ARG APP_GID="1000"

ARG ALFRESCO_REPO="docker.io/alfresco/alfresco-share"
ARG ALFRESCO_IMG="${ALFRESCO_REPO}:${VER}"

ARG RM_REPO="arkcase/alfresco-ce-rm"
ARG RM_VER="${VER}"
ARG RM_IMG="${PUBLIC_REGISTRY}/${RM_REPO}:${RM_VER}"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-java"
ARG BASE_VER="22.04"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

ARG BASE_TOMCAT_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_TOMCAT_REPO="arkcase/base-tomcat"
ARG BASE_TOMCAT_VER="9"
ARG BASE_TOMCAT_IMG="${BASE_TOMCAT_REGISTRY}/${BASE_TOMCAT_REPO}:${BASE_VER_PFX}${BASE_TOMCAT_VER}"

# Used to copy artifacts
FROM "${ALFRESCO_IMG}" AS alfresco-src

ARG RM_IMG

FROM "${RM_IMG}" AS rm-src

ARG BASE_TOMCAT_IMG

FROM "${BASE_TOMCAT_IMG}" AS tomcat-src

ARG BASE_IMG

# Final Image
FROM "${BASE_IMG}"

ARG ARCH
ARG OS
ARG VER
ARG JAVA
ARG PKG
ARG APP_USER
ARG APP_UID
ARG APP_GROUP
ARG APP_GID

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Alfresco Share" \
      VERSION="${VER}"

ENV JAVA_MAJOR="${JAVA}" \
    CATALINA_HOME="/usr/local/tomcat"
ENV TOMCAT_NATIVE_LIBDIR="${CATALINA_HOME}/native-jni-lib"
ENV LD_LIBRARY_PATH="${TOMCAT_NATIVE_LIBDIR}"
ENV PATH="${CATALINA_HOME}/bin:${PATH}"

RUN set-java "${JAVA}" && \
    apt-get -y install \
        fontconfig \
        fonts-dejavu \
        language-pack-en \
        libapr1 \
        libfreetype6 \
        libpng-tools \
      && \
    apt-get clean && \
    mkdir -p "${CATALINA_HOME}" && \
    mkdir -p "${TOMCAT_NATIVE_LIBDIR}" && \
    groupadd -g "${APP_GID}" "${APP_GROUP}" && \
    useradd -u "${APP_UID}" -g "${APP_GROUP}" -G "${ACM_GROUP}" -m "${APP_USER}"

WORKDIR "${CATALINA_HOME}"
ARG RM_AMP="/alfresco-governance-services-community-share.amp"
COPY --from=rm-src /alfresco-governance-services-community-share-*.amp "${RM_AMP}"
COPY --from=alfresco-src --chown="${APP_USER}:${APP_GROUP}" "${CATALINA_HOME}" "${CATALINA_HOME}"
COPY --from=tomcat-src --chown="${APP_USER}:${APP_GROUP}" --chmod="0755" "/app/tomcat/lib/native/${JAVA_MAJOR}" "${TOMCAT_NATIVE_LIBDIR}.new"

COPY --chown=root:root --chmod=0755 entrypoint /entrypoint
COPY --chown="${APP_USER}:${APP_GROUP}" "server.xml" "${CATALINA_HOME}/conf/server.xml"

RUN rm -rf "${TOMCAT_NATIVE_LIBDIR}" && \
    mv -vf "${TOMCAT_NATIVE_LIBDIR}.new" "${TOMCAT_NATIVE_LIBDIR}"

USER "${APP_USER}"
ENV TOMCAT_DIR="${CATALINA_HOME}"

ENV RM_AMP="${RM_AMP}"
RUN java -jar "${TOMCAT_DIR}/alfresco-mmt"/alfresco-mmt*.jar \
        install "${RM_AMP}" \
        "${TOMCAT_DIR}/webapps/share" -nobackup && \
    java -jar "${TOMCAT_DIR}/alfresco-mmt"/alfresco-mmt*.jar list  "${TOMCAT_DIR}/webapps/share" && \
    ( catalina.sh configtest 2>&1 | grep -q 'Loaded Apache Tomcat Native library' )

COPY --chown="${APP_USER}:${APP_GROUP}" shared/ "${TOMCAT_DIR}/shared/"

EXPOSE 8443
ENTRYPOINT [ "/entrypoint" ]
