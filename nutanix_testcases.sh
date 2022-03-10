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

pqos -R

#rmid and clos
#pqos rmid add monitoring 
#
cpupower frequency-set -u 2700Mhz

rm -rf /root/mlc_*

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


echo off > /sys/devices/system/cpu/smt/control

echo "Running HPVM1 Solo"

sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py

./run.sh -T vm -S setup -C $HPVM -W $HPWORKLOAD

sleep 30
#virsh destroy $HPWORKLOAD-01 --graceful
#virsh start $HPWORKLOAD-01

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}
virsh list

sleep 60
echo "Starting benchmark now"

#virsh list

./run.sh -T vm -S run -W $HPWORKLOAD

virsh list

cat /root/mlc_rep_1_ncores_34


virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}

sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*
rm -rf /root/mlc_rep_1_ncores_34



echo "================================================="
echo "CoScheduling HPVM with LPVM"
echo "================================================="

sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py

#virsh list --all --name|xargs -i virsh destroy {} --graceful
./run.sh -T vm -S setup -C $HPVM,$LPVM -W $HPWORKLOAD,$LPWORKLOAD

sleep 30

#virsh destroy mlc-02 --graceful
#virsh destroy mlc-03 --graceful

#virsh start mlc-02
#virsh start mlc-03

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W $HPWORKLOAD


cat /root/mlc_rep_1_ncores_34



virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2/*
rm -rf /root/mlc_rep_1_ncores_34


echo "========================================================="
echo "CoScheduling HPVM with LPVM with static MBA"
echo "========================================================="

pqos -e 'mba:0=10'
pqos -e 'mba:3=90'

pqos -a 'core:0=0-33'
pqos -a 'core:3=34-55'



sudo dhclient -r $ sudo dhclient
sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py

#virsh list --all --name|xargs -i virsh destroy {} --graceful
./run.sh -T vm -S setup -C $HPVM,$LPVM -W $HPWORKLOAD,$LPWORKLOAD

sleep 30

#virsh destroy mlc-02 --graceful
#virsh destroy mlc-03 --graceful

#virsh start mlc-02
#virsh start mlc-03

virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh start {}

sleep 60
echo "Starting benchmark now"

./run.sh -T vm -S run -W $HPWORKLOAD


cat /root/mlc_rep_1_ncores_34



virsh list --all --name|xargs -i virsh destroy {} --graceful
virsh list --all --name|xargs -i virsh undefine {}


sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
rm -rf /home/vmimages2
