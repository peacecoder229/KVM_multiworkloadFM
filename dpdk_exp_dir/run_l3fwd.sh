
dest_eth="3c:fd:fe:a5:4a:20"

port=0
queue=0

last_core=$(lscpu | grep node0 | cut -f2 -d: | cut -f2 -d-)
last_core=0

#(port,queue,lcore)
port_queue_lcore=""
lcores=""
for lcore in $(seq 0 $last_core); do
  if [ $lcore -eq $last_core ]; then
    port_queue_lcore+="($port,$queue,$lcore)"
    lcores+="$lcore"
  else
    port_queue_lcore+="($port,$queue,$lcore),"
    lcores+="$lcore,"
  fi

  queue=$((queue+1))
done

dpdk_l3fwd_cmd="./dpdk-l3fwd -l $lcores -- -p 0x1 -P --config="$port_queue_lcore" --parse-ptype --eth-dest=0,$dest_eth"

echo "$dpdk_l3fwd_cmd" 

#cd /root/dpdk/build/examples
cd /home/muktadir/dpdk/build/examples
$dpdk_l3fwd_cmd
cd -
