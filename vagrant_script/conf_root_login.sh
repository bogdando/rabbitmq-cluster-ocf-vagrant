#!/bin/bash
# WARNING: Changes the root pass for jepsen/jsch as it uses only a pass based auth!
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
printf "%b\n" "Host n*\nUser root" > /root/.ssh/config
printf "%b\n" "root\nroot" | passwd root
echo "PermitRootLogin yes" > /etc/ssh/sshd_config && kill -HUP `pgrep -f /usr/sbin/sshd`
exit 0
