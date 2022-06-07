
result_file=$1
n_copies=$(getconf _NPROCESSORS_ONLN)
workload="502.gcc_r"

cd /root/spec17/cpu2017

cp /root/speccpu_script/workload.sh ./
cp /root/speccpu_script/shrc ./

./workload.sh $workload $n_copies

grep "log for" workload.log | awk '{print $8}' | xargs cat > /root/$result_file

