# The workloads should have the following names: mlc, rn50, fio, stressapp, redis, memcache, ffmpegbm, rnnt

#cas_values=(16 115 135 155 175 195 215 235)
#cas_values=(235 215 195 175 155 135)
cas_values=(16)

for cas_value in ${cas_values[@]}; do
for workloads in "gcc,mlc"; do
  cores="36,12"
  config="ms_vm_config.sh"
  
  echo "VM_CORES=$cores" > $config
  echo "VM_WORKLOADS=$workloads" >> $config
  echo "MBA_COS_WL=0" >> $config
  echo 'MBA_COS_VAL="0=100,3=20"' >> $config
  echo "HWDRC_CAS_VAL=$cas_value" >> $config
  echo "HWDRC_COS_WL=7,7" >> $config
  echo 'SST_COS_WL="0"' >> $config
  echo 'SST_COS_FREQ="0:3000-0,3:1000-1500"' >> $config
  
  cat $config

  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_throttle-all_${workloads}_${cores}"
  mkdir -p $result_dir 

  ./run_testcases.sh $result_dir $config
done
done
