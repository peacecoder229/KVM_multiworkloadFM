# Description

Pre-requisite: Ensure that VT-X is enabled in the BIOS
 
Steps:

(1) In vm_cloud_init.py set the number of VMs you want for each workload (Look for Tile_Map). We are using the codeblocks of 5G workload currently, so change the number there. Also change the Networking according to your need (Line#104). However if you want to use SR-IOV need to set it up.

(2) Run the following script to launch the vm: ./run.sh -T vm -S setup -C <number of cpus for each vm> -W <list of workload names in lowercase>
  For example, the following command "./run.sh -T vm -S setup -C 4,8 -W mlc,fio" will create two VM one with physical core 4 and 8 respectively, and the name of the VMs will mlc-01 and fio-02 respectively.

(3) ./run.sh -T vm -S run. For example, ./run.sh -T vm -S run. The command will 

The script assumes that you have a run_<workload name>.sh script in the current directory. You also need to install the workload specific softwares in the VM in the run_VM() function of the run.sh script.
