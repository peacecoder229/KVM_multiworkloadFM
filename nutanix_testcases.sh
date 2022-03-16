#!/bin/bash
#Author: Rohan Tabish
#Organization: Intel Corporation

#################################################################
# Config # 1: HPVM1(13) | HPVM2 (13) |HVSVM (2) | LP-VM1 (10) | LP-VM2 (10)
# Config # 2: HPVM1(13)
# Config # 3: HPVM1 (13) | HPVM2(13)
# More to be added
#################################################################

HPVM=34
LPVM=22

HPWORKLOAD=$1
LPWORKLOAD=$2

cpupower frequency-set -u 2700Mhz
pqos -R



#sed -i "0,/${HPWORKLOAD}_STRING=/s//${HPWORKLOAD}_STRING=${HPWORKLOAD}_solo/" run.sh
#sed -i "0,/${HPWORKLOAD}_STRING=${HPWORKLOAD}_solo/s//$HPWORKLOAD_STRING=${HPWORKLOAD}_stress/" run.sh

sed -i "s/${HPWORKLOAD}_STRING=/${HPWORKLOAD}_STRING=${HPWORKLOAD}_hp/g" run.sh


rm -rf /root/.ssh/known_hosts

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

echo off > /sys/devices/system/cpu/smt/control

echo "Running HPVM1 Solo"

sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py

./run.sh -T vm -S setup -C $HPVM -W $HPWORKLOAD

sleep 30

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}
virsh list

sleep 60
echo "Starting benchmark now"

#virsh list

./run.sh -T vm -S run -W $HPWORKLOAD

virsh list



virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*

sed -i "s/${HPWORKLOAD}_STRING=${HPWORKLOAD}_hp/${HPWORKLOAD}_STRING=${HPWORKLOAD}_stressed/g" run.sh

if [$LPWORKLOAD != $HPWORKLOAD]
then
	sed -i "s/${LPWORKLOAD}_STRING=/${LPWORKLOAD}_STRING=${LPWORKLOAD}_stressed/g" run.sh
fi

echo "================================================="
echo "CoScheduling HPVM with LPVM"
echo "================================================="

sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py

./run.sh -T vm -S setup -C $HPVM,$LPVM -W $HPWORKLOAD,$LPWORKLOAD

sleep 30

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W $HPWORKLOAD


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*

sed -i "s/${HPWORKLOAD}_STRING=${HPWORKLOAD}_stressed/${HPWORKLOAD}_STRING=${HPWORKLOAD}_stressed_MBA/g" run.sh
if [$LPWORKLOAD != $HPWORKLOAD]
then
	sed -i "s/${LPWORKLOAD}_STRING=${LPWORKLOAD}_stressed/${LPWORKLOAD}_STRING=${LPWORKLOAD}_stressed_MBA/g" run.sh
fi
echo "========================================================="
echo "CoScheduling HPVM with LPVM with static MBA"
echo "========================================================="

pqos -a 'core:0=22-55'
pqos -a 'core:3=0-21'

pqos -e 'mba:0=100'
pqos -e 'mba:3=10'



sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py

./run.sh -T vm -S setup -C $HPVM,$LPVM -W $HPWORKLOAD,$LPWORKLOAD

sleep 30

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W $HPWORKLOAD


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2
sed -i "s/${HPWORKLOAD}_STRING=${HPWORKLOAD}_stressed_MBA/${HPWORKLOAD}_STRING=/g" run.sh
if [$LPWORKLOAD != $HPWORKLOAD]
then
	sed -i "s/${LPWORKLOAD}_STRING=${LPWORKLOAD}_stressed_MBA/${LPWORKLOAD}_STRING=/g" run.sh
fi
