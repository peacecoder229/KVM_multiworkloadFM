#!/bin/bash

result_file=$1
total_cores=$(getconf _NPROCESSORS_ONLN)
docker exec pytorch_spr_2022_ww16 /bin/bash -c "/home/dataset/pytorch/run_rnnt_exec.sh $total_cores"

cd /home/dataset/pytorch

# process data after run
start=0
total_avg=0.0
for log in *.log; do
  avg=$(grep "Throughput:" $log | awk '{print $2}')
  
  total_avg=$(awk "BEGIN{ print $avg + $total_avg}")

  start=$((start+4))
done

cd -

echo "$total_avg" > /root/$result_file
