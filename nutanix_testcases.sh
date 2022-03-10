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

#rmid and clos
#pqos rmid add monitoring 
#

rm -rf /root/mlc_*

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


echo off > /sys/devices/system/cpu/smt/control

echo "Running HPVM1 Solo"

sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py

./run.sh -T vm -S setup -C $HPVM -W mlc

sleep 30
virsh destroy mlc-01 --graceful
virsh start mlc-01

#virsh list --all --name|xargs -i virsh destroy {} --graceful
#virsh list --all --name|xargs -i virsh start {}
virsh list
sleep 60
echo "Starting benchmark now"

#virsh list

./run.sh -T vm -S run -W mlc

virsh list

cat /root/mlc_rep_1_ncores_34


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*
rm -rf /root/mlc_rep_1_ncores_34






echo "CoScheduling HPVM1 with HPVM2|HPSVM|LPVM1|LPVM2"

sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py

#virsh list --all --name|xargs -i virsh destroy {} --graceful
./run.sh -T vm -S setup -C $HPVM,$LPVM -W mlc

sleep 30

virsh destroy mlc-02 --graceful
virsh destroy mlc-03 --graceful

virsh start mlc-02
virsh start mlc-03

#virsh list --all --name|xargs -i virsh destroy {} --graceful
#virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W mlc


cat /root/mlc_rep_1_ncores_34



virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*


