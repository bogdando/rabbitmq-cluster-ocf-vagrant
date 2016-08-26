#!/bin/bash
# Smoke test for a rabbitmq cluster of given # of nodes,
# for example if $1=2: it will test against {rabbit@n1, rabbit@n2}.
# Wait for a given $WAIT env var
# run on remote node, if the $AT_NODE specified.
# When run localy, provide crm_mon outputs as well.
[ -z "${1}" ] && exit 0
rabbit_nodes=""
for i in $(seq 1 $1); do
  rabbit_nodes="rabbit@n$i ${rabbit_nodes}"
done

echo root > /tmp/sshpass
cmd='timeout --signal=KILL 10 rabbitmqctl cluster_status'
[ "${AT_NODE}" ] && cmd="sshpass -f /tmp/sshpass ssh ${AT_NODE} ${cmd}"

count=0
result="FAILED"
throw=1
WAIT="${WAIT:-180}"
while [ $count -lt $WAIT ]
do
  output=`${cmd} 2>/dev/null`
  rc=$?
  state=0
  for n in $rabbit_nodes; do
    [ "${n}" ] || continue
    echo "${output}" | grep -q "running_nodes.*${n}"
    [ $? -eq 0 ] || state=1
  done
  if [ $rc -eq 0 -a $state -eq 0 ]; then
    result="PASSED"
    throw=0
    break
  fi
  echo "RabbitMQ cluster is yet to be ready"
  count=$((count+10))
  if [ -z "${AT_NODE}" ]; then
    echo "Crm_mon says:"
    timeout --signal=KILL 5 crm_mon -fotAW -1
  fi
  sleep 30
done

echo "RabbitMQ cluster smoke test: ${result}"
exit $throw
