#!/bin/bash

result_file=$1
cc=$(getconf _NPROCESSORS_ONLN)
servcore=$(( cc/2 ))
phi=$(( servcore-1 ))

# 1 iteration: 393216 = 836s, 1048576 = ???s
no_of_iteration=1
no_of_requests=393216
#no_of_requests=786432

cd /root/memc_redis
for (( i=1; i<=$no_of_iteration; i++)); do
  ./mc_rds_in_vm.sh 0-${phi} /root/$result_file 1 125 "redis" $servcore $no_of_requests
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
python3 client.py $result_file
