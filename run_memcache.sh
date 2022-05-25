#!/bin/bash

result_file=$1
cc=$(getconf _NPROCESSORS_ONLN)
servcore=$(( cc/2 ))
phi=$(( servcore-1 ))
cd /root/memc_redis

./mc_rds_in_vm.sh 0-${phi}  /root/$result_file 1 125 "memcache_text" $servcore

