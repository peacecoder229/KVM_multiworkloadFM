cd /root/dpdk/usertools/
ip addr > net_interface_info.txt

eth1_pci=$(python3 dpdk-devbind.py -s | grep eth1 | awk '{print $1}')

reset=$1
modprobe vfio-pci
echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode # why is it needed
ip link set dev eth1 down
python3 dpdk-devbind.py -b vfio-pci $eth1_pci
python3 dpdk-hugepages.py -p 2M --setup 2048M
cd -

# reset 
#cd /root/dpdk/usertools/
#python3 dpdk-devbind.py -u $eth1_pci
#python3 dpdk-devbind.py -b virtio-pci $eth1_pci
#cd -
