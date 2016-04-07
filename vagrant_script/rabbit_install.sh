#!/bin/sh
# Install the rabbitmq-server package of a given version ($1),
# if requested.
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ $1 ] || exit 1
[ "$1" = "false" ] && exit 0
file="rabbitmq-server_$1-1_all.deb"
wget "http://www.rabbitmq.com/releases/rabbitmq-server/v$1/${file}" -O "/tmp/${file}"
dpkg -i "/tmp/${file}"
exit $?
