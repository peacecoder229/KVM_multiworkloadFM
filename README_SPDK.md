## Running FIO with SPDK in host
1. Clone and build FIO:
```
git clone https://github.com/axboe/fio 
cd fio/
make
```

2. Clone and install prequisites for SPDK:
```
git clone https://github.com/spdk/spdk
./scripts/pkgdep.sh # to install the dependencies
```

3. Build SPDK
```
cd spdk/
git submodule update --init
./configure --with-fio=/root/fio
make
python3 dpdk/usertools/dpdk-hugepages.py -p 2M --setup 2048M # Setup huge page
```

4. Unbind the nvme drive from the kernel:
- Need to reset first (?) `./scripts/setup.sh reset`. Bind the nvme device with the kernel nvme driver. 
- Bind the nvme drive to vfio-pci: `./scripts/setup.sh`
- The drive should not show up in `lsblk`. If it shows up it means the drive is active and binding with the vfio-pci drive was not successful.

5. To make sure nvme device got bound with the PMD, run the perf test.
```
/root/spdk/build/examples/perf -q 32 -s 1024 -w randwrite -t 60 -c 0xF -o 4096 -r 'trtype:PCIe traddr:0000:49:00.0'

```

6. Run FIO with SPDK
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
LD_PRELOAD=$SPDK_PATH/build/fio/spdk_nvme $FIO_PATH/fio fio_config
```

## Running FIO with SPDK in VM
1. Spawn a VM with 5 cores and specify `spdk_fio`  
```
./run.sh -A -T vm -S setup -C 5 -W spdk_fio
```
2. Now follow the steps from (3)-(6) in `Running FIO with SPDK in host`.
