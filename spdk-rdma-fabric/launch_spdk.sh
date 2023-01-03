#Author: Rohan Tabish
#Description: Creates a SPDK device over the RDMA and transfers the data
#!/bin/bash
killall -9 reactor_24 reactor_0


build/bin/nvmf_tgt -m 0x0000060 & # Cores 24,25,26,27

sleep 1
scripts/rpc.py nvmf_create_transport -t RDMA -u 8192 -i 131072 -c 8192
scripts/rpc.py bdev_nvme_attach_controller -b Nvme0 -t PCIe -a 0000:81:00.0 # change this address for another nvme device
scripts/rpc.py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode1 -a -s SPDK00000000000001 -d SPDK_Controller1
scripts/rpc.py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode1 Nvme0n1
scripts/rpc.py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode1 -t rdma -a 192.168.232.254 -s 4420

scripts/rpc.py nvmf_create_transport -t RDMA -u 8192 -i 131072 -c 8192
scripts/rpc.py bdev_nvme_attach_controller -b Nvme1 -t PCIe -a 0000:98:00.0 # change this address for another nvme device
scripts/rpc.py nvmf_create_subsystem nqn.2016-06.io.spdk:cnode2 -a -s SPDK00000000000002 -d SPDK_Controller2
scripts/rpc.py nvmf_subsystem_add_ns nqn.2016-06.io.spdk:cnode2 Nvme1n1
scripts/rpc.py nvmf_subsystem_add_listener nqn.2016-06.io.spdk:cnode2 -t rdma -a 192.168.232.254 -s 4425




ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "ifconfig ens1 192.168.232.250 up"
sleep 5

ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "modprobe nvme-rdma"

sleep 1 

ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode1" -a 192.168.232.254 -s 4420" 
ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme connect -t rdma -n "nqn.2016-06.io.spdk:cnode2" -a 192.168.232.254 -s 4425" 


sleep 2

ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "dd if=/dev/nvme0n1 of=/dev/null bs=256K count=6553500" &
ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "dd if=/dev/nvme1n1 of=/dev/null bs=256K count=6553500" 

sleep 2

ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme disconnect -n "nqn.2016-06.io.spdk:cnode1"" 

ssh -o 'StrictHostKeyChecking no'  root@10.242.51.105 "nvme disconnect -n "nqn.2016-06.io.spdk:cnode2""



