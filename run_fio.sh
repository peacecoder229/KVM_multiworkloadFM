result_file=$1

yum -y install fio

# TODO: Add argument for running FIO with/without SPDK.

#fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --numjobs=$[$(getconf _NPROCESSORS_ONLN)-1] --size=2g --iodepth=1 --runtime=60 --time_based --end_fsync=1 > ${result_file}_temp

# with SPDK
LD_PRELOAD=/root/spdk/build/fio/spdk_nvme /root/fio/fio --name=random-write --ioengine=spdk --rw=randwrite --bs=4k --numjobs=$[$(getconf _NPROCESSORS_ONLN)-1] --size=2g --iodepth=1 --runtime=60 --time_based --end_fsync=1 > ${result_file}_temp

grep "WRITE" ${result_file}_temp > $result_file

rm -f ${result_file}_temp
