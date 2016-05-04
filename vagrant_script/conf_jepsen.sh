#!/bin/sh
# Clone/fetch jepsen to the shared docker volume
# Protect from an incident running on hosts which aren't n1, n2, etc.
! [[ `hostname` =~ ^n[0-9]+$ ]] && exit 1

cd /jepsen
#if ! git clone https://github.com/aphyr/jepsen
if ! git clone -b rabbit_pcmk https://github.com/bogdando/jepsen
then
  cd ./jepsen
  git remote update
  git pull --ff-only
  cd -
fi
mkdir -p logs
sync
exit 0
