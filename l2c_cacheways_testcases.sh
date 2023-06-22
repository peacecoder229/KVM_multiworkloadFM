
############################# Note ##################################
# Before running make sure to do the following in run_testcases.sh:
# 1. "echo on > /sys/devices/system/cpu/smt/control" in the setup_env() in run_testcases.sh
# 2. Comment out the for loop and add the following in init_vm_core_range() function: 
# 	VM_CORE_RANGE+=("0-0")
#    	VM_CORE_RANGE+=("96-96")
#####################################################################


#for workloads in "redis,mlc_w3"; do

for workloads in "redis"; do
#for workloads in "mlc_w6"; do
  cores="1"
  config1="1-config.sh"
  config2="2-config.sh"
  config2="3-config.sh"
  config4="4-config.sh"
  
  # config 1: Colocation (No QoS)
  echo "VM_CORES=$cores" > $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "MONITORING=1" >> $config1 
  echo 'SST_ENABLE=0' >> $config1
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "MBA_ENABLE=0" >> $config1
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config1
  
  # config 2: CAT (L2C: 13 ways to HP and 3 ways to LP)
  echo "VM_CORES=$cores" > $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "MONITORING=1" >> $config2
  echo 'SST_ENABLE=0' >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config2

  echo "MBA_ENABLE=0" >> $config2

  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config2
  
  echo "L2C_CACHE_WAYS_ENABLE=1" >> $config2
  #echo "L2C_COS_WL=4,7" >> $config2
  #echo "L2C_COS_WAYS=0xfff8,0x7" >> $config2
  echo "L2C_COS_WL=4" >> $config2
  echo "L2C_COS_WAYS=0x7" >> $config2
   
  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/resdir_l2c_${workloads}_${cores}"
  mkdir -p $result_dir

  ./run_testcases.sh $result_dir $config1
  #./run_testcases.sh $result_dir $config2
  #echo "L2C_COS_WAYS=0xfff8" >> $config2
  #./run_testcases.sh $result_dir $config2
  
  # Run experiments with the configs
  #for i in {1..4}; do
  #  config="$i-config.sh"
  #  cat $config
  #  ./run_testcases.sh $result_dir $config
  #done
done
