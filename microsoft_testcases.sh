#!/bin/bash
#Author: Rohan Tabish
#Organization: Intel Corporation

#################################################################
# Config # 1: HPVM1(13) | HPVM2 (13) |HVSVM (2) | LP-VM1 (10) | LP-VM2 (10)
# Config # 2: HPVM1(13)
# Config # 3: HPVM1 (13) | HPVM2(13)
# More to be added



#################################################################

HPVM1=13
HPVM2=13
HVSVM=2
LPVM1=14
LPVM2=14

rm -rf /root/mlc_*

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


echo off > /sys/devices/system/cpu/smt/control

echo "Running HPVM1 Solo"

sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py
./run.sh -T vm -S setup -C $HPVM1 -W mlc

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 30
echo "Starting benchmark now"

./run.sh -T vm -S run -W mlc


cat /root/mlc_rep_1_ncores_13


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*
rm -rf /root/mlc_rep_1_ncores_13


echo "CoScheduling HPVM1 with HPVM2|HPSVM|LPVM1|LPVM2"

sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :5/g' vm_cloud-init.py

virsh list --all --name|xargs -i virsh destroy {} --graceful
./run.sh -T vm -S setup -C $HPVM1,$HPVM2,$HVSVM,$LPVM1,$LPVM2 -W mlc

sleep 30

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W mlc


cat /root/mlc_rep_1_ncores_13


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


sed -i 's/"5G" :5/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*
