#!/bin/bash

trexIP="10.242.51.175"

dpdkdevbind="python /root/dpdk/usertools/dpdk-devbind.py"
portBuses=$($dpdkdevbind -s | grep XXV710 | grep igb_uio  | awk '{print $1}')

portsConfig="1,1024,25 2,1024,24.984 4,1024,24.434"

for portConfig in $portsConfig;
do
  macArray=()
  for port in $portBuses;
  do
    $dpdkdevbind --bind=i40e $port
    macAddr=$(ip addr show dev $($dpdkdevbind -s | grep "$port" | awk '{split($9, a, "="); print a[2]}') \
              | grep ether | awk '{print $2}')
    macArray+=($macAddr)
    echo "MAC address for $port: $macAddr"
    $dpdkdevbind --bind=igb_uio $port
  done

  frameRate=$(echo $portConfig | awk '{split($0, a, ","); print a[3]}')
  frameSize=$(echo $portConfig | awk '{split($0, a, ","); print a[2]}')
  numPorts=$(echo $portConfig | awk '{split($0, a, ","); print a[1]}')

  highSeq=$(echo $numPorts - 1 | bc)
  # 2=0,1; 4=0,1,2,3
  portList=$(seq -s , 0 $highSeq)

  # Start TRex on other machine using the local config
  python trex-manager/trex-manager.py start --server $trexIP --config l3fwd/$numPorts-port.yaml

  # Get the MAC addresses of the interfaces used by TRex
  portMacs=$(python l3fwd/l3fwd.py --server $trexIP --ports 0,1,2,3 --printMAC)

  ethDestArray=()
  for portMac in $portMacs;
  do
    ethDestArray+=($portMac)
  done

  if [[ $numPorts == "1" ]]; then
    # 1 port for testing
    pushd /root/dpdk/examples/l3fwd/build
      echo "L3fwd will use --eth-dest=0,${ethDestArray[0]}"
      ./l3fwd -w 17:00.0 -l 2 -n 2 --socket-mem 2048 -- -p 0x1 --config="(0,0,2)" \
              --eth-dest="0,${ethDestArray[0]}" &> /tmp/dpdk-$numPorts-ports &
      sleep 5
    popd

    echo "TRex will send packets to destination: ${macArray[2]} from port 0"
    time python l3fwd/l3fwd.py --server $trexIP --ports $portList --portDest 0,${macArray[2]} \
                               --runTime 60 --frameRate $frameRate --frameSize $frameSize

  elif [[ $numPorts == "2" ]]; then
    pushd /root/dpdk/examples/l3fwd/build
      echo "L3fwd will use --eth-dest=0,${ethDestArray[1]} --eth-dest=1,${ethDestArray[0]}"
      ./l3fwd -w 15:00.0 -w 17:00.0 -l 2,3 -n 2 --socket-mem 2048 -- \
              -p 0x3 --config="(0,0,2),(1,0,3)" --eth-dest="0,${ethDestArray[1]}" --eth-dest="1,${ethDestArray[0]}" \
              &> /tmp/dpdk-$numPorts-ports &
      sleep 5
    popd

    echo "TRex will send packets to destination: ${macArray[0]} from port 0 and ${macArray[2]} from port 2"
    time python l3fwd/l3fwd.py --server $trexIP --ports $portList --portDest 0,${macArray[0]} --portDest 1,${macArray[2]} \
                               --runTime 60 --frameRate $frameRate --frameSize $frameSize
  elif [[ $numPorts == "4" ]]; then
    pushd /root/dpdk/examples/l3fwd/build
      echo "L3fwd will use --eth-dest=0,${ethDestArray[1]} --eth-dest=1,${ethDestArray[0]} --eth-dest=2,${ethDestArray[3]} --eth-dest=3,${ethDestArray[2]}"
      ./l3fwd -w 15:00.0 -w 15:00.1 -w 17:00.0 -w 17:00.1 -l 2,3,4,5 -n 2 --socket-mem 2048 -- \
              -p 0xf --config="(0,0,2),(1,0,3),(2,0,4),(3,0,5)" \
              --eth-dest="0,${ethDestArray[1]}" --eth-dest="1,${ethDestArray[0]}" \
              --eth-dest="2,${ethDestArray[3]}" --eth-dest="3,${ethDestArray[2]}" \
              &> /tmp/dpdk-$numPorts-ports &
      sleep 5
    popd

    echo "TRex will send packets to destination: ${macArray[0]} from port 0 and ${macArray[2]} from port 2"
    echo "TRex will send packets to destination: ${macArray[1]} from port 1 and ${macArray[3]} from port 3"
    time python l3fwd/l3fwd.py --server $trexIP --ports $portList --portDest 0,${macArray[0]} --portDest 1,${macArray[2]} \
                               --portDest 2,${macArray[1]} --portDest 3,${macArray[3]} \
                               --runTime 60 --frameRate $frameRate --frameSize $frameSize
  fi

  # Stop TRex
  python trex-manager/trex-manager.py stop --server $trexIP
  killall l3fwd
  sleep 15
done
