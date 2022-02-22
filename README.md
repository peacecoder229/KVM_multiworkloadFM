# Description
 
Set up vm: 

(1) In vm_cloud_init.py set the number of VMs you want for each workload (Look for Tile_Map(Line#179)). We are using the image of 5G workload currently, so change the number there. Also change the Networking according to your need (Line#104). However if you want to use SR-IOV need to set it up.

(2) Run the following script to launch the vm: ./run.sh -T vm -S setup -C <number of cpus for each vm> -W <workload name>
  For example, the following command "./run.sh -T vm -S setup -C 4,8 -W mlc" will create two VM one with physical core 4 and 8 respectively.

(3) ./run.sh -T vm -S run -W <workload name>. For example, ./run.sh -T vm -S run -W mlc. The script assumes that you have a run_<workload name>.sh script in the current directory. You also need to install the workload specific softwares in the VM in the run_VM() function of the run.sh script.

