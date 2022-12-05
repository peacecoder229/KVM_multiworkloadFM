#!/bin/bash

core_range=$(lscpu | grep node0 | cut -f2 -d:)
hi_core=$(echo $core_range | cut -f2 -d-)
lo_core=$(echo $core_range | cut -f1 -d-)

total_core=$(getconf _NPROCESSORS_ONLN)
total_core=$(( hi_core + 1 ))
half_core=$(( total_core/2 ))
nginx_end_core=$(( half_core - 1 ))

./start-nginx.sh $lo_core-$nginx_end_core 80
echo "./start-nginx.sh $lo_core-$nginx_end_core 80"
sleep 4

start=`date +%s`

# wrk parameters
n_thread=$half_core
n_conn=$((n_thread*100)) # 100 conn/thread
duration="850s"
core_range="${half_core}-${hi_core}"
server="http://127.0.0.1:80/1K"
# Run wrk directly
set +x
echo "numactl --physcpubind=${half_core}-${hi_core} ./wrk/wrk -t $n_thread -c $n_conn -d ${duration} -L http://127.0.0.1:80/1K"
numactl --physcpubind=${half_core}-${hi_core} ./wrk/wrk -t $n_thread -c $n_conn -d ${duration} -L http://127.0.0.1:80/1K 
P0=$!
wait $P0

# Run wrk from python script
#echo "Running wrk using python script: python3 run_wrk_collect_data.py $core_range $n_thread $n_conn $duration $server "
#python3 run_wrk_collect_data.py $core_range $n_thread $n_conn $duration $server 

end=`date +%s`
runtime=$((end-start))
echo "runtime = $runtime" >> /root/$result_file

./clean.sh

cd ..
