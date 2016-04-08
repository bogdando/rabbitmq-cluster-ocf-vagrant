#!/bin/sh
# Pull images to new location, which is the shared docker volume /jepsen
# Launch lein to test a given app ($1)
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ "$1" ] || exit 1
unit="/lib/systemd/system/docker.service"
if ! grep -q '^ExecStart.*\-g' "${unit}"
then
  echo "Patch docker service unit"
  sed -ie 's_^ExecStart.*[^\-g]_& -g /jepsen_' "${unit}"
  systemctl daemon-reload && systemctl restart docker
fi
if ! docker images | grep -q 'pandeiro/lein'
then
  echo "Pull lein container"
  docker pull pandeiro/lein
fi

# debug
docker images
ls /jepsen/jepsen
date

# FIXME(bogdando) remove those customs, when build is not required anymore
# Run lein to make a custom jepsen build
docker stop jepsen && docker rm -f -v jepsen
echo "Make a custom jepson jar build"
docker run -itd \
  -v /jepsen/jepsen/jepsen:/app \
  --entrypoint /bin/bash \
  --name jepsen -h jepsen \
  pandeiro/lein:latest -c "lein deps && lein compile && lein uberjar; sync"

# debug
docker exec -it jepsen mount -l
docker exec -it jepsen cat /app/project.clj

sync
docker stop jepsen && docker rm -f -v jepsen

# Run lein for jepsen tests, using the custom build from the target dir mounted
# Ignore exit code as it may fail. Distributed systems are faily with jepsen...
echo "Run lein test"
docker run --stop-signal=SIGKILL -itd \
  -v /etc/hosts:/etc/hosts:ro \
  -v /root/.ssh:/root/.ssh:ro \
  -v /jepsen/jepsen/$1:/app \
  -v /jepsen/jepsen/jepsen/target:/custom:ro \
  -v /jepsen/logs:/app/store \
  --entrypoint /bin/bash \
  --name jepsen -h jepsen \
  pandeiro/lein:latest

# debug
docker exec -it jepsen mount -l
docker exec -it jepsen cat /app/project.clj
docker exec -it jepsen ls -lah /custom

docker exec -it jepsen bash -c "mkdir -p resources/jepsen/jepsen/0.1.0-SNAPSHOT"
docker exec -it jepsen bash -c "cp -f /custom/jepsen-0.1.0-SNAPSHOT*  resources/jepsen/jepsen/0.1.0-SNAPSHOT/"
docker exec -it jepsen bash -c "lein deps && lein compile && lein test"
echo "Test exited with $?, but it is OK anyway"
sync
exit 0
