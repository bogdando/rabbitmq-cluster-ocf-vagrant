#!/bin/sh
# Manage drop-ins for a corosync/pacemaker service units
# Protect from an incident running on hosts which aren't n1, n2, etc.
hostname | grep -q "^n[0-9]\+"
[ $? -eq 0 ] || exit 1

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
After=network.target
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
