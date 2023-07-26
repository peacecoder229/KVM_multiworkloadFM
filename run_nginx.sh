#!/bin/bash

result_file=$1
start_core=${2:-0}
end_core=${3:-$[$(getconf _NPROCESSORS_ONLN)-1]}
VM_EXP=${4:-True}

cd nginx_exp_dir
pwd
start=`date +%s`

echo "nginx_exp_dir/run_nginx.sh $start_core $end_core $VM_EXP > $result_file"
./run_nginx.sh $start_core $end_core $VM_EXP > $result_file

end=`date +%s`
runtime=$((end-start))
echo "runtime = $runtime" >> $result_file
mv $result_file ../
