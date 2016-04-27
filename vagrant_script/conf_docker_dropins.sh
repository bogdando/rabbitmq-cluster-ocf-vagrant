#!/bin/sh
# Manage drop-ins for a docker service unit
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1
unit="/lib/systemd/system/docker.service"
drop_in="/etc/systemd/system/docker.service.d/"
mkdir -p $drop_in

# Move storage to new location, which is the shared docker volume /jepsen
override="new_storage_path.conf"
echo "Drop-in new storage path for a docker service unit"
# https://github.com/docker/docker/issues/14491
printf "%b\n" "[Service]\nExecStart=" > "${drop_in}${override}"
grep -E '^ExecStart' $unit | sed -e 's_$_& -g /jepsen_' >> "${drop_in}${override}"
systemctl daemon-reload && systemctl restart docker
