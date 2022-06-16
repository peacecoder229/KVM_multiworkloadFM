#!/bin/bash

result_file=$1
cc=$(getconf _NPROCESSORS_ONLN)
servcore=$(( cc/2 ))
phi=$(( servcore-1 ))

# 393216 = 836s, 1048576 = ???s
no_of_requests=393216

cd /root/memc_redis

./mc_rds_in_vm.sh 0-${phi} /root/$result_file 1 125 "redis" $servcore $no_of_requests

cd -

python3 client.py $result_file
