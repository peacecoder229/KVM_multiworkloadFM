# Pre-requisite:
1. Install pqos tool: ``` yum install intel-cmt-cat ```
2. If you want to run HWDRC, set it up first: ``` Link to HWDRC readme.```
3. Get the VM image. Username and password should be your same as your windows'.
```
 ./get_vm_image.sh <username> <password> <path where you want to store the image>
```
4. Open vm_cloud-init.py and change the ```path_prefix``` variable to where you saved  your VM image in step (3).

## Workload script:
The script assumes that you have a `run_<workload name>.sh` script in the current directory. You also need to install the workload specific softwares in the VM in the run_VM() function of the run.sh script.
 
# How to run:
(1) In `vm_cloud_init.py` set the number of VMs you want for each workload (Look for Tile_Map). We are using the codeblocks of **5G** workload currently, so change the number there. Also change the Networking according to your need (Line#104). However if you want to use SR-IOV need to set it up.

(2) Run the following script to launch the vm: 
./run.sh -T vm -S setup -C <number of cpus for each vm> -W <list of workload names>.
For example to run two VMs, one with mlc, and another with fio, run the following command:
```
./run.sh -T vm -S setup -C 4,8 -W mlc,fio
```
The above command will create two VMs named mlc-01 and fio-01 with physical core 4 and 8 respectively.
Following workloads are currently supportted: 
```
mlc, rn50, stressapp, redis, memcache, ffmpegbm, rnnt, speccpu, unet, spdk_fio, nginx
```

**Note: While launching a VM to run a particular workload, need to strictly use the above names.**

(3) Use the following command to run experiments in the VM:
```
./run.sh -T vm -S run -O $result_file_suffix -D $RESULT_DIR 
 ```
The above command will run the `run_$workload.sh` script in the available VMs and copy back the result in the `$RESULT_DIR` directory. Each result file name will have the following formart `${workload}_${start_core}-${end_core}_${result_file_suffix}_rep_${iteration}`.

#To generate plots of  BW of cores 0-17 & 18-35 i.e.    mbl[mb/s]_0-17 and  mbl[mb/s]_18-35 following cmdline optioons could be used.
./pqos_plot.py --filelist="memcache-hp_rn50-lp_18-35_0-17_na_mon,memcache-hp_rn50-lp_18-35_0-17_MBA_mon" --variablepos='{"0" : "wl1" , "1" : "wl2" , "4" : "qos" }' --variablesep="_" --metriclist="mbl[mb/s]_0-17,mbl[mb/s]_18-35" --mettag="wkld-type-QoS:" --outputfile="memcache_rn50_corun_memBW"
