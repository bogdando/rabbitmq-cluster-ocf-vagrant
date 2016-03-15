#!/bin/sh
if [ "${UPLOAD_METHOD}" = "copy" ] ; then
  [ "${OCF_RA_PATH}" ] || exit 1
  echo "Copy the rabbit OCF RA from ${OCF_RA_PATH}"
  cp -f "${OCF_RA_PATH}" /tmp/rabbitmq-server-ha
elif [ "${UPLOAD_METHOD}" = "none" ] ; then
  echo "Do not upload the rabbit OCF RA"
else
  echo "Download the rabbit OCF RA from the stable branch"
  wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-server/stable/scripts/rabbitmq-server-ha.ocf -O /tmp/rabbitmq-server-ha
fi
chmod +x /tmp/rabbitmq-server-ha
cp -f /tmp/rabbitmq-server-ha /usr/lib/ocf/resource.d/rabbitmq/
exit 0
