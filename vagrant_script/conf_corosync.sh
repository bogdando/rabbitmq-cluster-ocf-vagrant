#!/bin/sh -eu
# Evaluate and configure an ip address of the corosync node
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

puppet apply -e "class {'pacemaker::new::setup::config':cluster_nodes=>$NODES,cluster_options=>{'expected_votes'=>$CNT}}"
service corosync restart
service pacemaker restart
