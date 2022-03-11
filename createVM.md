# How to create a golden image?
  1. Get BKC image (.img) ) from repo. `wget https://emb-pub.ostc.intel.com/overlay/spr-bkc-pc/3.21-0.1/cs8-spr/internal-images/spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img.xz`
  2. Extract: `unxz  spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img.xz`
  3. Convert to qcow2 and expand to required storage: `qemu-img convert -f raw -O qcow2 spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.img`
  4. `virt-install --import -n <vm_name> -r 16384 --vcpus=4,sockets=1 --os-type=linux --os-variant=centos-stream8 --accelerate --disk path=/home/vmimages/spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.qcow2,format=raw,bus=virtio,cache=writeback --network bridge=virbr0 --cpuset 0,1,2,3 --noautoconsole --cpu host passthrough,cache.mode=passthrough --nographics --boot uefi`
  5. Go inside the VM: `virsh console <vm_name>`, and do the following
   - `cloud-init clean`
   - `cloud-init clean --logs`
   - `cloud-init clean --seed`
   - `hostnamectl set-hostname <vm_name>_golden_vm`
   - `init 0`
  6. Come out of VM: `[ctrl + B]`
  7. `virt-sysprep -d <vm_name>`
  8. Copy qcow2 and rename as "golden ready": `cp spr-bkc-pc-centos-stream-8-coreserver-3.21-0.1.qcow2 mlc_golden.qcow2`
