# Pre-requisite: 
Ensure that VT-X is enabled in the BIOS
## Enable SR-IOV:

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
