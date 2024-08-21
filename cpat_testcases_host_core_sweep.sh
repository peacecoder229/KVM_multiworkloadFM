#!/bin/bash

lp_core=30
while [ $lp_core -le 30 ]
do
#for workloads in "redis,speccpu:502.gcc_r:1:avx512"
for workloads in "matmul,speccpu:502.gcc_r:2:avx512"
#for workloads in "speccpu:502.gcc_r:1:avx512"
do
  cores="30,$lp_core"
  #cores="30"
  config1="1-config.sh"
  config2="2-config.sh"
  
  # config 1: Colocation (No QoS)
  echo "HOST_EXP=1" > $config1
  echo "VM_CORES=$cores" >> $config1
  echo "VM_WORKLOADS=$workloads" >> $config1
  echo "MONITORING=0" >> $config1
  echo "SST_ENABLE=0" >> $config1
  echo "CPAT_ENABLE=0" >> $config1
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config1
  echo "L2C_CACHE_WAYS_ENABLE=0" >> $config1
  echo "HWDRC_ENABLE=0" >> $config1
  echo "MBA_ENABLE=0" >> $config1
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config1
  
  # config 2: with CPAT
  echo "HOST_EXP=1" > $config2
  echo "VM_CORES=$cores" >> $config2
  echo "VM_WORKLOADS=$workloads" >> $config2
  echo "MONITORING=0" >> $config2
  echo "CPAT_ENABLE=1" >> $config2
  echo "CPAT_COS=4,7" >> $config2
  echo "MBA_ENABLE=0" >> $config2
  echo 'SST_ENABLE=0' >> $config2
  echo "HWDRC_ENABLE=0" >> $config2
  echo "LLC_CACHE_WAYS_ENABLE=0" >> $config2
  echo "L2C_CACHE_WAYS_ENABLE=0" >> $config2
  echo "VM_CONFIG=\"sample_vm_config.yaml\"" >> $config2
 
  # Create result directory
  workloads=$(echo ${workloads//,/-}) # replace comma by dash
  cores=$(echo ${cores//,/-}) # replace comma by dash
  result_dir="/root/cpat_data/hostexp_cpat_${workloads}_${cores}"
  mkdir -p $result_dir

  #./run_testcases.sh $result_dir $config1 # default case
  ./run_testcases.sh $result_dir $config2 # cpat case
done
lp_core=$((lp_core+2))
done # while loop

: '
# Run for (30,15) vcpus
workloads="speccpu:523.xalancbmk_r:1:avx512,speccpu:520.omnetpp_r:1:avx512"
cores="30,15"
# Create result directory for 30-15 run
workloads=$(echo ${workloads//,/-}) # replace comma by dash
cores=$(echo ${cores//,/-}) # replace comma by dash
result_dir="/root/cpat_data/vmexp_cpat_${workloads}_${cores}"
mkdir -p $result_dir
# update config
echo "VM_CORES=$cores" >> $config1
echo "VM_CORES=$cores" >> $config2
# run the exp
./run_testcases.sh $result_dir $config1 # default case
./run_testcases.sh $result_dir $config2 # cpat case
'
