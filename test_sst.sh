workloads="redis,unet,rnnt,mlc"
cores="12,12,16,8"

config="test_sst_config.sh"

echo "VM_CORES=$cores" > $config
echo "VM_WORKLOADS=$workloads" >> $config
echo "NO_QOS=0" >> $config
echo "HWDRC_ENABLE=0" >> $config
echo "LLC_CACHE_WAYS_ENABLE=0" >> $config
echo 'SST_ENABLE=0' >> $config
echo 'SST_COS_WL="0,0,3,3"' >> $config
echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config

workloads=$(echo ${workloads//,/-}) # replace comma by dash
cores=$(echo ${cores//,/-}) # replace comma by dash
result_dir="/root/nutanix_data/test_sst_${workloads}_${cores}"
mkdir -p $result_dir

./run_testcases.sh $result_dir $config
