RESULT_DIR=$1
CONFIG=$2

# Initializes VM_CORES, VM_WORKLOADS, and HWDRC and MBA related parameters
source $CONFIG

declare -a VM_CORE_RANGE # list of core ranges
declare -a VM_WORKLOAD_LIST
VM_NAMES="" # Comma separated names of the VMs

# pqos monitoring on/off
MONITORING=1 # 1:on; 0:off TODO: Need to fix

SST_ENABLE=0 # 1:on; 0:off

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
  for vm_wl in ${VM_WORKLOADS//,/ }; do
    VM_WORKLOAD_LIST+=($vm_wl)
  done
  
  for i in "${!VM_WORKLOAD_LIST[@]}"; do
   echo "${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}"
    VM_NAMES+="${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}"
    
    if [[ $i != $((${#VM_WORKLOAD_LIST[@]}-1)) ]]; then
      VM_NAMES+=","
    fi
  done

  echo $VM_NAMES
}

function setup_env() {
  if (($SST_ENABLE == 0)); then
    cpupower frequency-set -u 2300Mhz -d 2300Mhz
    echo "cpupower frequency-set -u 2300Mhz -d 2300Mhz"
  fi

  sst_reset
  
  hwdrc_reset

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
  sleep 60
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
  exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:$core_ranges" $RESULT_DIR/${mon_file} &
  mon_pid=$!
}

function stop_monitoring() {
  if (( $MONITORING == 1)); then
    kill -SIGINT $mon_pid
  fi
}

function hwdrc_reset() {
  # disable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function hp_lp_corun() {
  local cos_mode=$1 # na, MBA, HWDRC, RESCTRL-MBA, or RESCTRL-HWDRC
  echo "Running hp lp corun in $cos_mode mode."
  
  result_file_suffix="co_${cos_mode}_sst-${SST_ENABLE}"
  
  if [[ $SST_ENABLE -eq 1 ]]; then
    sst_config
  fi
  
  start_frequency_monitoring "$result_file_suffix"

  # start pqos monitor, if enabled
  if (( $MONITORING == 1)); then
    mon_file=$( echo ${VM_NAMES//,/_} )
    mon_file=${mon_file}_${result_file_suffix}_mon
    echo ${mon_file}
    start_monitoring "${mon_file}"
  fi
  
  # Run experiments in the VMs
  ./run.sh -T vm -S run -O $result_file_suffix -D $RESULT_DIR

  # Reset monitoring and process data 
  stop_frequency_monitoring
  process_sst_data "$result_file_suffix"

  # Reset and clean up
  stop_monitoring # stop monitor, if enabled
  destroy_vms
  rm -rf /home/vmimages2/*
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
  
  # Launch the VMs 
  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES
  #restart_vms

  # Run experiments
  hp_lp_corun "na"
}

function hp_lp_corun_mba() {
  echo "Running hp lp workloads in corun mba mode."
 
  pqos -R 

  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES
  
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

function hp_lp_corun_resctrl_mba() {
  echo "Running hp lp workloads in corun resctrl-mba mode."
  
  echo "Launching VMs without cpu affinity."
  sudo dhclient -r $ sudo dhclient
  ./run.sh -T vm -S setup -C $VM_CORES -W $VM_NAMES
  
  echo "Configuring resctrl mba ...."
  config_resctrl_mba
  
  hp_lp_corun "RESCTRL-MBA"
}

function hp_lp_corun_hwdrc() {
  echo "Running hp lp workloads in corun HWDRC mode."
  pqos -R

  echo "Launching VMs with cpu affinity."
  sudo dhclient -r $ sudo dhclient
  echo "./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES"
  ./run.sh -A -T vm -S setup -C $VM_CORES -W $VM_NAMES
  #restart_vms
  
  # Enable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh $HWDRC_CAS_VAL
  cd -
  
  # Associate each COS LLC with the cores where each VM is running.
  i=0
  for cos in ${HWDRC_COS_WL//,/ }; do
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
function sst_config() {
  # reset to default state before applying the changes
  sst_reset
  
  echo "Configuring SST ... "

  # Associate cores to CLOS groups
  i=0 
  for sst_cos in ${SST_COS_WL//,/ }; do
    #Example: intel-speed-select -c $HPCORE_RANGE core-power assoc -c 0
    intel-speed-select -c ${VM_CORE_RANGE[i]} core-power assoc -c $sst_cos
    echo "intel-speed-select -c ${VM_CORE_RANGE[i]} core-power assoc -c $sst_cos"
    i=$((i+1))
  done

  #Enable SST
  intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) core-power enable --priority 1

  #Set the CLOS parameters. Frequency for HP is 3000 Mhz and for LP is 1000
  #intel-speed-select -c 0 core-power config --clos 0 --min 3000 # max is 3100
  
  for sst_cos_freq in ${SST_COS_FREQ//,/ }; do
    sst_cos=$(echo $sst_cos_freq | cut -d: -f1)
    min_freq=$(echo $sst_cos_freq | cut -d: -f2 | cut -d- -f1)
    max_freq=$(echo $sst_cos_freq | cut -d: -f2 | cut -d- -f2)
    
    # Example: intel-speed-select -c 0 core-power config --clos 3 --min 0 --max 500
    if [[ $max_freq == 0 ]]; then
      intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq
      echo "intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq"
    else
      intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq --max $max_freq
      echo "intel-speed-select -c 0 core-power config --clos $sst_cos --min $min_freq --max $max_freq"
    fi
  done
}

# disable sst
function sst_reset() {
  echo "Reseting SST config ....."
  
  #wrmsr -a 0x774 0xff00
  #wrmsr -a 0x620 0x0818

  # Reset 	
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 0 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 1 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 2 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 3 &> /dev/null

  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power disable &> /dev/null
}

function start_frequency_monitoring() {
  result_file_suffix=$1
  
  i=0
  for vm_wl in ${VM_WORKLOADS//,/ }; do
    turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c ${VM_CORE_RANGE[i]} --interval 1 --out $RESULT_DIR/${vm_wl}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat.txt &
    
    echo "turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c ${VM_CORE_RANGE[i]} --interval 1 --out $RESULT_DIR/${vm_wl}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat.txt &"
    
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
    ./turbostat_process.sh $RESULT_DIR/${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat.txt $vm_core $offset >> $RESULT_DIR/${VM_WORKLOAD_LIST[i]}_${VM_CORE_RANGE[i]}_${result_file_suffix}_turbostat-avg.txt
    
    echo "./turbostat_process.sh $RESULT_DIR/${VM_WORKLOADS[i]}_${vm_core_range}_${result_file_suffix}_turbostat.txt $vm_core $offset >> $RESULT_DIR/${VM_WORKLOADS[i]}_${vm_core_range}_${result_file_suffix}_turbostat-avg.txt"
  
    i=$((i+1))
  done
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

  #hp_solo_run
  #hp_lp_corun_mba
  #hp_lp_corun_hwdrc
  #hp_lp_corun_resctrl_mba
  #hp_lp_corun_resctrl_hwdrc
  
  # TODO: loop over core ranges and COSes, and construct file_suffix and pass it to hp_lp_corun and append_compiled_csv
   
  #hp_solo_run
  hp_lp_corun_wo_cos
  hp_lp_corun_hwdrc
  
  SST_ENABLE=0 # 1:on; 0:off
  #hp_lp_corun_wo_cos
  #hp_lp_corun_hwdrc
  #append_compiled_csv "HWDRC"
  
  #hp_lp_corun_mba
}

main $@
