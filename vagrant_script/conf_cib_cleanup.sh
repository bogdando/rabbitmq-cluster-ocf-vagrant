#!/bin/sh
# Removes artificial nodes from the CIB.

# Remove artificial nodes from CIB
# wait for crm_node to become functioning
count=0
while [ $count -lt 160 ]
do
  crm_node -l
  [ $? -eq 0 ] && break
  service pacemaker restart
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
