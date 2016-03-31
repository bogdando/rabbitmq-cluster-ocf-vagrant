#!/bin/bash
# WARNING: Changes the root pass for jepsen/jsch as it uses only a pass based auth!
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
echo -e "Host n*\nUser root" > /root/.ssh/config
echo -e "root\nroot" | passwd root
echo "PermitRootLogin yes" > /etc/ssh/sshd_config && kill -HUP `pgrep -f /usr/sbin/sshd`
exit 0
