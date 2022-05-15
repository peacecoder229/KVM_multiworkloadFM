for workloads in "mlc,mlc,mlc,mlc"; do
  cores="10,10,10,10"
  config="ms_vm_config.sh"
  
  echo "VM_CORES=$cores" > $config
  echo "VM_WORKLOADS=$workloads" >> $config
  echo "MBA_COS_WL=0,3,3,3" >> $config
  echo 'MBA_COS_VAL="0=100,3=20"' >> $config
  echo "HWDRC_CAS_VAL=16" >> $config
  echo "HWDRC_COS_WL=4,7,7,7" >> $config
  echo 'SST_COS_WL="0,3,3,3"' >> $config
  echo 'SST_COS_FREQ="0:3000-0,3:1000-1500"' >> $config

  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_${workloads}_${cores}"
  
  ./run_testcases.sh $result_dir $config
done
