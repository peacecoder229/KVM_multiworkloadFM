#!/bin/bash

RESULT_DIR=$1
CONFIG=$2

# Initializes VM_CORES, VM_WORKLOADS, and HWDRC and MBA related parameters
source $CONFIG

: '
if [ $HOST_EXP -eq 1 ] && [ $RESCTRL -eq 1 ]; then
  ./run_resctrl_host_exp.sh
  exit
fi
'

declare -a VM_CORE_RANGE # list of core ranges
declare -a VM_WORKLOAD_LIST
VM_NAMES="" # Comma separated names of the VMs

# turbostat monitoring process id
declare -A turbostat_pids

# Initializes the VM_CORE_RANGE array, for example ["2-4", "5-6"]
function init_vm_core_range() {
  
  local total_core=$(lscpu | grep node0 | cut -f2 -d:)
  local hi_core=$(echo $total_core | cut -f2 -d-)
  local lo_core=$(echo $total_core | cut -f1 -d-)

  local temp_hi=$hi_core
  #if [[ $L2C_CACHE_WAYS_ENABLE -eq 0 ]]; then
  #  for vm_core in ${VM_CORES//,/ }; do
  #    local temp_lo=$((temp_hi - vm_core + 1))
  #    VM_CORE_RANGE+=("${temp_lo}-${temp_hi}")
  #    temp_hi=$((temp_hi - vm_core))
  #  done
  #else # for L2 Cache experiments, need
    #VM_CORE_RANGE+=("0") # for vm need to use 0 and 96
    VM_CORE_RANGE+=("0-47")
    #VM_CORE_RANGE+=("96-143")
    #VM_CORE_RANGE+=("1")
    #VM_CORE_RANGE+=("143")
  #fi
  
  for vm_core_range in "${VM_CORE_RANGE[@]}"; do
    echo "$vm_core_range"
  done
}

# Initializes a comma seperated string of VM names.
# Each VM is named in the following format: <workload name>:<core range>: mlc:1-15, mlc:16-32
function init_vm_names() {
  for vm_wl in ${VM_WORKLOADS//,/ }; do
    VM_WORKLOAD_LIST+=($vm_wl)
  done
  
  for i in "${!VM_WORKLOAD_LIST[@]}"; do
   echo "${VM_WORKLOAD_LIST[i]}:${VM_CORE_RANGE[i]}"
   VM_NAMES+="${VM_WORKLOAD_LIST[i]}:${VM_CORE_RANGE[i]}"
    
    if [[ $i != $((${#VM_WORKLOAD_LIST[@]}-1)) ]]; then
      VM_NAMES+=","
    fi
  done

  echo "VM Names: $VM_NAMES"
}

function setup_env() {
  if [[ $SST_ENABLE -eq 0 ]]; then
    echo "cpupower frequency-set -u 2300Mhz -d 2300Mhz"
    cpupower frequency-set -u 2700Mhz -d 2700Mhz > /dev/null
  fi

  sst_reset
  
  hwdrc_reset

  disable_resctrl
  pqos -R
  
  rm -rf /root/.ssh/known_hosts
  
  #if [[ $L2C_CACHE_WAYS_ENABLE -eq 1 ]]; then
  echo on > /sys/devices/system/cpu/smt/control
  #else
  #  echo off > /sys/devices/system/cpu/smt/control
  #fi
  sleep 5 
  
  pkill -f server.py
  #destroy_vms
}

function setup_llc_ways() {
  echo "Setting up LLC cache ways ...."

  declare -a LLC_COS_WAYS_LIST
  
  for llc_way in ${LLC_COS_WAYS//,/ }; do
    LLC_COS_WAYS_LIST+=($llc_way)
  done
  # Associate each COS LLC with the cacheways
  i=0
  for cos in ${LLC_COS_WL//,/ }; do
    echo "pqos -e "llc:$cos=${LLC_COS_WAYS_LIST[i]}""
    pqos -e "llc:$cos=${LLC_COS_WAYS_LIST[i]}"
    i=$((i+1))
  done

  # Associate each COS LLC with the cores where each VM is running.
  i=0
  for cos in ${LLC_COS_WL//,/ }; do
    echo "pqos -a "llc:$cos=${VM_CORE_RANGE[i]}""
    pqos -a "llc:$cos=${VM_CORE_RANGE[i]}"
    i=$((i+1))
  done

  echo "Done setting up LLC ways."
  pqos -s -V | grep L3CA
}

function setup_l2c_ways() {
  echo "Setting up L2C cache ways ...."

  declare -a L2C_COS_WAYS_LIST
  
  for l2c_way in ${L2C_COS_WAYS//,/ }; do
    L2C_COS_WAYS_LIST+=($l2c_way)
  done

  # Associate each COS L2C with the cacheways
  i=0
  for cos in ${L2C_COS_WL//,/ }; do
    echo "pqos -e "l2:$cos=${L2C_COS_WAYS_LIST[i]}""
    pqos -e "l2:$cos=${L2C_COS_WAYS_LIST[i]}"
    i=$((i+1))
  done

  # Associate each COS LLC with the cores where each VM is running.
  i=0
  for cos in ${L2C_COS_WL//,/ }; do
    echo "pqos -a "llc:$cos=${VM_CORE_RANGE[i]}""
    pqos -a "llc:$cos=${VM_CORE_RANGE[i]}"
    i=$((i+1))
  done

  echo "Done setting up LLC ways."
  pqos -s -V | grep L3CA

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
  sleep 60
}

function start_monitoring() {
  mon_file=$1
  
  core_ranges=""
  for i in "${!VM_CORE_RANGE[@]}"; do
    core_ranges+="[${VM_CORE_RANGE[i]}]"
    #echo "${VM_CORE_RANGE[i]}" 
    if [[ $i != $((${#VM_CORE_RANGE[@]}-1)) ]]; then
      core_ranges+=","
    fi
  done 
  
  # monitor local memory bandwidth on the core ranges
  #exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:$core_ranges" $RESULT_DIR/${mon_file} &
  
  # monitor local memory bandwidth and llc occupancy on the core ranges
  echo "Starting Memory Bandwidth and Cache monitoring ..."
  exec python3 pqos_mon_tool.py "pqos -r -i 20 -m all:$core_ranges" $RESULT_DIR/${mon_file} &
  
  mon_pid=$!
}

function hwdrc_reset() {
  # disable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function hp_lp_corun_host() {
  local cos_mode=na # na, MBA, HWDRC, RESCTRL-MBA, or RESCTRL-HWDRC
  if [[ $HWDRC_ENABLE -eq 1 ]]; then
    cos_mode="HWDRC"
  elif [[ $MBA_ENABLE -eq 1 ]]; then
    echo "Running colocation w/ MBA .... "
    cos_mode="MBA"
  fi
  echo "Running hp lp corun in $cos_mode mode."
  
  result_file_suffix="co_${cos_mode}_sst-${SST_ENABLE}"
  
  if [[ $LLC_CACHE_WAYS_ENABLE -eq 1 ]]; then
    llc_ways=$( echo ${LLC_COS_WAYS//,/-} )
    result_file_suffix=${result_file_suffix}_llc-${llc_ways}
  fi
  if [[ $L2C_CACHE_WAYS_ENABLE -eq 1 ]]; then
    l2c_ways=$( echo ${L2C_COS_WAYS//,/-} )
    result_file_suffix=${result_file_suffix}_l2c-${l2c_ways}
  fi

  #start_frequency_monitoring "$result_file_suffix"

  # start pqos monitor, if enabled
  if (( $MONITORING == 1)); then
    mon_file=$( echo ${VM_NAMES//,/_} )
    mon_file=${mon_file}_${result_file_suffix}_mon
    #echo ${mon_file}
    start_monitoring "${mon_file}"
  fi
 
  ./run_in_host.sh $VM_NAMES $result_file_suffix $RESULT_DIR
}

function hp_lp_corun() {
  local cos_mode=$1 # na, MBA, HWDRC, RESCTRL-MBA, or RESCTRL-HWDRC
  echo "Running hp lp corun in $cos_mode mode."
  
  result_file_suffix="co_${cos_mode}_sst-${SST_ENABLE}"
  
  if [[ $LLC_CACHE_WAYS_ENABLE -eq 1 ]]; then
    llc_ways=$( echo ${LLC_COS_WAYS//,/-} )
    result_file_suffix=${result_file_suffix}_llc-${llc_ways}
  fi
  if [[ $L2C_CACHE_WAYS_ENABLE -eq 1 ]]; then
    l2c_ways=$( echo ${L2C_COS_WAYS//,/-} )
    result_file_suffix=${result_file_suffix}_l2c-${l2c_ways}
  fi

  #start_frequency_monitoring "$result_file_suffix"

  # start pqos monitor, if enabled
  if (( $MONITORING == 1)); then
    mon_file=$( echo ${VM_NAMES//,/_} )
    mon_file=${mon_file}_${result_file_suffix}_mon
    #echo ${mon_file}
    start_monitoring "${mon_file}"
  fi
  
  # Run experiments in the VMs
  ./run.sh -T vm -S run -O $result_file_suffix -D $RESULT_DIR

  # Reset monitoring and process data 
  #stop_frequency_monitoring
  #process_sst_data "$result_file_suffix"

}

function hp_solo_run() {
  echo "hp_solo_run (only run the HP(first in the list) workload)"

  hp_wl=$(echo $VM_NAMES | cut -d"," -f1)
  hp_wl_core=$(echo $VM_CORES | cut -d"," -f1)
  
  # Launch the VMs 
  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  echo "./run.sh -A -T vm -S setup -C $hp_wl -W $hp_wl_core"
  ./run.sh -A -T vm -S setup -C $hp_wl_core -W $hp_wl
  #restart_vms
  
  # Run experiments
  hp_lp_corun "solo_na"
}

function hp_lp_corun_wo_cos() {
  echo "Running hp lp workloads in corun without CoS."
  
  # start pqos monitor, if enabled
  if (( $MONITORING == 1)); then
    mon_file=$( echo ${VM_NAMES//,/_} )
    mon_file=${mon_file}_${result_file_suffix}_mon
    #echo ${mon_file}
    start_monitoring "${mon_file}"
  fi
 
  # Launch the VMs 
  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  echo "./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG"
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG
  #restart_vms

  # Run experiments
  hp_lp_corun "na"
}

function hp_lp_corun_mba() {
  echo "Running hp lp workloads in corun mba mode."
 
  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG
  
  # Associate each COS MBA with the cores where each VM is running.
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

  hp_lp_corun "MBA"
}

function cleanup() {
  # stop pqos monitoring, if enabled
  if (( $MONITORING == 1)); then
    kill -SIGINT $mon_pid
  fi

  #destroy_vms
  rm -rf /home/vmimages2/*
  pkill -f server.py
}

function hp_lp_corun_resctrl_mba() {
  echo "Running hp lp workloads in corun resctrl-mba mode."
  
  echo "Launching VMs without cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG
  
  echo "Configuring resctrl mba ...."
  config_resctrl_mba
  
  hp_lp_corun "RESCTRL-MBA"
}

function hp_lp_corun_hwdrc() {
  echo "Running hp lp workloads in corun HWDRC mode."

  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  echo "./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG"
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES -F $VM_CONFIG
  
  # Enable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh $HWDRC_CAS_VAL
  cd -
  
  # Associate each COS LLC with the cores where each VM is running.
  i=0
  for cos in ${LLC_COS_WL//,/ }; do
    echo "pqos -a "llc:$cos=${VM_CORE_RANGE[i]}""
    pqos -a "llc:$cos=${VM_CORE_RANGE[i]}"
    i=$((i+1))
  done
 
  # Run the experiment
  hp_lp_corun "HWDRC-$HWDRC_CAS_VAL" #HWDRC_CAS (1 to 255)
  
  # disable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function hp_lp_corun_resctrl_hwdrc() {
  echo "Running hp lp workloads in corun resctrl hwdrc mode."

  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES
  
  echo "Configuring resctrl hwdrc...."
  config_resctrl_hwdrc
  
  # Run the experiment
  hp_lp_corun "RESCTRL-HWDRC"
}

function disable_resctrl() {
  umount resctrl
}

# enable sst
function setup_sst() {
  # Start vm monitoring server in the background
  # Note: Some workloads does not produce output when killed, so killing the corresponding turbostat process
  #python3 server.py &

  # reset to default state before applying the changes
  sst_reset
  
  echo "Configuring SST ... "

  # Associate cores to CLOS groups
  i=0 
  for sst_cos in ${SST_COS_WL//,/ }; do
    #Usage: intel-speed-select -c $CORE_RANGE core-power assoc -c $CLOS
    intel-speed-select -c ${VM_CORE_RANGE[i]} core-power assoc -c $sst_cos &> /dev/null
    echo "intel-speed-select -c ${VM_CORE_RANGE[i]} core-power assoc -c $sst_cos"
    i=$((i+1))
  done

  #Enable SST-CP
  echo "intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) core-power enable --priority 1" 
  intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) core-power enable --priority 1 &> /dev/null
  
  #Enable SST-TF (if turned on)
  echo "intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) turbo-freq enable --priority 1"
  intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) turbo-freq enable --priority 1 &> /dev/null
  
  #Set the CLOS parameters. Frequency for HP is 3000 Mhz and for LP is 1000
  #intel-speed-select -c 0 core-power config --clos 0 --min 3000 # max is 3100
  
  for sst_cos_freq in ${SST_COS_FREQ//,/ }; do
    sst_cos=$(echo $sst_cos_freq | cut -d: -f1)
    min_freq=$(echo $sst_cos_freq | cut -d: -f2 | cut -d- -f1)
    max_freq=$(echo $sst_cos_freq | cut -d: -f2 | cut -d- -f2)
    
    # Example: intel-speed-select -c 0 core-power config --clos 3 --min 0 --max 500
    if [[ $max_freq == 0 ]]; then
      intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq &> /dev/null
      echo "intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq"
    else
      if [[ $min_freq == 0 ]]; then
        intel-speed-select -c 0 core-power config --clos $sst_cos --max $max_freq &> /dev/null
        echo "intel-speed-select -c 0 core-power config --clos $sst_cos --max $max_freq"
      else
        intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq --max $max_freq &> /dev/null
        echo "intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq --max $max_freq"
      fi
    fi
  done
}

# disable sst
function sst_reset() {
  echo "Reseting SST config ....."
  
  wrmsr -a 0x774 0xff00
  wrmsr -a 0x620 0x0818

  # Reset 	
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 0 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 1 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 2 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 3 &> /dev/null

  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power disable &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) turbo-freq disable &> /dev/null
}

function start_frequency_monitoring() {
  result_file_suffix=$1
  
  rm -f turbostat_pids.txt

  i=0
  for vm_wl in ${VM_WORKLOADS//,/ }; do
    turbostat_filename="${vm_wl}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat.txt"
    echo "turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c ${VM_CORE_RANGE[i]} --interval 1 --out $RESULT_DIR/$turbostat_filename &"
    turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c ${VM_CORE_RANGE[i]} --interval 1 --out $RESULT_DIR/$turbostat_filename &
    ts_pid=$! 
    turbostat_pids["$turbostat_filename"]=$ts_pid
    echo "$turbostat_filename,$ts_pid" >> turbostat_pids.txt
    i=$((i+1))
  done
}

function stop_frequency_monitoring() {
  killall -9 turbostat # stop capturing
}

function process_sst_data() {
  result_file_suffix=$1

  echo "Processing sst data ...."
  #Start processing data; <filename> <number of instances> <starting offset>
  i=0
  for vm_core in ${VM_CORES//,/ }; do
    offset=$(echo ${VM_CORE_RANGE[i]} | cut -d- -f1)
    ./turbostat_process.sh $RESULT_DIR/${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat.txt $vm_core $offset > $RESULT_DIR/${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat-avg.txt
    
    echo "./turbostat_process.sh $RESULT_DIR/${VM_WORKLOADS[i]}_${vm_core_range}_${result_file_suffix}_turbostat.txt $vm_core $offset > $RESULT_DIR/${VM_WORKLOADS[i]}_${vm_core_range}_${result_file_suffix}_turbostat-avg.txt"
  
    i=$((i+1))
  done
}

function hp_lp_corun_host_resctrl() {
  : '
  # Run exp script, run_in_host.sh will store the pids in file
  ./run_in_host.sh $VM_NAMES $result_file_suffix $RESULT_DIR

  mount -t resctrl resctrl /sys/fs/resctrl
  

  # L2:<cache_id0>=<mask> 
  # setup resctrl
  if [[ $L2C_CACHE_WAYS_ENABLE -eq 1 ]]; then
    declare -a L2C_COS_WAYS_LIST
    for l2c_way in ${L2C_COS_WAYS//,/ }; do
      L2C_COS_WAYS_LIST+=($l2c_way)
    done
  
    declare -a L2C_COS_WL_LIST
    for l2c_cos in ${L2C_COS_WL//,/ }; do
      L2C_COS_WL_LIST+=($l2c_cos)
    done
    
    i=0
    for clos in ${L2C_COS_WL//,/ }; do
      mkdir /sys/fs/resctrl/clos$clos
      start_core=$(echo ${VM_CORE_RANGE[i]} | cut -d- -f1)
      end_core=$(echo ${VM_CORE_RANGE[i]} | cut -d- -f2)
      for ((core=start_core; core<=end_core; core++)); do
        cache_id=$(cat "/sys/devices/system/cpu/cpu$core/cache/index2/id")
        mask=${L2C_COS_WAYS_LIST[i]}
        echo "L2:$cache_id=$mask" > /sys/fs/resctrl/clos$clos/schemata
        clos=$((clos+1))
      done
    done
  fi
  '
}

function config_resctrl_mba() {
   echo "Configuring RESCTRL MBA."

   disable_resctrl
   
   vm_name_list=$(virsh list --name)

   mount -t resctrl resctrl /sys/fs/resctrl
   
   clos=0
   for cos_val in ${MBA_COS_VAL//,/ }; do
     mkdir /sys/fs/resctrl/mclos$clos
     echo "MB:$cos_val" > /sys/fs/resctrl/mclos$clos/schemata
     clos=$((clos+1))
   done
   
   for clos in ${MBA_COS_WL//,/ }; do
     for vm_name in $vm_name_list
     do
       #pid_list=$(grep -o 'pid=[^ ,]\+' /var/run/libvirt/qemu/$vm_name.xml | cut  -b 6-9)# TODO: Fix it; Rohan
       pid_list=$(cat /var/run/libvirt/qemu/$vm_name.xml | grep pid | awk '{print $3}' | cut -d\' -f2)
       for process in $pid_list
       do
         echo $process > /sys/fs/resctrl/mclos$clos/tasks
       done
     done
   done
}

function config_resctrl_hwdrc() {
  vm_name_list=$(virsh list --name)
  local -a clos_list
  for clos in ${HWDRC_COS_WL}; do
    if [[ $clos -ge 10 ]]; then
      clos_list+=("C$clos")
    else
      clos_list+=("C0$clos")
    fi
  done
  
  index=0
  cd hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_resctrl.sh # mounts resctrl, creates directory for CLOS C01 to C014
  cd -

  for vm_name in $vm_name_list
  do
    #pid_list=$(grep -o 'pid=[^ ,]\+' /var/run/libvirt/qemu/$vm_name.xml | cut  -b 6-9)# TODO: fix it by making generic - Rohan
    pid_list=$(cat /var/run/libvirt/qemu/$vm_name.xml | grep pid | awk '{print $3}' | cut -d\' -f2)
    for process in $pid_list
    do
      echo $process > /sys/fs/resctrl/${clos_list[$index]}/tasks
    done
    index=$((index+1))
  done
}

function append_compiled_csv() {
 echo "TODO: Need to compile result"
 local cos_list=$1 #comma seperated list
 local file_suffix=$2 #TODO 

 for cos in ${cos_list//,/ }; do
   row=""
   i=0
   for vm_wl in ${VM_WORKLOADS//,/ }; do
     # <workload>_<core_range>_<co/solo>_<cos>_<iteration>
     file_suffix=${vm_wl}_${VM_CORE_RANGE[i]}_co_${cos}_sst-${SST_ENABLE} 
     outfile="$RESULT_DIR/${file_suffix}_rep_1"
     turbostat_file="$RESULT_DIR/${file_suffix}_turbostat-avg.txt"
     echo "Getting score from $outfile and cpu freq from $turbostat_file"

     score=$(get_score "${outfile}")
     freq=$(get_cpu_freq "${turbostat_file}")
     
     local temp="$vm_wl, ${VM_CORE_RANGE[i]}, $score, $freq"
     
     if [[ $row == "" ]]; then
       row="${temp}"
     else
       row="${row}, ${temp}"
     fi

     i=$((i+1))
   done
   # Write to summary file
   echo "$row, $cos, sst-$SST_ENABLE" >> $RESULT_DIR/summary.txt
 done
}

function get_score() {
  filename=$1
   
  workload=$(echo $filename | rev | cut -d"/" -f1 | rev | cut -d"_" -f1)

  case $workload in
    *"mlc"*)
      echo "$(cat ${filename} | tail -1 | cut -d','  -f2)"
    ;;
    *"rn50"*)
      echo "$(cat ${filename} | tail -1)"
    ;;
    *"fio"*)
      echo "N/A"
    ;;
    *"stressapp"*)
      echo "N/A"
    ;;
    *"redis"* | *"memcache"*)
      echo "$(cat ${filename} | cut -d',' -f10 | tail -1)"
    ;;
    *"ffmpeg"*)
      echo "$(cat ${filename} | cut -d':' -f2)"
    ;;
    *"ffmpegbm"*)
      echo "$(cat ${filename})"
    ;;
    *)
      echo "N/A"
    ;;
  esac
}

function get_cpu_freq() {
  avg_stat_file=$1
  echo "$(cat $avg_stat_file | tail -1 | awk '{print $3}')"
}

function main() {
  setup_env
  init_vm_core_range
  init_vm_names
  
  if [[ $LLC_CACHE_WAYS_ENABLE -eq 1 ]]; then
    setup_llc_ways
  fi

  if [[ $L2C_CACHE_WAYS_ENABLE -eq 1 ]]; then
    setup_l2c_ways
  fi

  if [[ $SST_ENABLE -eq 1 ]]; then
    setup_sst
  fi

  #TODO: Add config option for hp_solo_run, hp_lp_corun_resctrl_mba, hp_lp_corun_resctrl_hwdrc
  
  if [[ $HOST_EXP -eq 1 ]]; then
    if [[ $RESCTRL -eq 1 ]]; then
        echo "Running exp in host using resctrl interface."
        hp_lp_corun_host_resctrl 
     else    
        echo "Running exp in host."
        hp_lp_corun_host
    fi
  elif [[ $HWDRC_ENABLE -eq 1 ]]; then
    echo "Running colocation w/ HWDRC .... "
    hp_lp_corun_hwdrc
  elif [[ $MBA_ENABLE -eq 1 ]]; then
    echo "Running colocation w/ MBA .... "
    hp_lp_corun_mba
  else
    echo "Running colocation w/o HWDRC or MBA .... "
    hp_lp_corun_wo_cos
  fi

  # Destroy vms, delete temp files etc.
  cleanup
}

main $@
