#!/bin/bash

wl_core_range=$1 #comma sperated list of workload:startcore-endcore, e.g. redis:46-47, mlc:44-45
file_suffix=$2
result_dir=$3

echo "run_in_host.sh $wl_core_range $file_suffix $result_dir"

declare -a result_file_list # list of result file names

for wl_core in ${wl_core_range//,/ }; do
  # comma seperated list of speccpu has the following format: speccpu:502.gcc_r:3:46-47,speccpu:511.povray_r:1:44-45
  if [[ $wl_core == *"speccpu"* ]]; then
      benchmark=$(echo $wl_core | cut -d: -f2)
      n_iteration=$(echo $wl_core | cut -d: -f3)
      start_core=$(echo $wl_core | cut -d: -f4 | cut -d- -f1)
      end_core=$(echo $wl_core | cut -d: -f4 | cut -d- -f2)
      echo "$benchmark will run in core range: $start_core-$end_core"

      result_file=${benchmark}_${start_core}-${end_core}_${file_suffix}
      result_file_list+=($result_file)

      bash run_speccpu.sh $result_file $start_core $end_core False $benchmark $n_iteration & # VM_EXP flag is false
      
      pid=$!
      echo "echo $pid > $core_range.txt"
      echo $pid > $core_range.txt
      cat $core_range.txt

  else 
      wl=$(echo $wl_core | cut -d: -f1)
      start_core=$(echo $wl_core | cut -d: -f2 | cut -d- -f1)
      end_core=$(echo $wl_core | cut -d: -f2 | cut -d- -f2)
      echo "$wl will run in core range: $start_core-$end_core"
      
      result_file=${wl}_${start_core}-${end_core}_${file_suffix}
      result_file_list+=($result_file)
  
      echo "bash run_${wl}.sh $result_file $start_core $end_core False"
      bash run_${wl}.sh $result_file $start_core $end_core False  & # VM_EXP flag is false
      
      pid=$!
      echo "echo $pid > $core_range.txt"
      echo $pid > $core_range.txt
      cat $core_range.txt
  fi
done

echo "Waiting for the workloads to finish ...."
workload_pids=($!)
wait "${pids[@]}"

echo "Move result files to result directory ..."
for result_file in "${result_file_list[@]}"; do
  echo "mv $result_file $result_dir"
  mv $result_file $result_dir
done
