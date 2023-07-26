#!/bin/bash

wl_core_range=$1 #comma sperated list of workload_startcore-workload_endcore, e.g. redis_46-47, mlc_44-45
file_suffix=$2
result_dir=$3

echo "run_in_host.sh"

declare -a result_file_list # list of result file names

for wl_core in ${wl_core_range//,/ }; do
  wl=$(echo $wl_core | cut -d_ -f1)
  start_core=$(echo $wl_core | cut -d_ -f2 | cut -d- -f1)
  end_core=$(echo $wl_core | cut -d_ -f2 | cut -d- -f2)
  echo "$wl will run in core range: $start_core-$end_core"
  
  result_file=${wl}_${start_core}-${end_core}_${file_suffix}
  result_file_list+=($result_file)
  
  echo "bash run_${wl}.sh $result_file $start_core $end_core False"
  bash run_${wl}.sh $result_file $start_core $end_core False  & # VM_EXP flag is false
done

echo "Waiting for the workloads to finish ...."
workload_pids=($!)
wait "${pids[@]}"

echo "Move result files to result directory ..."
for result_file in "${result_file_list[@]}"; do
  echo "mv $result_file $result_dir"
  mv $result_file $result_dir
done
