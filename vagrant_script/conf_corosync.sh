#!/bin/sh
# Evaluate and configure an ip address of the corosync node
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
IP=`ip addr show | grep -E '^[ ]*inet' | grep -m1 global | awk '{ print $2 }' | sed -e 's/\/.*//'`
CNT=${CNT:-2}
sed -i "s/bindnetaddr: 127.0.0.1/bindnetaddr: $IP/g" /etc/corosync/corosync.conf
sed -i "s/expected_votes:.*$/expected_votes: $CNT/g" /etc/corosync/corosync.conf
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
exit 0
