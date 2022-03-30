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

:'
Input:
-----
VM_CORES=[3, 3, 2, 1, 1] # no of cpus for different VMs according to their priority
VM_WORKLOADS=["mlc", "redis", "mlc", "rn50", "memcache"] # name of workloads to be run on the VMs accroding to their priority

The following is done from the input:
------------------------------------
1. VM_CORE_RANGE=["45-47", "42-44", "40-41", "39", "38"] # need to init core ranges for the VMs
2. ./run.sh -T vm -S setup -C $VM_CORES -W $VM_WORKLOADS
3. ./run.sh -T vm -S run -C $VM_CORES -W $VM_WORKLOADS -N <co/solo>_<QoS>
	I.   Initialize core range for each VM ($VM_CORE_RANGE)
	II.  Run experiments in all the VMs and write file to : <name of the workload>_<core_range>_<co/solo>_<QoS> (e.g. mlc_45-47_co_hwdrc) or <vm_name>_<co/solo>_<QoS>.
	    Iterate through all the VMs that are running and get VM name. The VM name contains the name of the workload, e.g. mlc-01
	III. After the exp is done, copy back the result file: <name of the workload>_<core_range>_<co/solo>_<QoS> (e.g. mlc_45-47_co_hwdrc)
	  Iterate through all the VMs that are running and get VM name. The VM name contains the name of the workload, e.g. mlc-01
	IV.  While compiling results, go through the VM_WORKLOADS list and generate filename: mlc_27-40_solo_na, mlc_27-40_co_na, mlc_27-40_co_mba, mlc_27-40_co_hwdrc

Questions:
1. Can there be multiple HP VMs?
2. Can there
3. One VM cpu pinning, others floating (do not pin).
4. Priority Group: 

'

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
