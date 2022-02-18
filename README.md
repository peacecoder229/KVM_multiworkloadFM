# Description
 
Set up vm: 
(1) In vm_cloud_init.py set the number of VMs you want for each workload (Look for Tile_Map(Line#179)). We are using the image of 5G workload currently, so change the number there. Also change the Networking according to your need (Line#104) 
(2) The run the following script to launch the vm: ./run.sh -T vm -S setup -C <number of cpus for each vm>
(3) ./run.sh -T vm -S run

