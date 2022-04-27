summary_file_name="/root/nutanix_data/Summary_$(date +%Y-%m-%d_%H-%M-%S)"

for workloads in "mlc,redis"; do
  cores="5,3"
  config="ms_vm_config.sh"

  echo "VM_CORES=$cores" >> $config
  echo "VM_WORKLOADS=$workloads" >> $config
  echo 'MBA_COS_WL="0,3"' >> $config
  echo 'MBA_COS_VAL="0=100,3=20"' >> $config
  echo 'HWDRC_CAS_VAL=16' >> $config
  echo 'LLC_COS_WL="4,7"' >> $config

  workloads=$(echo ${workloads/,/-}) # replace comma by dash
  cores=$(echo ${cores/,/-})
  result_dir="/root/nutanix_data/ms_resdir_${workloads}_${cores}"
  
  ./run_testcases.sh $result_dir $config
  # cat $summary_dir/summary >> summary_file_name="/root/nutanix_data/Summary_$(date +%Y-%m-%d_%H-%M-%S)"
done
