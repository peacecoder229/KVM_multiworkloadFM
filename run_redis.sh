#!/bin/bash

result_file=$1
start_core=${2:-0}
end_core=${3:-$[$(getconf _NPROCESSORS_ONLN)-1]}
VM_EXP=${4:-True}

# Script for running L2
./run_redis_l2.sh $result_file $start_core
#pkill redis-server
exit

# Total no. of keys in the dump.rdb is 738557, size (18MB). For L2 using --key-maximum 82061 (size of the L2 cache)
# Also load lower number of keys during load phase. Search for "Loading" in memc_redis/mc_rds_in_vm.sh

# Find the memtier_benchmark command in exhaustclientcores() of  memc_redis/core_scale/memtier_client_server_modules.py. Can change the memtier parameter there or in memc_redis/core_scale/client_memt.sh

no_of_connections=20

# Params for Baremetal
memtier_core_start=48 # run memtier in another socket
server_core_end=$end_core # run redis/memcache in the start_core to end_core
export runnuma="yes"

# Do the following when running VM experiments
if [[ $VM_EXP == True ]]; then
  cc=$((end_core-start_core+1))
  servcore=$((cc/2))
  server_core_end=$((servcore-1))
  memtier_core_start=$servcore
  export runnuma="None"
fi

# 1 iteration: 393216 = 836s, 1048576 = ???s
no_of_iteration=1
#no_of_requests=393216
no_of_requests=1966080 # for L2 exp when we use smaller data size need to use more no. of requests to increase the experiment runtime

cd memc_redis
for (( i=1; i<=$no_of_iteration; i++)); do
  #if [[ $VM_EXP == True ]]; then
    echo "./mc_rds_in_vm.sh ${start_core}-${server_core_end} ../$result_file 1 $no_of_connections redis $memtier_core_start $no_of_requests"
    ./mc_rds_in_vm.sh ${start_core}-${server_core_end} ../$result_file 1 $no_of_connections "redis" $memtier_core_start $no_of_requests
    pid=$!
    sleep 15
    memsize=$( ps aux | grep redis-server | awk '{print $2}' | xargs -I{} pmap -x {} | awk '/total/ {print $4}' | awk '{sum += $1} END {print sum}')
    wait $pid
done

cd -

#pkill redis-server

lcore=$(tail -1 $result_file | cut -d, -f1)
total=$(tail -1 $result_file | cut -d, -f2)
instances=$(tail -1 $result_file | cut -d, -f3)
connections=$(tail -1 $result_file | cut -d, -f4)
avg_min=$(awk '{ if(NR > 1) {total += $5; count++} } END {print total/count}' $result_file )
avg_max=$(awk '{ if(NR > 1) {total += $6; count++} } END {print total/count}' $result_file )
avg_avg=$(awk '{ if(NR > 1) {total += $7; count++} } END {print total/count}' $result_file )
avg_p99=$(awk '{ if(NR > 1) {total += $8; count++} } END {print total/count}' $result_file )
avg_p75=$(awk '{ if(NR > 1) {total += $9; count++} } END {print total/count}' $result_file )
avg_throughput=$(awk '{ if(NR > 1) {total += $10; count++} } END {print total/count}' $result_file )
total_runtime=$(awk '{ if(NR > 1) {total += $11; count++} } END {print total}' $result_file)

#echo "physcores, totalcores,instance, connections, min, max, avg, p99, p75, throughput, Total Runtime" > $result_file
#echo "$lcore, $total, $instances, $connections, $avg_min, $avg_max, $avg_avg, $avg_p75, $avg_p99, $avg_throughput, $total_runtime" >> $result_file
#python3 client.py $result_file
