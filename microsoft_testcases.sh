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

echo off > /sys/devices/system/cpu/smt/control

./run.sh -T vm -S setup -C $HPVM1,$HPVM2,$HVSVM,$LPVM1,$LPVM2 -W mlc 

sleep 30

virsh destroy mlc-01 --graceful
virsh destroy mlc-02 --graceful
virsh destroy mlc-03 --graceful
virsh destroy mlc-04 --graceful
virsh destroy mlc-05 --graceful


virsh start mlc-01
virsh start mlc-02
virsh start mlc-03
virsh start mlc-04
virsh start mlc-05

sleep 30


./run.sh -T vm -S run -W mlc

#virsh domiflist mlc-01
#virsh domiflist mlc-02
#virsh domiflist mlc-03
#virsh domiflist mlc-04
#virsh domiflist mlc-05



#scp /usr/bin/mlc root@192.168.122.52:/usr/bin/
#ssh root@192.168.122.52 "mlc --loaded_latency -R -t${30} -T -k${HPVM1} -d0 | grep 00000 | awk '{print $3}'" 

