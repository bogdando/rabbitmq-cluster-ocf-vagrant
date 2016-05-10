#!/bin/bash
# WARNING: Changes the root pass for jepsen/jsch as it uses only a pass based auth!
# Setup jepsen related things, $1 is the number of nX nodes
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
printf "%b\n" "Host n*\nUser root" > /root/.ssh/config
printf "%b\n" "root\nroot" | passwd root

for i in $(seq 1 $1); do
  ssh-keyscan -t rsa n$i >> /root/.ssh/known_hosts
done

# wait for sshd alive
count=0
while [ $count -lt 160 ]; do
  ps -C sshd -o command= | grep -v 'defunct' && break
  /usr/sbin/sshd
  count=$((count+10))
  sleep 10
done

echo "PermitRootLogin yes" > /etc/ssh/sshd_config && kill -HUP `pgrep -f /usr/sbin/sshd`
exit 0
