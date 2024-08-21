  mode=cpat
  lp_core=24
  result_file=redis_$lp_core
  db_file="../dump.rdb"
  start_core=24
  end_core=27

  redis_pids=()
  port_no=9001
  for (( i=$start_core; i<=$end_core; i++ )); do
    cp -f $db_file temp-$i.rdb
    cp -f ../redis.conf temp-$i.conf
    echo "Update redis conf: temp-$i.conf ...."
    sed -i "s/^port PORT_NO$/port $port_no/" temp-$i.conf
    sed -i "s/^dbfilename DB_NAME.rdb$/dbfilename temp-$i.rdb/" temp-$i.conf

    taskset -c $i redis-server  temp-$i.conf & # pin to cpu
    #numactl --cpunodebind=0 --localalloc redis-server  temp-$i.conf & # pin to numanode
    redis_pids+=($!)
  
    port_no=$((port_no+1))
  done

  sleep 10

  echo "Waiting for the servers to be up ....."
  port_no=9001
  for (( i=$start_core; i<=$end_core; i++ )); do
    while [ $(redis-cli -h 127.0.0.1 -p $port_no info | grep -c loading:1) == "1" ]; do
    #echo "Waiting for database loading. Status: $(redis-cli -h $redis_container_ip  -p $port_no info | grep -c loading:1)"
      sleep 10
    done
    port_no=$((port_no+1))
  done
  
  if [ "$mode" == "resctrl" ]; then
    echo "Associate redis server pids to clos ...."
    for pid in "${redis_pids[@]}"; do
      echo $pid > /sys/fs/resctrl/COS4/tasks
    done
  fi
  
  # run memtier benchhmark
  start=`date +%s`
  port_no=9001
  mb_pids=()
  for (( i=$start_core; i<=$end_core; i++ )); do
    numactl --cpunodebind=1 --localalloc memtier_benchmark -s 127.0.0.1 -p $port_no --key-prefix= --key-minimum=1 --key-maximum=630838 --show-config --threads=1 --clients=6 --pipeline=8 --test-time=300 --data-size=32 --ratio=0:1 --key-pattern=G:G >  /root/vm_coloc_framework/cpat_host_exp/${result_file}_${port_no} &
    pids+=($!)
    port_no=$((port_no+1))
  done

