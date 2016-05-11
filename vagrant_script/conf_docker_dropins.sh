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

drop_in="/etc/systemd/system/corosync.service.d/"
mkdir -p $drop_in
# Respawn a Corosync, gives up when is "Active (active:exited)" ;-(
override="respawn.conf"
echo "Drop-in respawn for a corosync service"
def="[Unit]
After=network.target
[Service]
Type=forking
RemainAfterExit=false
ExecStart=
ExecStart=/usr/sbin/corosync
Restart=always
StartLimitInterval=0"
printf "%b\n" ${def} > "${drop_in}${override}"

drop_in="/etc/systemd/system/pacemaker.service.d/"
mkdir -p $drop_in
# Respawn a Pacemaker with a Corosync dependency
override="respawn.conf"
echo "Drop-in respawn for a pacemaker service"
def="[Unit]
After=network.target corosync.service
Requires=corosync.service
[Service]
Type=simple
RemainAfterExit=false
ExecStart=
ExecStart=/usr/sbin/pacemakerd
Restart=always
StartLimitInterval=0"
printf "%b\n" ${def} > "${drop_in}${override}"

systemctl daemon-reload
systemctl enable corosync
systemctl enable pacemaker
systemctl restart docker
