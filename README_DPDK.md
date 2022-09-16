## Create two VMs with DPDK cloned and its prerequisites installed:
- Setup SRIOV (link to the SRIOV document.) or OVS-Bridge (link to OVS_README.md).
- Spawn two VMs one with 5 cores and another with 4 cores: ```./run.sh -A -T vm -S setup -C 5,4 -W dpdk,dpdk```
  
- To run **l2fwd**, create the VMs with the number of interfaces equals to the number of cores you want to run l2fwd on. Open `virt-install-cmds.sh` and add the pci address (otained from setting up SRIOV) of the VFs (--host-device=<pci address of VF>) in the virt install command. For example,

```
virt-install --import -n dpdk-01 -r 81920 --vcpus=5 --os-type=linux \
  --os-variant=centos7.0 --accelerate \ 
  --disk path=/home/vmimages2/5g-01.qcow2,format=raw,bus=virtio,cache=writeback \
  --disk path=/home/vmimages2/5g-01.iso,device=cdrom \
  --network bridge=virbr0 --host-device=pci_0000_27_02_1 \
  --host-device=pci_0000_27_01_0 --host-device=pci_0000_27_01_1  --host-device=pci_0000_27_01_2 --host-device=pci_0000_27_01_3 \
  --cpuset 47,46,45,44,43 --noautoconsole --cpu host-passthrough,cache.mode=passthrough --nographics
```

Then execute the command: ```./virt-install-cmds.sh```

  - To run **l3fwd**, create the VMs with an interface with number of queues equals to the number of cores you want to run l3fwd on. Add the following line in the xml file:
  ``` <driver name='vhost' queues='4'/> ```
  Inside the VM check if the corresponding nic has 4 queues: ``` ethtool -l <interface> ```

## Setup DPDK on both the VMs:
1. Build DPDK:
  ```
  cd /root/dpdk
  meson build -Dexamples=l2fwd,l3fwd
  ninja -C build
  ```
2. Bind the SRIOV or OVS-Bridge associated interface to the DPDK driver:
  ```
  cd usertools/
  python3 dpdk-devbind.py -s
  modprobe vfio-pci
  echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode # why is it needed
  ip link set dev eth1 down
  python3 dpdk-devbind.py -b vfio-pci <PCI address of the device>
  python3 dpdk-devbind.py -s
  ```
3. Set up hugepages:
  ```
  python3 dpdk-hugepages.py -p 2M --setup 2048M
  grep -i huge /proc/meminfo 
  ```

## Run L2 forwarder and testpmd traffic on dpdk-01 and dpdk-02 VMs respectively:
### VM dpdk-01
```
cd /root/dpdk/build/examples/
./dpdk-l2fwd -l 1-4 -- -p f
```
### VM dpdk-02
1. ``` cd /root/dpdk/build/app ```
2. Run the testpmd app in interactive mode: ``` ./dpdk-testpmd -- --eth-peer 0,<MAC address of the receiver> -i ```
3. Start transmission in the testpmd prompt:
``` 
start tx_first
show fwd stats all # to see the forwarding status of all the ports 
```

## Run L3-forwarder on dpdk-01 VM and trex on dpdk-02:
### VM dpdk-01
1. ``` cd /root/dpdk/build/examples ```
2. Disable all the options in rte_eth_conf (make them zero) of l3fwd/main.c (TODO: Enable the offload features in the NIC)
3. Run l3fwd on CPU1 and CPU2, each using tx/rx queue 0 and 1 respectively (--config (port,queue,lcore)): 
  ```
  ./dpdk-l3fwd -l 1,2 -- -p 0x1 -P --config="(0,0,1),(0,1,2)" --parse-ptype --eth-dest=0,< MAC Address of dpdk-02s DPDK port>
  
  ``` 

### VM dpdk-02
1. Build, install TRex:
```
git clone https://github.com/cisco-system-traffic-generator/trex-core /opt/
cd /opt/trex-core/linux_dpdk
./b configure
./b
```
2. Run TRex:
  - Create a config file called trex_cfg.yaml for TRex:
  ```
  - port_limit: 2 # required: should be equal to the number of interfaces
  version: 2 # reauired: should be 2
  # PCI address of the interface bind to dpdk driver
  interfaces: ['03:00.0', 'dummy'] # required: MAC address of the interfaces
  c: 1 # optional: Number of threads (cores) TRex will use per interface pair
  port_info:
        - ip: 1.1.1.1
          default_gw: 2.2.2.2
        - ip: 2.2.2.2
          default_gw: 1.1.1.1
  platform:
        master_thread_id: 1 # HW thread_id for control thread
        latency_thread_id: 2 # Hardware thread_id for RX thread
        dual_if:
         - socket: 0# The NUMA node from which memory will be allocated for use by the interface pair.
           threads: [3]
  ```
  - Start TRex: ``` cd /opt/trex-core/scripts && ./t-rex-64 -i --cfg <path to trex_cfg.yaml> ```
    If the config file is copied to /etc/trex_cfg.yaml, then don't have to specify in the command.

3. Generate traffic:
```
git clone https://github.com/intel-sandbox/sos-scripts /root/
cd /root/sos-scripts/TRex/l3fwd
python3 l3fwd.py --ports 0 --portDest 0,< Mac address of VM dpdk-01s port> --frameRate=1
```
