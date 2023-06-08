
result_file=$1
n_copies=$(getconf _NPROCESSORS_ONLN)
#workload="502.gcc_r"
workload="541.leela_r"
n_iteration=2 #1=???s, 2=815s, 3=1215s

start=`date +%s`

cd /root/spec17/cpu2017
cp /root/speccpu_script/workload.sh ./
cp /root/speccpu_script/shrc ./
./workload.sh $workload $n_copies $n_iteration
cd -

end=`date +%s`
runtime=$((end-start))

# Send signal to vm monitoring server
python3 client.py $result_file

# process result
total=0.0
for (( copy=0; copy < n_copies; copy++)); do
  log_file=$(grep "The log for this run is in" workload_${copy}.log | cut -d" " -f8)
  elapsed_times=$(grep -Irn "Total elapsed time:" $log_file | cut -d" " -f17)
  cur_avg_elapsed_time=$(echo $elapsed_times | awk '{for (i=1;i<=NF;i++) total+=$i; print total/NF}')
  echo "Current average elapsed time: $cur_avg_elapsed_time"
  total=$(awk "BEGIN { print $total + $cur_avg_elapsed_time }")
done

avg_elapsed_time=$(awk "BEGIN { print $total/$n_copies }")
echo "Average_Elapsed_time(s): $avg_elapsed_time,$runtime" 
echo "Average_Elapsed_time(s), Runtime" > $result_file
echo "$avg_elapsed_time,$runtime" >> $result_file
