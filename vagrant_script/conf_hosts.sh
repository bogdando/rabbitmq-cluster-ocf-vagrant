#!/bin/bash
# Configure hosts entries in the /etc/hosts
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ -z "${1}" ] && exit 1
echo "127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
" >/etc/hosts
while (( "$#" )); do
  echo "${1}" >> /etc/hosts
  shift
done
exit 0
