
############################# Note ##################################
# Before running make sure to do the following in run_testcases.sh:
# 1. "echo on > /sys/devices/system/cpu/smt/control" in the setup_env() in run_testcases.sh
# 2. Comment out the for loop and add the following in init_vm_core_range() function: 
# 	VM_CORE_RANGE+=("0-0")
#   VM_CORE_RANGE+=("96-96")
#####################################################################

#for workloads in "redis,mlc_w3"; do

for workloads in "speccpu:502.gcc_r:1,speccpu:511.povray_r:1"; do
#for workloads in "speccpu:502.gcc_r:1,speccpu:502.gcc_r:1"; do
#for workloads in "speccpu:502.gcc_r:1,mlc"; do
#for workloads in "redis,mlc"; do
#for workloads in "mlc,mlc"; do
  cores="1,1"
  config1="1-config.sh"
  config2="2-config.sh"
  config2="3-config.sh"
  config4="4-config.sh"
  
  # config 1: Colocation (No QoS)
  echo "HOST_EXP=1" > $config1
  echo "VM_CORES=$cores" >> $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "MONITORING=0" >> $config1 
  echo 'SST_ENABLE=0' >> $config1
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config1
  echo "L2C_CACHE_WAYS_ENABLE=0" >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "MBA_ENABLE=0" >> $config1
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config1
  
  # config 2: CAT (L2C: 13 ways to HP and 3 ways to LP)
  echo "HOST_EXP=1" > $config2
  echo "VM_CORES=$cores" >> $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "MONITORING=0" >> $config2
  echo 'SST_ENABLE=0' >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config2

  echo "MBA_ENABLE=0" >> $config2

  echo "L2C_CACHE_WAYS_ENABLE=1" >> $config2
  echo "L2C_COS_WL=4,7" >> $config2
  echo "L2C_COS_WAYS=0xfff,0xf000" >> $config2
  #echo "L2C_COS_WL=4" >> $config2
  #echo "L2C_COS_WAYS=0xff" >> $config2
   
  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/hostexp_l2c_${workloads}_${cores}"
  mkdir -p $result_dir
  
  # Run default case 
  case_name="${workloads}_${cores}_l2c-default"
  mkdir -p $result_dir/$case_name
  
  #numactl --cpunodebind=1 --localalloc tmc -c "./run_testcases.sh $result_dir $config1" -n -x mchowdh1 -u -S 5 -a "l2cat" -i "$case_name" -w thread,socket,core -D $case_name
  tmc -c "./run_testcases.sh $result_dir $config1" -n -x mchowdh1 -u -S 5 -a "l2cat" -i "$case_name" -w thread,socket,core -D $case_name
  #mv $result_dir/* $result_dir/$case_name/ # move data to case directory in result dir
  find $result_dir -maxdepth 1 -type f | xargs mv -t $result_dir/$case_name

  echo "Sleep for 10 min to make sure edp generated the excel file."
  sleep 600  
  wget --no-check-certificate https://fl31ca104ja0301.deacluster.intel.com/data/mchowdh1/GDC3200-28T090T/Global/$case_name/${case_name}_edp_r1/${case_name}_edp_r1.xlsx
  mv ${case_name}_edp_r1.xlsx $result_dir/$case_name/emon.xlsx
  mkdir -p $result_dir/$case_name/emon_plots
  python extract.py $result_dir/$case_name/emon.xlsx $result_dir/$case_name/emon_plots
   
  # cache way sweep experiments
  cache_list=("0x1,0xfffe" "0x3,0xfffc" "0xf,0xfff0" "0xff,0xff00" "0xfffe,0x1")
  for cache in "${cache_list[@]}"; do
    echo "L2C_COS_WAYS=$cache" >> $config2
    l2c_ways=$( echo ${cache//,/-} )
    case_name="${workloads}_${cores}_l2c-${l2c_ways}"
    mkdir -p $result_dir/$case_name
    
    tmc -c "./run_testcases.sh $result_dir $config2" -n -x mchowdh1 -u -S 5 -a "l2cat" -i "$case_name" -w thread,socket,core -D $case_name
  	#./run_testcases.sh $result_dir $config2
    # mv $result_dir/* $result_dir/$case_name/ # move current data from result_dir to to case directory
    find $result_dir -maxdepth 1 -type f | xargs mv -t $result_dir/$case_name
    
    echo "Sleep for 10 min to make sure edp generated the excel file."
    sleep 600
    wget --no-check-certificate https://fl31ca104ja0301.deacluster.intel.com/data/mchowdh1/GDC3200-28T090T/Global/$case_name/${case_name}_edp_r1/${case_name}_edp_r1.xlsx
    mv ${case_name}_edp_r1.xlsx $result_dir/$case_name/emon.xlsx
    mkdir -p $result_dir/$case_name/emon_plots
    python extract.py $result_dir/$case_name/emon.xlsx $result_dir/$case_name/emon_plots
  done
  
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
