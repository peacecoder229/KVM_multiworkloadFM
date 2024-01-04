#!/bin/bash

lo_core=$1
hi_core=$2
VM_EXP=${3:-True}

total_core=$(( hi_core-lo_core+1 ))
half_core=$(( total_core/2 ))

echo "nginx_exp_dir/run_nginx.sh $lo_core $hi_core $VM_EXP"

# Params value for baremetal
wrk_start_core=48
nginx_end_core=$hi_core

# Params value for VM
if [[ $VM_EXP == True ]]; then
  nginx_end_core=$(( lo_core+half_core - 1 ))
  wrk_start_core=$((lo_core+half_core ))
fi

echo "./start-nginx.sh $lo_core-$nginx_end_core 80"
./start-nginx.sh $lo_core-$nginx_end_core 80
sleep 4

# wrk parameters
n_thread=$total_core # for baremetal
wrk_end_core=$((wrk_start_core+$total_core-1)) # for baremetal
if [[ $VM_EXP == True ]]; then # for VM
  n_thread=$half_core
  wrk_end_core=$hi_core
fi
n_conn=1000 #$((n_thread*100)) # 100 conn/thread
duration="100s"
server="http://127.0.0.1:80/1K"
# Run wrk directly
echo "numactl --physcpubind=${wrk_start_core}-${wrk_end_core} ./wrk/wrk -t $n_thread -c $n_conn -d ${duration} -L http://127.0.0.1:80/1K"
numactl --physcpubind=${wrk_start_core}-${wrk_end_core} ./wrk/wrk -t $n_thread -c $n_conn -d ${duration} -L http://127.0.0.1:80/1K 
P0=$!
wait $P0

# Run wrk from python script
#echo "Running wrk using python script: python3 run_wrk_collect_data.py $core_range $n_thread $n_conn $duration $server "
#python3 run_wrk_collect_data.py $core_range $n_thread $n_conn $duration $server 

./clean.sh

cd ..
