#!/bin/bash

cc=$(getconf _NPROCESSORS_ONLN)
result_dir=${1}_${cc}
servcore=$(( cc/2 ))
phi=$(( servcore-1 ))
cd /root/memc_redis
./mc_rds_in_vm.sh 0-${phi} /root/$result_dir 1 16 "redis" $servcore
