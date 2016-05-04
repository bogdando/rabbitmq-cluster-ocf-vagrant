#!/bin/sh
# Removes artificial nodes from the CIB.

# Remove artificial nodes from CIB
# wait for crm_node to become functioning
# Protect from an incident running on hosts which aren't n1, n2, etc.
! [[ `hostname` =~ ^n[0-9]+$ ]] && exit 1

count=0
while [ $count -lt 160 ]
do
  timeout --signal=KILL 5 crm_node -l
  [ $? -eq 0 ] && break
  if ! timeout --signal=KILL 30 service pacemaker restart
  then
    pkill -f -9 pacemaker
    service pacemaker start
  fi
  count=$((count+10))
  sleep 5
done
crm_node -l | awk '{print $2}' | grep -v null > /tmp/valid_nodes
# wait for the crmd to become ready
count=0
while [ $count -lt 160 ]
do
  if crm_attribute --type crm_config --query --name dc-version | grep -q 'dc-version'
  then
    break
  fi
  count=$((count+10))
  sleep 10
done
crm configure show | awk '/^node/ {print $3}' | grep -v null > /tmp/all_nodes
for i in `grep -F -x -v -f /tmp/valid_nodes /tmp/all_nodes` ; do
  # protect valid nodes from an incident deletion
  if echo $i | grep -q -E "^n[0-9]+" ; then
    continue
  fi
  crm --force configure delete $i
done
exit 0
