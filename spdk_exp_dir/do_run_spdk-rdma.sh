
echo 1024 > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages

cd /root/spdk
pwd
pkill -9 reactor
killall -9 reactor_24 reactor_0

# Get the coremask of all the vm cores
total_cpus=$(getconf _NPROCESSORS_ONLN)
# total cpus = 8 ---bitamsk---> 11111111 ---corresponding decimal----> 255
# 2=11 (3), 3=111 (7), 4=1111(15)
bitmask=""
for ((i=0; i<$total_cpus; i++)); do
  bitmask="${bitmask}1"
done
bitmask_dec=$((2#${bitmask}))

echo "build/bin/nvmf_tgt -m 0x$bitmask_dec"
#./build/bin/nvmf_tgt -m 0x$bitmask_dec & # Cores 24,25,26,27 # 0x3
./build/bin/nvmf_tgt -m 0xf & # Cores 24,25,26,27 # 0x3

# Get PCI address of nvme
./scripts/setup.sh status | grep NVMe > nvme.txt
nvme_pci_addr=$(cat nvme.txt | awk '{print $2}')
nvme_pci_addr=${nvme_pci_addr//:/.}

sleep 1

scripts/rpc.py nvmf_create_transport -t RDMA -u 8192 -i 131072 -c 8192
sleep 2

n_devices=0 # no of devices
port=4420
for nvme in $nvme_pci_addr; do
  echo "scripts/rpc.py bdev_nvme_attach_controller -b Nvme${n_devices} -t PCIe -a $nvme" # change this address for another nvme device
  nvme_name=$(scripts/rpc.py bdev_nvme_attach_controller -b Nvme${n_devices} -t PCIe -a $nvme) # change this address for another nvme device
  
  echo "scripts/rpc.py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode${n_devices} -a -s SPDK0000000000000$i -d SPDK_Controller${n_devices}"
  scripts/rpc.py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode${n_devices} -a -s SPDK0000000000000$i -d SPDK_Controller${n_devices}
  sleep 2 
  
  echo "scripts/rpc.py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode${n_devices} $nvme_name"
  scripts/rpc.py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode${n_devices} $nvme_name
  sleep 2

  echo "scripts/rpc.py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode${n_devices} -t rdma -a 192.168.232.254 -s $port"
  scripts/rpc.py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode${n_devices} -t rdma -a 192.168.232.254 -s $port
  
  n_devices=$((n_devices+1))
  port=$((port+1))
done

# The following commands will be executed in 319 machine.
ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "ifconfig ens1 192.168.232.250 up"
sleep 5
ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "modprobe nvme-rdma"
sleep 1 

# Connect 319 (10.242.51.105) to this machine's nvme drive. After connecting, this machine's nvme drive should be visible in 319(10.242.51.105) (Try "nvme list" command in 319)
port=4420
n=0
declare -a process_list
for (( i=0; i<$n_devices; i++ )); do
  echo "ssh -o 'StrictHostKeyChecking no' root@10.242.51.105 "nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode$i" -a 192.168.232.254 -s $port""
  ssh -o 'StrictHostKeyChecking no' root@10.242.51.105 "nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode$i" -a 192.168.232.254 -s $port"
  sleep 2
  
  # Start writing from 319 (10.242.51.105) to the this machine's nvme drive
  echo "ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "dd if=/dev/nvme${i}n1 of=/dev/null bs=256K count=6553500" &"
  ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "dd if=/dev/nvme${i}n1 of=/dev/null bs=256K count=6553500" &
  process_list+=($!)
  sleep 5

  port=$((port+1))
done

echo "Waiting for the last job to finish"
for i in "${process_list[@]}"; do
  echo "Waiting for process: $i"
  wait $i
done
echo "All jobs are done."
pkill -9 reactor
killall -9 reactor_*

# Disconnect 319(10.242.51.105) from this machine's nvme drive.
for (( i=0; i<$n_devices; i++ )); do
  echo "ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme disconnect -n "nqn.2016-06.io.spdk:cnode$i"""
  ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme disconnect -n "nqn.2016-06.io.spdk:cnode$i""
done
