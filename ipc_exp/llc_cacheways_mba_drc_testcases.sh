#for workloads in "spdk_fio,redis,speccpu,mlc"; do
for workloads in "mlc"; do
  #cores="6,12,16,12"
  cores="12"
  config1="1-config.sh"
  config2="2-config.sh"
  config3="3-config.sh"
  config4="4-config.sh"
  
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
  
  # config 2: MBA (10% for mlc)
  echo "HOST_EXP=0" > $config2
  echo "VM_CORES=$cores" > $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "MONITORING=1" >> $config2 
  echo 'SST_ENABLE=0' >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo "MBA_ENABLE=1" >> $config2
  echo "MBA_COS_WL=0,3" >> $config2
  echo "MBA_COS_VAL=\"0=100,3=10\"" >> $config2
  echo "VM_CONFIG=\"ipc_exp/redis_fio_gcc_mlc_vm_config.yaml\"" >> $config2

  # config 3: MBA (10% for mlc) + CAT (13 ways to redis and 2 ways to MLC)
  echo "VM_CORES=$cores" > $config3
  echo "VM_WORKLOADS=$workloads" >> $config3
  echo "MONITORING=1" >> $config3
  echo 'SST_ENABLE=0' >> $config3
  echo "HWDRC_ENABLE=0" >> $config3

  echo "MBA_ENABLE=0" >> $config3
  echo "MBA_COS_WL=0,3" >> $config3
  echo "MBA_COS_VAL=\"0=100,3=10\"" >> $config3

  echo "LLC_CACHE_WAYS_ENABLE=1" >> $config3
  echo "LLC_COS_WL=4,7" >> $config3
  echo "LLC_COS_WAYS=0x7ffc,0x3" >> $config3
 
  # config 4: HWDRC(90) + CAT (13 ways to redis and 2 ways to MLC) 
  echo "VM_CORES=$cores" > $config4
  echo "VM_WORKLOADS=$workloads" >> $config4
  echo "MONITORING=1" >> $config4
  echo 'SST_ENABLE=0' >> $config4
  
  echo "HWDRC_ENABLE=1" >> $config4
  echo "HWDRC_CAS_VAL=90" >> $config4
  echo "HWDRC_COS_WL=4,7" >> $config4
  
  echo "LLC_CACHE_WAYS_ENABLE=1" >> $config4
  echo "LLC_COS_WL=4,7" >> $config4
  echo "LLC_COS_WAYS=0x7ffc,0x3" >> $config4
 
  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_llc_mba_${workloads}_${cores}"
  mkdir -p $result_dir
  ./run_testcases.sh $result_dir $config1
  # Run experiments with the configs
  #for i in {1..4}; do
  #  config="$i-config.sh"
  #  cat $config
  #  ./run_testcases.sh $result_dir $config
  #done
done
