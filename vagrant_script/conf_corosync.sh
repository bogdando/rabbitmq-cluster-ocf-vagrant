#!/bin/sh
# Configure ip address of the corosync node as ${1}
# and wait for ${2} seconds, if requested
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ -z "${1}" ] && exit 1
sed -i "s/bindnetaddr: 127.0.0.1/bindnetaddr: ${1}/g" /etc/corosync/corosync.conf
[ "${2}" ] && sleep $2
service corosync restart
service pacemaker restart
exit 0
