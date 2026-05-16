#!/bin/bash

set -euo pipefail
. /.functions

set_or_default SHARED_CONFIG_XML "/usr/local/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml"

is_file_writable "${SHARED_CONFIG_XML}" || fail "The CSRF configuration file [${SHARED_CONFIG_XML}] is not writable"

#
# Final configurations for CSRF
#
set_or_default REPO_SCHEME "http"
export REPO_SCHEME

set_or_default REPO_HOST "localhost"
export REPO_HOST

set_or_default REPO_PORT "8080"
export REPO_PORT

set_or_default CSRF_FILTER_REFERER
export CSRF_FILTER_REFERER

set_or_default CSRF_FILTER_ORIGIN
export CSRF_FILTER_ORIGIN


set_as_boolean CSRF_FILTER "false"
if [ -n "${CSRF_FILTER_REFERER}" ] && [ -n "${CSRF_FILTER_ORIGIN}" ] ; then
	CSRF_FILTER="true"
else
	CSRF_FILTER="false"
	CSRF_FILTER_REFERER=""
	CSRF_FILTER_ORIGIN=""
fi

cp -vf "${SHARED_CONFIG_XML}" "${SHARED_CONFIG_XML}.bak"
xmlenvsubst < "${SHARED_CONFIG_XML}.bak" > "${SHARED_CONFIG_XML}"

quit "CSRF Configuration set (CSRF Filtering Enabled = ${CSRF_FILTER})
