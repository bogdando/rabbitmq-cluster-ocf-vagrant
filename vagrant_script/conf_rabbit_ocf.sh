#!/bin/sh
# FIXME(bogdando) remove after the rabbitmq-server v3.5.7 released
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-server/stable/scripts/rabbitmq-server-ha.ocf \
-O /tmp/rabbitmq-server-ha
chmod +x /tmp/rabbitmq-server-ha
cp -f /tmp/rabbitmq-server-ha /usr/lib/ocf/resource.d/rabbitmq/
exit 0
