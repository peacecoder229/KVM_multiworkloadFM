for workloads in "redis"; do
  #cores="6,12,16,12"
  cores="24"
  config1="1-config.sh"
  
  # config 1: Colocation (No QoS)
  echo "HOST_EXP=0" > $config1
  echo "VM_CORES=$cores" >> $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "MONITORING=1" >> $config1 
  echo 'SST_ENABLE=0' >> $config1
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "MBA_ENABLE=0" >> $config1
  echo "VM_CONFIG=\"ipc_exp/redis_fio_gcc_mlc_vm_config.yaml\"" >> $config1
  
  ./run_testcases.sh $result_dir $config1
  
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_llc_cacheway-sweep_${workloads}_${cores}"
  mkdir -p $result_dir
  
  echo "LLC_CACHE_WAYS_ENABLE=1" >> $config1
  echo "LLC_COS_WL=4" >> $config1
  for mask in "0x3" "0xf" "0x3f" "0xff" "0x3ff" "0xfff" "0x7fff"; do
    echo "LLC_COS_WAYS=$mask" >> $config1
    ./run_testcases.sh $result_dir $config1
  done
done
