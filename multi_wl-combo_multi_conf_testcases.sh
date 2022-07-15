#for workloads in "redis,speccpu" "memcache,speccpu" "redis,mlc" "memcache,unet" "redis,unet"; do
for workloads in "redis,mlc"; do
  cores="12,36"
  config1="1-config.sh"
  config2="2-config.sh"
  config3="3-config.sh"
  config4="4-config.sh"
  config5="5-config.sh"
  config6="6-config.sh"
  config7="7-config.sh"
  config8="8-config.sh"
  config9="9-config.sh"
  config10="10-config.sh"
  config11="11-config.sh"
  config12="12-config.sh"
  
  #  Cacheways: 15,15
  # config 1: No QoS
  echo "VM_CORES=$cores" > $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "NO_QOS=1" >> $config1
  echo 'SST_ENABLE=0' >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "HWDRC_COS_WL=4,7" >> $config1
  echo "LLC_COS_WAYS=0x7fff,0x7fff" >> $config1
  # config 2: Only SST
  echo "VM_CORES=$cores" > $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "NO_QOS=0" >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo "HWDRC_COS_WL=4,7" >> $config2
  echo 'SST_ENABLE=1' >> $config2
  echo 'SST_COS_WL="0,3"' >> $config2
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config2
  echo "LLC_COS_WAYS=0x7fff,0x7fff" >> $config2
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
  echo "LLC_COS_WAYS=0x7fff,0x7fff" >> $config3
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
  echo "LLC_COS_WAYS=0x7fff,0x7fff" >> $config4

  # Cache ways: 15,4
  # config 5: No QoS
  echo "VM_CORES=$cores" > $config5
  echo "VM_WORKLOADS=$workloads" >> $config5
  echo "NO_QOS=1" >> $config5
  echo 'SST_ENABLE=0' >> $config5
  echo "HWDRC_ENABLE=0" >> $config5
  echo "HWDRC_COS_WL=4,7" >> $config5
  echo "LLC_COS_WAYS=0x7fff,0xf" >> $config5
  # config 6: Only SST
  echo "VM_CORES=$cores" > $config6
  echo "VM_WORKLOADS=$workloads" >> $config6
  echo "NO_QOS=0" >> $config6
  echo "HWDRC_ENABLE=0" >> $config6
  echo "HWDRC_COS_WL=4,7" >> $config6
  echo 'SST_ENABLE=1' >> $config6
  echo 'SST_COS_WL="0,3"' >> $config6
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config6
  echo "LLC_COS_WAYS=0x7fff,0xf" >> $config6
  # config 7: Only HWDRC
  echo "VM_CORES=$cores" > $config7
  echo "VM_WORKLOADS=$workloads" >> $config7
  echo "NO_QOS=0" >> $config7
  echo "HWDRC_ENABLE=1" >> $config7
  echo "HWDRC_CAS_VAL=16" >> $config7
  echo "HWDRC_COS_WL=4,7" >> $config7
  echo 'SST_ENABLE=0' >> $config7
  echo 'SST_COS_WL="0,3"' >> $config7
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config7
  echo "LLC_COS_WAYS=0x7fff,0xf" >> $config7
  # config 8: SST+HWDRC
  echo "VM_CORES=$cores" > $config8
  echo "VM_WORKLOADS=$workloads" >> $config8
  echo "NO_QOS=0" >> $config8
  echo "HWDRC_ENABLE=1" >> $config8
  echo "HWDRC_CAS_VAL=16" >> $config8
  echo "HWDRC_COS_WL=4,7" >> $config8
  echo 'SST_ENABLE=1' >> $config8
  echo 'SST_COS_WL="0,3"' >> $config8
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config8
  echo "LLC_COS_WAYS=0x7fff,0xf" >> $config8
  
  # Cache ways: 11,4
  # config 9: No QoS
  echo "VM_CORES=$cores" > $config9
  echo "VM_WORKLOADS=$workloads" >> $config9
  echo "NO_QOS=1" >> $config9
  echo 'SST_ENABLE=0' >> $config9
  echo "HWDRC_ENABLE=0" >> $config9
  echo "HWDRC_COS_WL=4,7" >> $config9
  echo "LLC_COS_WAYS=0x7ff,0xf" >> $config9
  # config 10: Only SST
  echo "VM_CORES=$cores" > $config10
  echo "VM_WORKLOADS=$workloads" >> $config10
  echo "NO_QOS=0" >> $config10
  echo "HWDRC_ENABLE=0" >> $config10
  echo "HWDRC_COS_WL=4,7" >> $config10
  echo 'SST_ENABLE=1' >> $config10
  echo 'SST_COS_WL="0,3"' >> $config10
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config10
  echo "LLC_COS_WAYS=0x7ff,0xf" >> $config10
  # config 11: Only HWDRC
  echo "VM_CORES=$cores" > $config11
  echo "VM_WORKLOADS=$workloads" >> $config11
  echo "NO_QOS=0" >> $config11
  echo "HWDRC_ENABLE=1" >> $config11
  echo "HWDRC_CAS_VAL=16" >> $config11
  echo "HWDRC_COS_WL=4,7" >> $config11
  echo 'SST_ENABLE=0' >> $config11
  echo 'SST_COS_WL="0,3"' >> $config11
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config11
  echo "LLC_COS_WAYS=0x7ff,0xf" >> $config11
  # config 12: SST+HWDRC
  echo "VM_CORES=$cores" > $config12
  echo "VM_WORKLOADS=$workloads" >> $config12
  echo "NO_QOS=0" >> $config12
  echo "HWDRC_ENABLE=1" >> $config12
  echo "HWDRC_CAS_VAL=16" >> $config12
  echo "HWDRC_COS_WL=4,7" >> $config12
  echo 'SST_ENABLE=1' >> $config12
  echo 'SST_COS_WL="0,3"' >> $config12
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config12
  echo "LLC_COS_WAYS=0x7ff,0xf" >> $config12

  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_sst-tf_cache-ways_${workloads}_${cores}"
  mkdir -p $result_dir

  # Run experiments with the configs
  for i in {9..12}; do
    config="$i-config.sh"
    cat $config
    ./run_testcases.sh $result_dir $config
  done
done
