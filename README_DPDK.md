# Create two VM with DPDK cloned and its prerequisites installed:
1. Setup SRIOV (link to the SRIOV document.)
2. ./run.sh -A -T vm -S setup -C 16,16 -W dpdk,dpdk

# Setup DPDK on both the VMs:
1. cd /root/dpdk
2. meson build -Dexamples=l2fwd,l3fwd
3. ninja -C build
4. cd usertools/
5. python3 dpdk-devbind.py -s
6. modprobe vfio-pci
7. echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode # why is it needed
8. ip link set dev eth1 down
9. python3 dpdk-devbind.py -b vfio-pci 05:00.0
10. python3 dpdk-devbind.py -s
11. python3 dpdk-hugepages.py -p 2M --setup 2048M
12. grep -i huge /proc/meminfo 

# Run L2 forwarder on dpdk-01 VM:
1. cd /root/dpdk/build/examples/
2. ./dpdk-l2fwd -a 05:00.0 -l 1 -- -p 0x1

# Run testpmd traffic generator on dpdk-02 VM:
1. cd /root/dpdk/build/app
2. Run the testpmd app in interactive mode: ./dpdk-testpmd -a 05:00.0 -- --eth-peer 0,16:11:AD:7A:2B:E6 -i
3. Start transmission in the testpmd prompt: 
3.1. start tx_first
3.2. show fwd stats all

# Setup trex traffic generator (not done yet)
mkdir -p /opt/trex
cd /opt/trex
yum install -y wget
wget --no-cache --no-check-certificate https://trex-tgn.cisco.com/trex/release/latest
tar -xzvf latest
