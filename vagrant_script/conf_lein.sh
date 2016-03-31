#!/bin/sh
# Pull images to new location, which is the shared docker volume /jepsen
# Launch lein to test a given app ($1)
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ "$1" ] || exit 1
unit="/lib/systemd/system/docker.service"
grep -q '^ExecStart.*\-g' $unit || sed -ie 's_^ExecStart.*[^\-g]_& -g /jepsen_' $unit
systemctl daemon-reload && systemctl restart docker
docker pull pandeiro/lein

# Run lein for jepsen
docker stop jepsen && docker rm -f -v jepsen
docker run --stop-signal=SIGKILL -itd \
  -v /etc/hosts:/etc/hosts:ro \
  -v /root/.ssh:/root/.ssh:ro \
  -v /jepsen/jepsen/$1:/app \
  -v /jepsen/logs:/app/store \
  --entrypoint /bin/bash \
  --name jepsen -h jepsen \
  pandeiro/lein:latest
sync
echo "To run lein commmands, use docker exec -it jepsen lein foo"
echo "For example, docker exec -it jepsen lein test :only jepsen.core-test/ssh-test"
exit 0
