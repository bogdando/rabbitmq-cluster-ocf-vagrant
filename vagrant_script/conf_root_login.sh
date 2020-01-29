#!/bin/bash
# WARNING: Changes the root pass for jepsen/jsch as it uses only a pass based auth!
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
printf "Host n*\nUser root\n" > /tmp/config
mkdir -p /root/.ssh/
cp -f /tmp/config /root/.ssh/config
rm -f /tmp/config
printf "root\nroot\n" | passwd root >/dev/null 2>&1
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "PermitRootLogin yes" > /etc/ssh/sshd_config && kill -HUP `pgrep -f /usr/sbin/sshd`
exit 0
