#!/bin/bash

echo "run_redis.sh"

result_file=$1
start_core=${2:-0}
end_core=${3:-$[$(getconf _NPROCESSORS_ONLN)-1]}
VM_EXP=${4:-True}

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
no_of_requests=393216
#no_of_requests=786432

cd memc_redis
for (( i=1; i<=$no_of_iteration; i++)); do
  #if [[ $VM_EXP == True ]]; then
    echo "./mc_rds_in_vm.sh ${start_core}-${server_core_end} ../$result_file 1 125 "redis" $memtier_core_start $no_of_requests"
    ./mc_rds_in_vm.sh ${start_core}-${server_core_end} ../$result_file 1 125 "redis" $memtier_core_start $no_of_requests
  #else
  #  echo "./memc_redis_host/run_mc_rds.sh --lcore ${start_core}-${server_core_end} --res_dir $result_file --ins 1 --mccon $con --type redis --memtiercore $memtier_core_start --benchdir ./memc_redis_host/ --ratio 1:10 --dsize 64 --pipe 4 --servIP 127.0.0.1 > temp.out &"
  #  ./memc_redis_host/run_mc_rds.sh --lcore ${start_core}-${server_core_end} --res_dir $result_file --ins 1 --mccon $con --type redis --memtiercore $memtier_core_start --benchdir ./memc_redis_host/ --ratio 1:10 --dsize 64 --pipe 4 --servIP 127.0.0.1
    pid=$!
  #fi
done
cd -

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
