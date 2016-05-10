#!/bin/sh
# Pull images,
# Launch lein to test a given app ($1) and a given test ($2) or all.
# Protect from an incident running on hosts which aren't n1, n2, etc.
# Stop & remove the main jepsen container, if env $PURGE=true
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
[ "$1" ] || exit 1
if ! docker images | grep -q 'pandeiro/lein'
then
  echo "Pull lein container"
  docker pull pandeiro/lein
fi

# Try to start the jepsen container w/o purging it
docker start jepsen || PURGE=true

# Make custom builds only when purging as well
JEPSON_VER=0.1.1-SNAPSHOT
if [ "${PURGE}" = "true" ]; then
  # FIXME(bogdando) remove those customs, when build is not required anymore
  docker stop jepsen && docker rm -f -v jepsen
  # Run lein to make a custom jepsen build
  docker stop jepsen-build && docker rm -f -v jepsen-build
  echo "Make a custom jepson jar build"
  docker run -it --rm \
    -v /jepsen/jepsen/jepsen:/app \
    --entrypoint /bin/bash \
    --name jepsen-build -h jepsen \
    pandeiro/lein:latest -c "lein deps && lein compile && lein uberjar; sync"
  sync

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

  dir_jepsen=resources/jepsen/jepsen/${JEPSON_VER}
  docker exec -it jepsen bash -c "mkdir -p $dir_jepsen"
  docker exec -it jepsen bash -c "cp -f /custom/jepsen-${JEPSON_VER}*  $dir_jepsen"
fi

testcase="lein test"
[ "${2}" ] && testcase="${testcase} :only jepsen.${1}-test/${2}"
docker exec -it jepsen bash -c "lein deps && lein compile && ${testcase}"
echo "Test exited with $?, but it is OK anyway"
sync
exit 0
