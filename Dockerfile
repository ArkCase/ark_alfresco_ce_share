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
ARG BASE_REPO="arkcase/base"
ARG BASE_TAG="8.8-01"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="7.3.1"
ARG BLD="03"
ARG PKG="alfresco-share"
ARG ALFRESCO_SRC="docker.io/alfresco/alfresco-share"
ARG RM_VER="${VER}"
ARG RM_SRC="arkcase/alfresco-ce-rm"
ARG APP_USER="alfresco"
ARG APP_UID="33000"
ARG APP_GROUP="${APP_USER}"
ARG APP_GID="1000"

# Used to copy artifacts
FROM "${ALFRESCO_SRC}:${VER}" AS alfresco-src

ARG PUBLIC_REGISTRY
ARG RM_SRC
ARG RM_VER

FROM "${PUBLIC_REGISTRY}/${RM_SRC}:${RM_VER}" AS rm-src

ARG PUBLIC_REGISTRY
ARG BASE_REPO
ARG BASE_TAG

# Final Image
FROM "${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_TAG}"

ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG ALFRESCO_SRC
ARG RM_VER
ARG APP_USER
ARG APP_UID
ARG APP_GROUP
ARG APP_GID

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Alfresco Share" \
      VERSION="${VER}"

ENV JAVA_HOME="/usr/lib/jvm/jre-11-openjdk" \
    JAVA_MAJOR="11" \
    CATALINA_HOME="/usr/local/tomcat" \
    TOMCAT_NATIVE_LIBDIR="${CATALINA_HOME}/native-jni-lib" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${TOMCAT_NATIVE_LIBDIR}" \
    PATH="${CATALINA_HOME}/bin:${PATH}"

RUN yum -y update && \
    yum install -y \
        apr \
        dejavu-fonts-common \
        dejavu-sans-fonts \
        fontconfig \
        fontpackages-filesystem \
        freetype \
        java-${JAVA_MAJOR}-openjdk-devel \
        langpacks-en \
        libpng \
    && \
    yum -y clean all && \
    mkdir -p "${CATALINA_HOME}" && \
    mkdir -p "${TOMCAT_NATIVE_LIBDIR}" && \
    groupadd -g "${APP_GID}" "${APP_GROUP}" && \
    useradd -u "${APP_UID}" -g "${APP_GROUP}" -G "${ACM_GROUP}" "${APP_USER}"

WORKDIR "${CATALINA_HOME}"
COPY --from=alfresco-src "${CATALINA_HOME}" "${CATALINA_HOME}"
COPY --from=rm-src /alfresco-governance-services-community-share-*.amp /alfresco-governance-services-community-share.amp
COPY entrypoint /entrypoint
COPY --chown="${APP_USER}:${APP_GROUP}" "server.xml" "${CATALINA_HOME}/conf/server.xml"

RUN chown -R "${APP_USER}:" "${CATALINA_HOME}"
RUN chmod 0755 /entrypoint

USER "${APP_USER}"
ENV JAVA_HOME="/usr/lib/jvm/jre-11-openjdk" \
    JAVA_MAJOR="11" \
    CATALINA_HOME="/usr/local/tomcat" \
    TOMCAT_NATIVE_LIBDIR="${CATALINA_HOME}/native-jni-lib" \
    TOMCAT_DIR="${CATALINA_HOME}" \
    LD_LIBRARY_PATH="${CATALINA_HOME}/native-jni-lib" \
    PATH="${CATALINA_HOME}/bin:${PATH}"

RUN java -jar "${TOMCAT_DIR}/alfresco-mmt"/alfresco-mmt*.jar \
        install "/alfresco-governance-services-community-share.amp" \
        "${TOMCAT_DIR}/webapps/share" -nobackup && \
    NATIVE="$(catalina.sh configtest 2>&1 | grep -c 'Loaded Apache Tomcat Native library')" && \
    test $NATIVE -ge 1 || exit 1 && \
    java -jar "${TOMCAT_DIR}/alfresco-mmt"/alfresco-mmt*.jar list  "${TOMCAT_DIR}/webapps/share"

EXPOSE 8000 
ENTRYPOINT [ "/entrypoint" ]
