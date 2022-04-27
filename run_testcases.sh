
RESULT_DIR=$1
CONFIG=$2

# Initializes VM_CORES, VM_WORKLOADS, and HWDRC and MBA related parameters
source $CONFIG

declare -a VM_CORE_RANGE # list of core ranges
VM_NAMES="" # Comma separated names of the VMs

# pqos monitoring on/off
MONITORING=1 # 1:on; 0:off

# Initializes the VM_CORE_RANGE array, for example ["2-4", "5-6"]
function init_vm_core_range() {
  local total_core=$(lscpu | grep node0 | cut -f2 -d:)
  local hi_core=$(echo $total_core | cut -f2 -d-)
  local lo_core=$(echo $total_core | cut -f1 -d-)

  local temp_hi=$hi_core
  for vm_core in ${VM_CORES//,/ }; do
    local temp_lo=$((temp_hi - vm_core + 1))
    VM_CORE_RANGE+=("${temp_lo}-${temp_hi}")
    temp_hi=$((temp_hi - vm_core))
  done

  for vm_core_range in "${VM_CORE_RANGE[@]}"; do
    echo "$vm_core_range"
  done
}

# Initializes a comma seperated string of VM names.
# Each VM is named in the following format: <workload name>_<core range>: mlc_1-15, mlc_16-32
function init_vm_names() {
  local -a vm_workloads;
  for vm_wl in ${VM_WORKLOADS//,/ }; do
    vm_workloads+=($vm_wl)
  done
  
  for i in "${!vm_workloads[@]}"; do
    echo "${vm_workloads[i]}_${VM_CORE_RANGE[i]}"
    VM_NAMES+="${vm_workloads[i]}_${VM_CORE_RANGE[i]}"
    
    if [[ $i != $((${#vm_workloads[@]}-1)) ]]; then
      VM_NAMES+=","
    fi
  done

  echo $VM_NAMES
}

function setup_env() {
  cpupower frequency-set -u 2700Mhz
  
  pqos -R
  
  rm -rf /root/.ssh/known_hosts
  
  echo off > /sys/devices/system/cpu/smt/control
  sleep 5 
  
  destroy_vms
}

function restart_vms() {
  virsh list --all --name|xargs -i virsh destroy {} --graceful
  virsh list --all --name|xargs -i virsh start {}
  virsh list
  sleep 60
}

function destroy_vms() {
  virsh list
  virsh list --all --name|xargs -i virsh destroy {} --graceful
  virsh list --all --name|xargs -i virsh undefine {}
}

function start_monitoring() {
  mon_file=$1
  
  core_ranges=""
  for i in "${!VM_CORE_RANGE[@]}"; do
    core_ranges+="[${VM_CORE_RANGE[i]}]"
    echo "${VM_CORE_RANGE[i]}" 
    if [[ $i != $((${#VM_CORE_RANGE[@]}-1)) ]]; then
      core_ranges+=","
    fi
  done 
  echo "$core_ranges" 
  # monitor local memory bandwidth on the core ranges 
  exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:$core_ranges" ${mon_file} &
  mon_pid=$!
}

function stop_monitoring() {
  if (( $MONITORING == 1))
  then
    kill -SIGINT $mon_pid
  fi
}

function hp_solo_run() {
  echo "TODO: hp_solo_run"
}

function hp_lp_corun() {
  echo "hp lp corun: $VM_CORES, $VM_NAMES"

  ./run.sh -T vm -S setup -C $VM_CORES -W $VM_NAMES
  restart_vms

  local qos_mode="na"
  if [[ $# -eq 1 ]]; then
    qos_mode=$1 # MBA or HWDRC
  fi
  result_file_suffix="co_${qos_mode}"

  # monitor, if enabled
  if (( $MONITORING == 1)); then
    mon_file=$( echo ${VM_NAMES/,/_} )
    mon_file=${mon_file}_${result_file_suffix}_mon
    echo ${mon_file}
    start_monitoring "${mon_file}"
  fi

  ./run.sh -T vm -S run -O $result_file_suffix -D $RESULT_DIR 

  # Reset and clean up
  stop_monitoring # stop monitor, if enabled
  destroy_vms
  rm -rf /home/vmimages2/*
}

function hp_lp_corun_mba() {
  echo "Running hp lp workloads in corun mba mode."
  
  enable_cos_mba

  hp_lp_corun "mba"
}

# Associate each COS MBA with the cores where each VM is running.
function enable_cos_mba() {
  i=0
  for cos in ${MBA_COS_WL//,/ }; do
    echo "pqos -a "core:$cos=${VM_CORE_RANGE[i]}""
    pqos -a "core:$cos=${VM_CORE_RANGE[i]}"
    i=$((i+1))
  done
  
  # Set various COS to various memory bandwidth availability 
  for cos_val in ${MBA_COS_VAL//,/ }; do
    echo "pqos -e 'mba:$cos_val'"
    pqos -e "mba:$cos_val"
  done
}

# Associate each COS LLC with the cores where each VM is running.
function enable_cos_llc() {
  i=0
  for cos in ${HWDRC_COS_WL//,/ }; do
    echo "pqos -a "llc:$cos=${VM_CORE_RANGE[i]}""
    pqos -a "llc:$cos_val=${VM_CORE_RANGE[i]}"
    i=$((i+1))
  done
}

function hp_lp_corun_hwdrc() {
  echo "Running hp lp workloads in corun HWDRC mode."
  pqos -R

  # enable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh $HWDRC_CAS_VAL
  cd -
  
  # Associate each COS with the cores where each VM is running. Comment out for now. 
  enable_cos_llc

  hp_lp_corun "HWDRC" #HWDRC_CAS (1 to 255)
  
  # disable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function append_compiled_csv() {
 echo "TODO: Need to compile result"
 # <workload>_<core_range>_<co/solo>_<qos>_<iteration>
 i=0
 for qos in "na" "mba" "hwdrc"; do 
   for vm_wl in ${VM_WORKLOADS//,/ }; do
     echo "${vm_wl}_${VM_CORE_RANGE[i]}_co_${qos}"
   done
 done
}

function main() {
  setup_env
  init_vm_core_range
  init_vm_names

  #hp_solo_run #TODO
  hp_lp_corun
  #hp_lp_corun_mba
  #hp_lp_corun_hwdrc
  
  #append_compiled_csv
}

main $@
