## Running FIO with SPDK in host
1. Clone and build FIO:
```
git clone https://github.com/axboe/fio 
cd fio/
make
cd ..
```

2. Clone, install prequisites for SPDK, and build it:
```
git clone https://github.com/spdk/spdk
cd spdk/
git submodule update --init
./scripts/pkgdep.sh # to install the dependencies
./configure --with-fio=/root/fio
make
python3 dpdk/usertools/dpdk-hugepages.py -p 2M --setup 2048M # Setup huge page
```

3. Unbind the NVME drive from the kernel:
- If you are using the NVME drive for the first time, need to format the NVME drive, for example:
```
nvme reset /dev/nvme0n1
nvme format /dev/nvme0n1
```
- Specify the drives you want to use for the experiment in PCI_ALLOWED environemnt variable: `PCI_ALLOWED="0000:49:00.0 0000:4b:00.0"` 
- The following command will only bind the nvme drives specified in the PCI_ALLOWED variable to vfio-pci: `./scripts/setup.sh`
- The drive should not show up in `lsblk`. If it shows up it means the drive is active and binding with the vfio-pci drive was not successful.
- After you are done with FIO+SPDK experiment, you can bind the nvme device back to the kernel driver using the following command: `./scripts/setup.sh reset`

4. To make sure nvme device got bound with the PMD, run the perf test.
```
/root/spdk/build/examples/perf -q 32 -s 1024 -w randwrite -t 60 -c 0xF -o 4096 -r 'trtype:PCIe traddr:0000:49:00.0'
```

5. Run FIO with SPDK
- Create a SPDK config file (e.g. fio_config) like the following:
```
[global]
ioengine=spdk
thread=1
group_reporting=1
direct=1
verify=0
time_based=1
ramp_time=0
runtime=2
iodepth=128
rw=randrw
size=4096

filename=trtype=PCIe traddr=0000.49.00.0 ns=1 # specify the PCI address of the nvme drive

[test]
numjobs=1
```

- Run FIO with the config file:
```
LD_PRELOAD=/root/spdk/build/fio/spdk_nvme /root/fio/fio fio_config
```

## Running FIO with SPDK in VM
1. Open `spdk_exp_dir/fio_vm_config.yaml` and add the pci addresses of your NVME devices in PT_Device["NVME"]. An example is given below:
```
#pass through devices (NIC, GPU, NVME),
PT_Device = {
    GPU:  []
    NIC:  []
    NVME: [ "pci_0000_49_00_0" ], # Add the PCI addresses of the NVME devices here (seperated by comma)
    #"NVME": []
}
```
2. Spawn a VM with 5 cores and specify `spdk_fio`  
```
./run.sh -A -T vm -S setup -C 5 -W spdk_fio -F spdk_exp_dir/fio_vm_config.yaml
```
2. Now follow the steps from (2)-(5) in `Running FIO with SPDK in host`.

## Experiment Result
### GDC3200-28T090T
1. Running FIO with SPDK for 60 seconds
- In VM:
```
READ: bw=86.4MiB/s (90.6MB/s), 86.4MiB/s-86.4MiB/s (90.6MB/s-90.6MB/s), io=5182MiB (5434MB), run=60005-60005msec
WRITE: bw=86.3MiB/s (90.5MB/s), 86.3MiB/s-86.3MiB/s (90.5MB/s-90.5MB/s), io=5176MiB (5428MB),run=60005-60005msec
```
- In Host:
```
READ: bw=1784MiB/s (1871MB/s), 1784MiB/s-1784MiB/s (1871MB/s-1871MB/s), io=105GiB (112GB), run=60001-60001msec
WRITE: bw=1784MiB/s (1871MB/s), 1784MiB/s-1784MiB/s (1871MB/s-1871MB/s), io=105GiB (112GB), run=60001-60001msec
```

2. Running the Perf test for 60 seconds:
- In VM:
```
# /root/spdk/build/examples/perf -q 32 -s 1024 -w randwrite -t 60 -c 0x1 -o 4096 -r 'trtype:PCIe traddr:0000:06:00.0'
TELEMETRY: No legacy callbacks, legacy socket not created
Initializing NVMe Controllers
Attached to NVMe Controller at 0000:06:00.0 [8086:0a54]
Associating PCIE (0000:06:00.0) NSID 1 with lcore 0
Initialization complete. Launching workers.
========================================================
                                                                           Latency(us)
Device Information                     :       IOPS      MiB/s    Average        min        max
PCIE (0000:06:00.0) NSID 1 from core  0:  652439.48    2548.59      49.03       5.12    1617.14
========================================================
Total                                  :  652439.48    2548.59      49.03       5.12    1617.14

```

- In Host:
```
# ./build/examples/perf -q 32 -s 1024 -w randwrite -t 60 -c 0x1 -o 4096 -r 'trtype:PCIe traddr:0000:49:00.0'
TELEMETRY: No legacy callbacks, legacy socket not created
Initializing NVMe Controllers
Attached to NVMe Controller at 0000:49:00.0 [8086:0a54]
Associating PCIE (0000:49:00.0) NSID 1 with lcore 0
Initialization complete. Launching workers.
========================================================
                                                                           Latency(us)
Device Information                     :       IOPS      MiB/s    Average        min        max
PCIE (0000:49:00.0) NSID 1 from core  0:  651427.92    2544.64      49.11       5.16    1798.65
========================================================
Total                                  :  651427.92    2544.64      49.11       5.16    1798.65
```

