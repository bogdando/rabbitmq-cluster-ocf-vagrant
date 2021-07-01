#!/bin/bash
# Smoke test for a rabbitmq cluster of given # of nodes,
# for example if $1=2: it will test against {rabbit@n1, rabbit@n2}.
# Wait for a given $WAIT env var
# run on remote node, if the $AT_NODE specified.
# When run localy, provide crm_mon outputs as well.
set -o pipefail
[ -z "${1}" ] && exit 0
rabbit_nodes="rabbit@n1"
for i in $(seq 2 $1); do
  rabbit_nodes="${rabbit_nodes} rabbit@n$i"
done

echo root > /tmp/sshpass
cmd="timeout --signal=KILL 10 rabbitmqctl cluster_status --formatter json"
[ "${AT_NODE}" ] && cmd="sshpass -f /tmp/sshpass ssh ${AT_NODE} ${cmd}"

count=0
result="FAILED"
throw=1
WAIT="${WAIT:-180}"
while [ $count -lt $WAIT ]
do
  output=`${cmd}|python3 -c 'import sys,json;n=json.loads(sys.stdin.read());print(" ".join(sorted(dict(zip(n["running_nodes"],n["running_nodes"])).keys())))' 2>/dev/null`
  rc=$?
  if [ $rc -eq 0 -a "$output" = "$rabbit_nodes" ]; then
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
