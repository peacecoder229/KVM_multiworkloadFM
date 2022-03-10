# Pre-requisite: 
Ensure that VT-X is enabled in the BIOS
## Eanble SR-IOV:

## Workload script:
The script assumes that you have a `run_<workload name>.sh` script in the current directory. You also need to install the workload specific softwares in the VM in the run_VM() function of the run.sh script.
 
# How to run:
(1) In `vm_cloud_init.py` set the number of VMs you want for each workload (Look for Tile_Map). We are using the codeblocks of 5G workload currently, so change the number there. Also change the Networking according to your need (Line#104). However if you want to use SR-IOV need to set it up.

(2) Run the following script to launch the vm: ./run.sh -T vm -S setup -C <number of cpus for each vm> -W <list of workload names in lowercase>.
```
./run.sh -T vm -S setup -C 4,8 -W mlc,fio
```
The above command will create two VM one with physical core 4 and 8 respectively. The VM names are of the following format:  <workload-name>-<some id>. For example, the command above will create two VMs named mlc-01 and fio-02.

(3) ./run.sh -T vm -S run. The command will find the VMs available in this machine and run respective workload in each of the VM. For example, if there is a VM named mlc-02, then mlc will be run on the VM. 

# How to create a golden image?
  1. Get BKC image (.img) ) from repo. `wget https://emb-pub.ostc.intel.com/overlay/spr-bkc-pc/3.21-0.1/cs8-spr/internal-images/spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img.xz`
  2. Extract: `unxz  spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img.xz`
  3. Convert to qcow2 and expand to required storage: `qemu-img convert -f raw -O qcow2 spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img`
  4. `virt-install --import -n <vm_name> -r 16384 --vcpus=4,sockets=1 --os-type=linux --os-variant=centos-stream8 --accelerate --disk path=/home/vmimages/spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.qcow2,format=raw,bus=virtio,cache=writeback --network bridge=virbr0 --cpuset 0,1,2,3 --noautoconsole --cpu host passthrough,cache.mode=passthrough --nographics --boot uefi`
  5. Go inside the VM: `virsh console <vm_name>`, and do the following
  ..* `cloud-init clean`
  ..* `cloud-init clean --logs`
  ..* `cloud-init clean --seed`
  ..* `hostnamectl set-hostname <vm_name>_golden_vm`
  ..* `init 0`
  6. Come out of VM: `[ctrl + B]`
  7. `virt-sysprep -d <vm_name>`
  8. Copy qcow2 and rename as "golden ready": `cp spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.qcow2 mlc_golden.qcow2`
