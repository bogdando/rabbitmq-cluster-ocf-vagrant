#!/bin/sh
# Configures the rabbitmq OCF primitive
# wait for the crmd to become ready
# Protect from an incident running on hosts which aren't n1, n2, etc.
! [[ `hostname` =~ ^n[0-9]+$ ]] && exit 1

count=0
while [ $count -lt 160 ]
do
  if timeout --signal=KILL 5 crm_attribute --type crm_config --query --name dc-version | grep -q 'dc-version'
  then
    break
  fi
  count=$((count+10))
  sleep 10
done

# create the rabbitmq multi-state primitive, remove old node's names artifact
# w/a https://github.com/ClusterLabs/crmsh/issues/120
# retry for the cib patch diff Error 203
crm configure show p_rabbitmq-server && exit 0
count=0
while [ $count -lt 160 ]
do
  crm configure<<EOF
  property stonith-enabled=false
  property no-quorum-policy=stop
  commit
EOF
  (echo y | crm configure primitive p_rabbitmq-server ocf:rabbitmq:rabbitmq-server-ha \
          params erlang_cookie=DPMDALGUKEOMPTHWPYKC node_port=5672 policy_file=/tmp/rmq-ha-pol \
          op monitor interval=30 timeout=180 \
          op monitor interval=27 role=Master timeout=180 \
          op monitor interval=35 role=Slave timeout=180 OCF_CHECK_LEVEL=30 \
          op start interval=0 timeout=180 \
          op stop interval=0 timeout=120 \
          op promote interval=0 timeout=120 \
          op demote interval=0 timeout=120 \
          op notify interval=0 timeout=180 \
          meta migration-threshold=10 failure-timeout=30s resource-stickiness=100) && \
  (echo y | crm configure ms p_rabbitmq-server-master p_rabbitmq-server \
          meta notify=true ordered=false interleave=false master-max=1 master-node-max=1)
  [ $? -eq 0 ] && break
  count=$((count+10))
  sleep 10
done
exit 0
