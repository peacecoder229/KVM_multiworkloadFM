#!/bin/bash

# dump-128kb.rdb: 150 keys
# dump-256kb.rdb: 300 keys
# dump-512kb.rdb: 600 keys
# dump-1mb.rdb: 1400 keys
# dump-2mb.rdb: 2500 keys

result_file=$1
start_core=$2
end_core=$3

db_file="dump-2mb.rdb"

#cp dump-256kb.rdb $conf_file

#echo 3 > /proc/sys/vm/drop_caches && swapoff -a && swapon -a

#mkdir /sys/fs/cgroup/memory/redis-cgroup
#echo 1048576 > /sys/fs/cgroup/memory/redis-cgroup/memory.limit_in_bytes

port_no=9001
for (( i=$start_core; i<=$end_core; i++ )); do
  cp -f $db_file temp-$i.rdb
  cp -f redis.conf temp-$i.conf
  echo "Update redis conf: temp-$i.conf ...."
  sed -i "s/^port PORT_NO$/port $port_no/" temp-$i.conf
  sed -i "s/^dbfilename DB_NAME.rdb$/dbfilename temp-$i.rdb/" temp-$i.conf

  echo "taskset -c $i redis-server  temp-$i.conf &"
  taskset -c $i redis-server  temp-$i.conf &

  port_no=$((port_no+1))
done

sleep 20
#redis_pid=$!
#echo $redis_pid > /sys/fs/cgroup/memory/redis-cgroup/cgroup.procs

# Wait for the servers to be up
port_no=9001
for (( i=$start_core; i<=$end_core; i++ )); do
  while [ $(redis-cli -h 127.0.0.1 -p $port_no info | grep -c loading:1) == "1" ]; do
    #echo "Waiting for database loading. Status: $(redis-cli -h $redis_container_ip  -p $port_no info | grep -c loading:1)"
    sleep 10
  done
  port_no=$((port_no+1))
done

# print memory used by each server
port_no=9001
for (( i=$start_core; i<=$end_core; i++ )); do
  redis-cli -h 127.0.0.1 -p $port_no info | grep used_memory
  port_no=$((port_no+1))
done

# run memtier benchhmark
start=`date +%s`
port_no=9001
mb_pids=()
for (( i=$start_core; i<=$end_core; i++ )); do
  numactl --cpunodebind=1 --localalloc memtier_benchmark -s 127.0.0.1 -p $port_no --key-prefix= --key-minimum=1 --key-maximum=2500 --show-config --threads=1 --clients=6 --pipeline=8 --test-time=100 --data-size=32 --ratio=0:1 --key-pattern=G:G --key-stddev=500 --json-out-file run-$i.json > ${result_file}_${port_no} &
  mb_pids+=($!)
  port_no=$((port_no+1))
done

# Wait for the memtier benchmark to finish
for pid in "${mb_pids[@]}"; do
  wait $pid
done

total_thruput=0.0
total_p99=0.0
port_no=9001
for (( i=$start_core; i<=$end_core; i++ )); do
  thruput=$(cat ${result_file}_${port_no} | grep "Totals" | awk '{print $2}')
  p99=$(cat ${result_file}_${port_no} | grep "Totals" | awk '{print $7}')
  total_thruput=$(echo "$total_thruput + $thruput" | bc)
  total_p99=$(echo "$total_p99 + $p99" | bc)
  echo "$total_thruput, $total_p99"
  port_no=$((port_no+1))
done

total_instances=$((end_core-start_core+1))
thruput=$(echo "scale=2 ; $total_thruput/$total_instances" | bc)
p99=$(echo "scale=2 ; $total_p99/$total_instances" | bc)

#cat ${result_file}_temp | grep "Totals" | awk '{print $2, $7}' > $result_file

end=`date +%s`
runtime=$((end-start))

echo "Throughput, p99, runtime" > $result_file
echo "$thruput, $p99, $runtime" >> $result_file
sleep 10

redis-cli -h 127.0.0.1 -p $port info | grep used_memory >> $result_file

pkill redis-server
