
# spr image, but works on emr
wget https://ubit-artifactory-or.intel.com/artifactory/linuxbkc-or-local/linux-stack-bkc-spr/2023ww16/internal-images/spr-bkc-pc-centos-stream-8-coreserver-16.4-24.img.xz

# Use the following commands for resizing the vm
img="spr-emr-golden-image.qcow2"
size=40
qemu-img resize ${img} ${size}G
cp ${img} ${img}f
virt-resize --expand /dev/vda3 ${img} ${img}f
mv ${img}f ${img}
virt-filesystems --long -h --all -a ${img}
