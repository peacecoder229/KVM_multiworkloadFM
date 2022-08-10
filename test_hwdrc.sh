workloads="redis,unet,rnnt,mlc"
cores="12,12,16,8"

config="test_hwdrc_config.sh"

echo "VM_CORES=$cores" > $config
echo "VM_WORKLOADS=$workloads" >> $config
echo "NO_QOS=0" >> $config
echo 'SST_ENABLE=0' >> $config
echo "LLC_CACHE_WAYS_ENABLE=0" >> $config
echo "HWDRC_ENABLE=1" >> $config
echo "HWDRC_CAS_VAL=16" >> $config
echo "HWDRC_COS_WL=4,4,7,7" >> $config

workloads=$(echo ${workloads//,/-}) # replace comma by dash
cores=$(echo ${cores//,/-}) # replace comma by dash
result_dir="/root/nutanix_data/test_hwdrc_${workloads}_${cores}"
mkdir -p $result_dir

./run_testcases.sh $result_dir $config
