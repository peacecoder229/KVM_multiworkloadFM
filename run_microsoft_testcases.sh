# The workloads should have the following names: mlc, rn50, fio, stressapp, redis, memcache, ffmpegbm, rnnt, speccpu

#cas_values=(16 115 135 155 175 195 215 235)
#cas_values=(235 215 195 175 155 135)
cas_values=(16)

#for cas_value in ${cas_values[@]}; do
for workloads in "redis,speccpu"; do
  cores="12,36"
  config="ms_vm_config.sh"
  
  echo "VM_CORES=$cores" > $config
  echo "VM_WORKLOADS=$workloads" >> $config
  echo "MBA_COS_WL=0" >> $config
  echo 'MBA_COS_VAL="0=100,3=20"' >> $config
  echo "HWDRC_CAS_VAL=$cas_value" >> $config
  echo "HWDRC_COS_WL=4,7" >> $config
  echo 'SST_COS_WL="0,3"' >> $config
  echo 'SST_COS_FREQ="0:3300-0,3:0-1800"' >> $config
  
  cat $config

  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/nutanix_data/ms_resdir_sst-tf_${workloads}_${cores}"
  mkdir -p $result_dir 

  ./run_testcases.sh $result_dir $config
done
#done
