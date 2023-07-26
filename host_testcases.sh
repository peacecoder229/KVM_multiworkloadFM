
for workloads in "redis,speccpu"; do
  cores="24,24"
  config1="1-config.sh"
  
  echo "HOST_EXP=1" > $config1
  echo "VM_CORES=$cores" >> $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "MONITORING=1" >> $config1 
  echo 'SST_ENABLE=0' >> $config1
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "MBA_ENABLE=0" >> $config1
  
  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/resdir_host-exp_${workloads}_${cores}"
  mkdir -p $result_dir

  ./run_testcases.sh $result_dir $config1

done
