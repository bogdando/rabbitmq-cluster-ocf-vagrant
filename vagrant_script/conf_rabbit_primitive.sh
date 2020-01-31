#!/bin/sh -x
# Configures the rabbitmq OCF primitive
# wait for the crmd to become ready, wait for a given $SEED node.
# Protect from an incident running on hosts which aren't n1, n2, etc.
OCF_RA_PROVIDER=${OCF_RA_PROVIDER:-rabbitmq}
OCF_RA_TYPE=${OCF_RA_TYPE:-rabbitmq-server-ha}
POLFILE=${POLFILE:-/usr/local/sbin/set_rabbitmq_policy}
[ "${POLICY_BASE64}:-''" ] &&  echo "${POLICY_BASE64}" | base64 -d > ${POLFILE}
name=$(hostname)
echo $name | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
count=0
while [ $count -lt 160 ]
do
  if timeout --signal=KILL 5 cibadmin -Q
  then
    break
  fi
  count=$((count+10))
  sleep 10
done

# for a seed node, create the rabbitmq multi-state primitive
# w/a https://github.com/ClusterLabs/crmsh/issues/120
# retry for the cib patch diff Error 203
if [ "${name}" = "${SEED}" ] ; then
  crm configure show p_rabbitmq-server && exit 0
  count=0
  while [ $count -lt 160 ]
  do
    crm configure<<EOF
    property stonith-enabled=false
    property no-quorum-policy=stop
    property cluster-recheck-interval=30s
    commit
EOF
    crm --force configure primitive p_rabbitmq-server \
          ocf:$OCF_RA_PROVIDER:$OCF_RA_TYPE \
          params erlang_cookie=DPMDALGUKEOMPTHWPYKC node_port=5672 policy_file=$POLFILE \
          op monitor interval=30 timeout=180 \
          op monitor interval=27 role=Master timeout=180 \
          op start interval=0 timeout=180 \
          op stop interval=0 timeout=120 \
          op promote interval=0 timeout=120 \
          op demote interval=0 timeout=120 \
          op notify interval=0 timeout=180 \
          meta migration-threshold=10 failure-timeout=30s resource-stickiness=100 && \
    crm --force configure ms p_rabbitmq-server-master p_rabbitmq-server \
          meta notify=true ordered=false interleave=false master-max=1 master-node-max=1 \
          requires="nothing"
    [ $? -eq 0 ] && break
    count=$((count+10))
    sleep 10
  done
else
  # wait for a seed node
  while :; do
    crm_resource --locate --resource p_rabbitmq-server-master | grep -q "running on.*${SEED}" && break
    echo "Waiting for a seed node ${SEED}"
    sleep 10
  done
fi

crm configure location p_rabbitmq-server-master_$name p_rabbitmq-server-master 100: $name
crm resource cleanup p_rabbitmq-server-master
exit 0
