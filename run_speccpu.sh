#!/bin/bash

# Set the following while running in baremetal
# On 90T SPEC_DIR="/home/spec17"
SPEC_DIR="/home/spec17"

result_file=$1
start_core=${2}
end_core=${3}
VM_EXP=${4}
workload=$5
n_iteration=$6 #1=???s, 2=815s, 3=1215s

n_copies=$((end_core-start_core+1))
#workload="541.leela_r" # n_iteration 2
#workload="511.povray_r" # n_iteration 2

start=`date +%s`

# copy scripts and cd to $SPEC_DIR/cpu2017
if [[ $VM_EXP == True ]]; then
  cd /root/spec17/cpu2017
  cp /root/speccpu_script/workload.sh ./
  cp /root/speccpu_script/shrc ./
  start_core=0
  end_core=$(($(getconf _NPROCESSORS_ONLN)-1))
  ./workload.sh $workload $start_core $end_core $n_iteration
else
  cp speccpu_script/workload.sh $SPEC_DIR/cpu2017
  cp speccpu_script/shrc $SPEC_DIR/cpu2017
  cd $SPEC_DIR/cpu2017
  ./workload.sh $workload $start_core $end_core $n_iteration
  rm -f workload.sh shrc
fi

end=`date +%s`
runtime=$((end-start))

# Send signal to vm monitoring server
if [[ $VM_EXP == True ]]; then
  python3 client.py $result_file
fi

# process result
total=0.0
for (( copy=start_core; copy <= end_core; copy++)); do
  log_file=$(grep "The log for this run is in" workload_${copy}.log | cut -d" " -f8)
  elapsed_times=$(grep -Irn "Total elapsed time:" $log_file | cut -d" " -f17)
  cur_avg_elapsed_time=$(echo $elapsed_times | awk '{for (i=1;i<=NF;i++) total+=$i; print total/NF}')
  echo "Current average elapsed time: $cur_avg_elapsed_time"
  total=$(awk "BEGIN { print $total + $cur_avg_elapsed_time }")
done

# come out of $SPEC_DIR/cpu2017 directory
cd - 

avg_elapsed_time=$(awk "BEGIN { print $total/$n_copies }")
echo "Average_Elapsed_time(s): $avg_elapsed_time,$runtime"
echo "Average_Elapsed_time(s), Runtime" > $result_file
echo "$avg_elapsed_time,$runtime" >> $result_file

# To get the performance data in tmc file
echo "**************** $result_file ************"
echo "$avg_elapsed_time, $runtime"
