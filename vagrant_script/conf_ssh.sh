#!/bin/bash
# Setup jepsen related things, $1 is the number of nX nodes
# Protect from an incident running on hosts which aren't n1, n2, etc.
me="$(hostname -s)"
echo $me | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
rm -f /tmp/known_hosts
(while true; do mkdir -p /run/sshd; sleep 3; done) & disown
while true; do
  entry="$(ssh-keyscan -t rsa $me)"
  [ "${entry}" ] && break
  echo "${me} is waiting for SSH keys to arrive o_O"
  sleep 5
done
for i in $(seq 1 $1); do
   echo $entry | sed "s/^$me/n$i/g" >> /tmp/known_hosts
done
cp -f /tmp/known_hosts /root/.ssh/known_hosts
exit 0
