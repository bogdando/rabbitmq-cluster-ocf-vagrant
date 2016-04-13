#!/bin/sh
# Configure ip address of the corosync node as ${1}
# and wait for ${2} seconds, if requested
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ -z "${1}" ] && exit 1
sed -i "s/bindnetaddr: 127.0.0.1/bindnetaddr: ${1}/g" /etc/corosync/corosync.conf
[ "${2}" ] && sleep $2
if ! timeout --signal=KILL 30 service corosync restart
then
  pkill -f -9 corosync
  service corosync start
fi
if ! timeout --signal=KILL 30 service pacemaker restart
then
  pkill -f -9 pacemaker
  service pacemaker start
fi
# FIXME(bogdando) A w/a to ensure the pacemakerd is respawning, if failed
cp -f /vagrant/conf/pacemakerd.service /lib/systemd/system || /bin/true
systemctl daemon-reload || /bin/true
systemctl enable pacemakerd || /bin/true
systemctl start pacemakerd || /bin/true
exit 0
