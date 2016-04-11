#!/bin/bash
# Smoke test for a rabbitmq cluster of given set of nodes,
# for example: rabbit@n1 rabbit@n2
# wait for a given $WAIT env var
# run on remote node, if the $AT_NODE specified.
# When run localy, provide crm_mon outputs as well.
[ -z "${1}" ] && exit 0
echo '' >/tmp/nodes
while (( "$#" )); do
  echo "${1}" >> /tmp/nodes
  shift
done

cmd='timeout --signal=KILL 10 rabbitmqctl cluster_status'
[ "${AT_NODE}" ] && cmd="ssh ${AT_NODE} ${cmd}"

count=0
result="FAILED"
throw=1
WAIT="${WAIT:-180}"
while [ $count -lt $WAIT ]
do
  output=`${cmd} 2>/dev/null`
  rc=$?
  state=0
  while read n; do
    [ "${n}" ] || continue
    echo "${output}" | grep -q "running_nodes.*${n}"
    [ $? -eq 0 ] || state=1
  done </tmp/nodes
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
