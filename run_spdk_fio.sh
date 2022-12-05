result_file=$1
runtime=900

./spdk/scripts/setup.sh status | grep NVMe > nvme.txt
nvme_pci_addr=$(cat nvme.txt | awk '{print $2}')
nvme_pci_addr=${nvme_pci_addr//:/.}

export SPDK_FILE_NAME="trtype=PCIe  traddr=$nvme_pci_addr ns=1 "
echo $SPDK_FILE_NAME

spdk_fio_cmd="LD_PRELOAD=./spdk/build/fio/spdk_nvme fio/fio ./spdk_exp_dir/spdk.fio --iodepth=64 --direct=1 --ioengine=spdk --thread=1 --time_based --runtime=$runtime --ramp_time=5 --cpus_allowed=1 --group_reporting --bs=256k --rw=read > $result_file"
echo "Running $spdk_fio_cmd"

start=`date +%s`

LD_PRELOAD=./spdk/build/fio/spdk_nvme fio/fio ./spdk_exp_dir/spdk.fio --iodepth=64 --direct=1 --ioengine=spdk --thread=1 --time_based --runtime=$runtime --ramp_time=5 --cpus_allowed=1 --group_reporting --bs=256k --rw=read > $result_file

end=`date +%s`
runtime=$((end-start))
echo "runtime = $runtime" >> /root/$result_file


#LD_PRELOAD=/root/spdk/build/fio/spdk_nvme /root/fio/fio /root/spdk_exp_dir/fio_config_vm_shide > $result_file
