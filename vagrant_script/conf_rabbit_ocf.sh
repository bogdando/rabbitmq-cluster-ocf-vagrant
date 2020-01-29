#!/bin/sh
STORAGE=${STORAGE:-/tmp}
mkdir -p "${STORAGE}/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}"
[ "${OCF_RA_PROVIDER}" = "none" -o "${UPLOAD_METHOD}" = "none" ] && exit 0
if [ "${UPLOAD_METHOD}" = "copy" ] ; then
  [ "${OCF_RA_PATH}" ] || exit 1
  echo "Get the OCF RA from ${OCF_RA_PATH}"
  cp -f "${OCF_RA_PATH}" "${STORAGE}/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}"
else
  echo "Download the OCF RA from the stable branch"
  wget "${OCF_RA_PATH}"  -O "${STORAGE}/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}"
fi
chmod +x "${STORAGE}/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}"
mkdir -p "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}"
cp -f "${STORAGE}/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}" "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}/${OCF_RA_PROVIDER_TYPE}"
exit 0
