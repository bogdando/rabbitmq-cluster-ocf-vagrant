#!/bin/bash
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
rm -f /root/.ssh/known_hosts
for i in $(seq 1 $1); do
  ssh-keyscan -t rsa n$i >> /root/.ssh/known_hosts
done
exit 0
