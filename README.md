# Pre-requisite: 
Ensure that VT-X is enabled in the BIOS
## Enable SR-IOV:
  1. First make sure vt-x and vt-d is enabled:
  (1) Add "intel_iommu=on" in GRUB_CMDLINE_LINUX of /etc/default/grub file;
  (2) Execute “grub2-mkconfig -o /boot/grub2/grub.cfg”. 
  (3) It did not work, because system was booting from another grub conf which is in: /boot/efi/EFI/fedora/grub.cfg. So written the iommu changes there as well: 
  grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg or /boot/efi/EFI/centos/grub.cfg
  The changes we made in /etc/defualt/grub will reflect in the new grub.cfg file.
  (4) reboot. 
  (5) After machine is booted check “dmesg | grep -i IOMMU” if iommu is enabled.
  (6) If VT-d is enabled, Linux will configure DMA Remapping at boot time. The easiest way to find this is to look in dmesg for DMAR entries. If you don't see errors, then VT-d is enabled.
  (7) Check if the network card supports sriov: (i) lshw -c network -businfo (ii) lspci -vs <bus address>
  (8 ) To see the boot option: cat /proc/cmdline
 2. echo 2 > /sys/class/net/enp1s0f0/device/sriov_numvfs

## Workload script:
The script assumes that you have a `run_<workload name>.sh` script in the current directory. You also need to install the workload specific softwares in the VM in the run_VM() function of the run.sh script.
 
## Download Workloads:
To download the workloads call get_benchmark.sh and move them to /root/


# How to run:
(1) In `vm_cloud_init.py` set the number of VMs you want for each workload (Look for Tile_Map). We are using the codeblocks of 5G workload currently, so change the number there. Also change the Networking according to your need (Line#104). However if you want to use SR-IOV need to set it up.

(2) Run the following script to launch the vm: ./run.sh -T vm -S setup -C <number of cpus for each vm> -W <list of workload names in lowercase>.
```
./run.sh -T vm -S setup -C 4,8 -W mlc-hp,fio-lp
```
The above command will create two VM one with physical core 4 and 8 respectively. The VM names are of the following format:  <workload-name>-<hp or lp>-<some id>. For example, the command above will create two VMs named mlc-hp-01 and fio-lp-02, where the former is the high priority(hp) VM and latter is the low priority (lp) VM.

(3) ./run.sh -T vm -S run -O <hp-workload-result-file>, <lp-workload-result-file>. The command will find the VMs available in this machine and run respective workload in each of the VM. For example, if there is a VM named mlc-02, then mlc will be run on the VM. 

 (4) Changed the VM names to following format:  <workload-name>-<hp or lp>-<some id>. And when running run.sh you need to pass the hp and lp result file names to run.sh. The file names will have the following format: 

HP workload file = <HP_WORKLOAD>-hp_<LP_WORKLOAD>-lp_<HPCORE_RANGE>_<LPCORE_RANGE>_<QoS Mode>
LP_workoad_file = <LP_WORKLOAD>-lp_<HP_WORKLOAD>-hp_<LPCORE_RANGE>_<HPCORE_RANGE>_<QoS Mode>

The filenames will be generated from run_nutanix_testcases.sh.

#To generate plots of  BW of cores 0-17 & 18-35 i.e.    mbl[mb/s]_0-17 and  mbl[mb/s]_18-35 following cmdline optioons could be used.
./pqos_plot.py --filelist="memcache-hp_rn50-lp_18-35_0-17_na_mon,memcache-hp_rn50-lp_18-35_0-17_MBA_mon" --variablepos='{"0" : "wl1" , "1" : "wl2" , "4" : "qos" }' --variablesep="_" --metriclist="mbl[mb/s]_0-17,mbl[mb/s]_18-35" --mettag="wkld-type-QoS:" --outputfile="memcache_rn50_corun_memBW"

 
