
result_file=$1
n_copies=$(getconf _NPROCESSORS_ONLN)
workload="502.gcc_r"

cd /root/spec17/cpu2017

cp /root/speccpu_script/workload.sh ./
cp /root/speccpu_script/shrc ./

./workload.sh $workload $n_copies

cd -

# process result
total=0.0
for (( copy=0; copy < n_copies; copy++)); do
  log_file=$(grep "The log for this run is in" workload_${copy}.log | cut -d" " -f8)
  elapsed_time=$(grep -Irn "Total elapsed time:" $log_file | cut -d" " -f17)
  echo "Elapsed time: $elapsed_time"
  total=$(awk "BEGIN { print $total+$elapsed_time }")
done

avg_elapsed_time=$(awk "BEGIN { print $total/$n_copies }")
echo "Average_Elapsed_time(s): $avg_elapsed_time" 
echo "Average_Elapsed_time(s)" > $result_file
echo $avg_elapsed_time >> $result_file
