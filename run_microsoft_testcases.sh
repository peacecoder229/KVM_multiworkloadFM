#for cas_value in {25..225..100}; do
for workloads in "redis,mlc"; do
  cores="12,36"
  config="ms_vm_config.sh"
  
  echo "VM_CORES=$cores" > $config
  echo "VM_WORKLOADS=$workloads" >> $config
  echo "MBA_COS_WL=0" >> $config
  echo 'MBA_COS_VAL="0=100,3=20"' >> $config
  #echo "HWDRC_CAS_VAL=$cas_value" >> $config
  echo "HWDRC_CAS_VAL=16" >> $config
  echo "HWDRC_COS_WL=4,7" >> $config
  echo 'SST_COS_WL="0"' >> $config
  echo 'SST_COS_FREQ="0:3000-0,3:1000-1500"' >> $config
  
  cat $config

  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_${workloads}_${cores}"
  
  ./run_testcases.sh $result_dir $config
done
