#!/bin/bash
# WARNING: Changes the root pass for jepsen/jsch as it uses only a pass based auth!
# Setup jepsen related things, $1 is the number of nX nodes
# Protect from an incident running on hosts which aren't n1, n2, etc.
! [[ `hostname` =~ ^n[0-9]+$ ]] && exit 1

mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
echo -e "Host n*\nUser root" > /root/.ssh/config
echo -e "root\nroot" | passwd root

for i in $(seq 1 $1); do
  ssh-keyscan -t rsa n$i >> /root/.ssh/known_hosts
done

echo "PermitRootLogin yes" > /etc/ssh/sshd_config && kill -HUP `pgrep -f /usr/sbin/sshd`
exit 0
