#!/bin/sh
[ "${OCF_RA_PROVIDER}" = "none" -o "${UPLOAD_METHOD}" = "none" ] && exit 0
mkdir -p "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}"
if [ "${UPLOAD_METHOD}" = "copy" ] ; then
  [ "${OCF_RA_PATH}" ] || exit 1
  echo "Get the OCF RA from ${OCF_RA_PATH}"
  cp -f "${OCF_RA_PATH}" "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}/${OCF_RA_TYPE}"
else
  echo "Download the OCF RA from the stable branch"
  wget "${OCF_RA_PATH}"  -O "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}/${OCF_RA_TYPE}"
fi
chmod +x "/usr/lib/ocf/resource.d/${OCF_RA_PROVIDER}/${OCF_RA_TYPE}"
exit 0
