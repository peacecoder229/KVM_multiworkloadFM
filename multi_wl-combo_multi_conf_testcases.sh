for workloads in "redis,speccpu" "memcache,speccpu" "redis,mlc" "memcache,unet" "redis,unet"; do
  cores="12,36"
  config1="1-config.sh"
  config2="2-config.sh"
  config3="3-config.sh"
  config4="4-config.sh"

  # config 1: No QoS
  echo "VM_CORES=$cores" > $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "NO_QOS=1" >> $config1
  echo 'SST_ENABLE=0' >> $config1
  echo "HWDRC_ENABLE=0" >> $config1

  # config 2: Only SST
  echo "VM_CORES=$cores" > $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "NO_QOS=0" >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo 'SST_ENABLE=1' >> $config2
  echo 'SST_COS_WL="0,3"' >> $config2
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config2

  # config 3: Only HWDRC
  echo "VM_CORES=$cores" > $config3
  echo "VM_WORKLOADS=$workloads" >> $config3
  echo "NO_QOS=0" >> $config3
  echo "HWDRC_ENABLE=1" >> $config3
  echo "HWDRC_CAS_VAL=16" >> $config3
  echo "HWDRC_COS_WL=4,7" >> $config3
  echo 'SST_ENABLE=0' >> $config3
  echo 'SST_COS_WL="0,3"' >> $config3
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config3

  # config 4: SST+HWDRC
  echo "VM_CORES=$cores" > $config4
  echo "VM_WORKLOADS=$workloads" >> $config4
  echo "NO_QOS=0" >> $config4
  echo "HWDRC_ENABLE=1" >> $config4
  echo "HWDRC_CAS_VAL=16" >> $config4
  echo "HWDRC_COS_WL=4,7" >> $config4
  echo 'SST_ENABLE=1' >> $config4
  echo 'SST_COS_WL="0,3"' >> $config4
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config4

  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_sst-tf_${workloads}_${cores}"
  mkdir -p $result_dir

  # Run experiments with the configs
  for config in $config1 $config2 $config3 $config4; do
    ./run_testcases.sh $result_dir $config
    cat $config
  done
done
