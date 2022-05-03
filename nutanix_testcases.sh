#!/bin/bash

: '
Individual results are stored in a file in /root/nutanix_data directory in the following format: <HPWORKLOAD>_<LPWORKLOAD>_<HPCORE_RANGE>_<LPCORE_RANGE>_<QoS>_rep_<repetition number>
'

HPWORKLOAD=${1}-hp
LPWORKLOAD=${2}-lp
CSV_FILENAME=$3 # stores the results from different HPWORKLOAD, LPWORKLOAD combo

# pqos monitoring on/off
#PQOS_MONITORING=0 # 1:on; 0:off
PQOS_MONITORING=0 # 1:on; 0:off
SST_ENABLE=0 # 1:on; 0:off
# hwdrc and mba parameters
HWDRC_CAS=$4 # 1 to 255
MBA_CLOS_0=100
MBA_CLOS_3=$5

# core variables
HPVM_CORES=16
LPVM_CORES=16
HPCORE_RANGE="17-32"
LPCORE_RANGE="1-16"

lcore=$(lscpu |grep node0 | cut -f2 -d:)
phyc_hi=$(echo $lcore | cut -f2 -d-)
phyc_lo=$(echo $lcore | cut -f1 -d-)

function init_core_variables() {
  local phyc_hi=$(echo $lcore | cut -f2 -d-)
  local phyc_lo=$(echo $lcore | cut -f1 -d-)

  local node0_cpus=$(( phyc_hi-phyc_lo+1 ))

  HPVM_CORES=$(( node0_cpus / 2))
  LPVM_CORES=$(( node0_cpus / 2)) # default we split the cores equally
  
  local lpcore_hi=$(( LPVM_CORES-1))
  
  LPCORE_RANGE="0-${lpcore_hi}"
  HPCORE_RANGE="${LPVM_CORES}-${phyc_hi}"
}

function config_resctrl_mba() {
   echo "Configuring RESCTRL MBA."

   disable_resctrl
   
   vm_name_list=$(virsh list --name)

   mount -t resctrl resctrl /sys/fs/resctrl

   mkdir /sys/fs/resctrl/mclos0
   mkdir /sys/fs/resctrl/mclos1

   echo "MB:0=100" > /sys/fs/resctrl/mclos0/schemata
   echo "MB:0=$MBA_CLOS_3" > /sys/fs/resctrl/mclos1/schemata
  
   clos=0
   for vm_name in $vm_name_list
   do
       #pid_list=$(grep -o 'pid=[^ ,]\+' /var/run/libvirt/qemu/$vm_name.xml | cut  -b 6-9)# TODO: Fix it; Rohan
       pid_list=$(cat /var/run/libvirt/qemu/$vm_name.xml | grep pid | awk '{print $3}' | cut -d\' -f2)
       echo $pid_list
       for process in $pid_list
       do
           echo $process > /sys/fs/resctrl/mclos$clos/tasks
       done
       clos=$((clos+1))
   done
   
   cat /sys/fs/resctrl/mclos0/tasks   
   cat /sys/fs/resctrl/mclos1/tasks   
}

function disable_resctrl() {
  umount resctrl
}

function config_resctrl_hwdrc() {
  vm_name_list=$(virsh list --name)
  clos=("C04" "C07")
  index=0
  cd hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_resctrl.sh
  cd -

  for vm_name in $vm_name_list
  do
    #pid_list=$(grep -o 'pid=[^ ,]\+' /var/run/libvirt/qemu/$vm_name.xml | cut  -b 6-9)# TODO: fix it by making generic - Rohan
    pid_list=$(cat /var/run/libvirt/qemu/$vm_name.xml | grep pid | awk '{print $3}' | cut -d\' -f2) #doesn't work - Muktadir
    for process in $pid_list
    do
      echo $process > /sys/fs/resctrl/${clos[$index]}/tasks
    done
    index=$((index+1))
  done
}

function setup_env() {
  cpupower frequency-set -u 3100000 -d 3100000
  
  sst_reset
  
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

# enable sst
function sst_config() {
  # reset to default staete before applying the changes
  sst_reset
  
  echo "Configuring SST ... "

  # Associate cores to CLOS groups
  intel-speed-select -c $HPCORE_RANGE core-power assoc -c 0
  intel-speed-select -c $LPCORE_RANGE core-power assoc -c 3
  
  #Enable SST
  intel-speed-select -c $(lscpu |grep node0 | cut -f2 -d:) core-power enable --priority 1

  #Set the CLOS parameters. Frequency for HP is 3000 Mhz and for LP is 1000 
  intel-speed-select -c 0 core-power config --clos 0 --min 3000 # max is 3100
  intel-speed-select -c 0 core-power config --clos 3 --min 0 --max 500
}

# disable sst
function sst_reset() {
  echo "Reseting SST config ....."
  # Reset 	
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 0 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 1 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 2 &> /dev/null
  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power config -c 3 &> /dev/null

  intel-speed-select -c $(lscpu | grep node0 | cut -f2 -d:) core-power disable &> /dev/null
}

function start_frequency_monitoring() {
   hpworkload_file=$1
   lpworkload_file=$2

   turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c $HPCORE_RANGE --interval 1 --out /root/nutanix_data/${hpworkload_file}_stat.txt & 
   turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c $LPCORE_RANGE --interval 1 --out /root/nutanix_data/${lpworkload_file}_stat.txt &
}

function stop_frequency_monitoring() {
  killall -9 turbostat # stop capturing
}

function process_sst_data() {
  hpworkload_file=$1
  lpworkload_file=$2
  
  echo "Processing sst data ...."
  
  #Start processing data; <filename> <number of instances> <starting offset>
  echo "./turbostat_process.sh /root/nutanix_data/${hpworkload_file}_stat.txt $HPVM_CORES $((phyc_hi-HPVM_CORES+1)) >> /root/nutanix_data/${hpworkload_file}_avg.txt"
  ./turbostat_process.sh /root/nutanix_data/${hpworkload_file}_stat.txt $HPVM_CORES $((phyc_hi-HPVM_CORES+1)) >> /root/nutanix_data/${hpworkload_file}_avg.txt
  
  echo "./turbostat_process.sh /root/nutanix_data/${lpworkload_file}_stat.txt $LPVM_CORES $((phyc_hi-HPVM_CORES+1-LPVM_CORES)) >> /root/nutanix_data/${lpworkload_file}_avg.txt"
  ./turbostat_process.sh /root/nutanix_data/${lpworkload_file}_stat.txt $LPVM_CORES $((phyc_hi-HPVM_CORES+1-LPVM_CORES)) >> /root/nutanix_data/${lpworkload_file}_avg.txt
}

function start_pqos_monitoring() {
  hpworkload_file=$1
  if (( $PQOS_MONITORING == 1))
  then
    exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:[$LPCORE_RANGE],[$HPCORE_RANGE]" ${hpworkload_file}_mon &
    mon_pid=$!
  fi
}

function stop_pqos_monitoring() {
  if (( $PQOS_MONITORING == 1))
  then
    kill -SIGINT $mon_pid
  fi
}

function hp_solo_run() {
  echo "hp solo run"
  sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py
  
  local hpworkload_file="${HPWORKLOAD}_na_${HPCORE_RANGE}_na_na"
  ./run.sh -T vm -S setup -C $HPVM_CORES -W ${HPWORKLOAD}
  restart_vms
  
  # monitor, if enabled
  start_pqos_monitoring "$hpworkload_file"

  # run the experiment
  echo "Starting benchmark now ...."
  ./run.sh -T vm -S run -O $hpworkload_file
   
  #clean up
  stop_pqos_monitoring # stop monitor, if enabled
  destroy_vms
  sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun() {
  local mode=$1 # na, MBA, HWDRC, RESCTRL-MBA, or RESCTRL-HWDRC
  local no_affinity=$2
  
  echo "hp,lp co-run."
  sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py
  
  # init output file for hp and lp workloads 
  local hpworkload_file="${HPWORKLOAD}_${LPWORKLOAD}_${HPCORE_RANGE}_${LPCORE_RANGE}_sst-${SST_ENABLE}_${mode}"
  local lpworkload_file="${LPWORKLOAD}_${HPWORKLOAD}_${LPCORE_RANGE}_${HPCORE_RANGE}_sst-${SST_ENABLE}_${mode}"

  # set up the VMs
  sudo dhclient -r $ sudo dhclient
  if (( $mode == "RESCTRL-MBA" || $mode == "RESCTRL-HWDRC")); then # launch VM w/o cpu affinity
    ./run.sh -A -T vm -S setup -C $HPVM_CORES,$LPVM_CORES -W $HPWORKLOAD,$LPWORKLOAD
  else
    ./run.sh -T vm -S setup -C $HPVM_CORES,$LPVM_CORES -W $HPWORKLOAD,$LPWORKLOAD
  fi
  restart_vms
  
  # enable SST
  if [[ $SST_ENABLE -eq 1 ]]; then
    sst_config
  fi
  
  # configure RESCTRL-MBA or RESCTRL-HWDRC
  if (( $mode == "RESCTRL-MBA" )); then 
    config_resctrl_mba
  elif (( $mode == "RESCTRL-HWDRC" )); then
    config_resctrl_hwdrc   
  fi

  start_frequency_monitoring "$hpworkload_file" "$lpworkload_file"

  # monitor, if enabled
  start_pqos_monitoring "$hpworkload_file"
 
  # Run experiments in the VMs
  ./run.sh -T vm -S run -O $hpworkload_file,$lpworkload_file
  
  # Resete monitoring and process data 
  stop_frequency_monitoring
  process_sst_data $hpworkload_file $lpworkload_file

  # Reset and clean up
  stop_pqos_monitoring # stop monitor, if enabled
  destroy_vms
  sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun_wo_qos() {
  hp_lp_corun "na" 0
}

function hp_lp_corun_mba() {
  echo "Setting COS0 to HPVM_CORES cores $HPCORE_RANGE and COS3 to LPVM_CORES cores $LPCORE_RANGE."

  pqos -a "core:0=$HPCORE_RANGE"
  pqos -a "core:3=$LPCORE_RANGE"

  pqos -e 'mba:0=100' # COS0 100% available
  pqos -e "mba:3=$MBA_CLOS_3" # vary the availability of COS3 from 20% to 100%
  
  hp_lp_corun "MBA" 0 # no affinity turned off; i.e. use affinity
}

function hp_lp_corun_hwdrc() {
  pqos -R
	
  # enable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh $HWDRC_CAS $HPCORE_RANGE $LPCORE_RANGE
  cd -
  
  #HWDRC_CAS (1 to 255)
  hp_lp_corun "HWDRC" 0 # no affinity turned off; i.e. use affinity
  
  # disable HWDRC
  echo "Disable HWDRC .... "
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function hp_lp_corun_resctrl() {
  mode=$1
  
  if [[ $mode == "mba" ]]; then
    hp_lp_corun "RESCTRL-MBA" 1 # no affinity turned on
  elif [[ $mode == "hwdrc" ]]; then
    hp_lp_corun "RESCTRL-HWDRC" 1 # no affinity turned on
  else
    echo "$mode not supported while running resctrl."
    exit
  fi

  disable_resctrl 
}

function append_compiled_csv() {
  exp_type=$1
  
  if [[ $exp_type == "solo" ]]; then
    # Append result for solo run
    echo "Appending result for solo run ...."
    hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_na_${HPCORE_RANGE}_na"
    local hp_score=$(get_score "$hpworkload_string")
    echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, N/A, N/A, N/A, N/A, N/A" >> $CSV_FILENAME
    return 1
  fi
  
  hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_${LPWORKLOAD}_${HPCORE_RANGE}_${LPCORE_RANGE}_sst-${SST_ENABLE}"
  lpworkload_string="/root/nutanix_data/${LPWORKLOAD}_${HPWORKLOAD}_${LPCORE_RANGE}_${HPCORE_RANGE}_sst-${SST_ENABLE}"
  
  if [[ $exp_type == "corun" ]]; then
    echo "Append result for HP, LP corun without QoS"
    hp_score=$(get_score "${hpworkload_string}_na")
    lp_score=$(get_score "${lpworkload_string}_na")
    hp_freq=$(get_cpu_freq "${hpworkload_string}_na_avg.txt")
    lp_freq=$(get_cpu_freq "${lpworkload_string}_na_avg.txt")
    echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $hp_freq, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, $lp_freq, N/A, $SST_ENABLE" >> $CSV_FILENAME
  
  elif [[ $exp_type == "mba" ]]; then
    echo "Append result for HP,LP corun with MBA"
    hp_score=$(get_score "${hpworkload_string}_MBA")
    lp_score=$(get_score "${lpworkload_string}_MBA")
    echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, MBA-$MBA_CLOS_3, $SST_ENABLE" >> $CSV_FILENAME
  
  elif [[ $exp_type == "hwdrc" ]]; then
    echo "Append result for HP,LP corun with HWDRC"
    hp_freq=$(get_cpu_freq "${hpworkload_string}_HWDRC_avg.txt")
    lp_freq=$(get_cpu_freq "${lpworkload_string}_HWDRC_avg.txt")
    hp_score=$(get_score "${hpworkload_string}_HWDRC")
    lp_score=$(get_score "${lpworkload_string}_HWDRC")
    echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $hp_freq, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, $lp_freq, HWDRC-$HWDRC_CAS, $SST_ENABLE" >> $CSV_FILENAME
   elif [[ $exp_type == "resctrl-mba" ]]; then
     echo "Append result for HP,LP corun with resctrl-mba"
     hp_freq=$(get_cpu_freq "${hpworkload_string}_RESCTRL-MBA_avg.txt")
     lp_freq=$(get_cpu_freq "${lpworkload_string}_RESCTRL-MBA_avg.txt")
     hp_score=$(get_score "${hpworkload_string}_RESCTRL-MBA")
     lp_score=$(get_score "${lpworkload_string}_RESCTRL-MBA")
     echo "$HPWORKLOAD, N/A, $hp_score, $hp_freq, $LPWORKLOAD, N/A, $lp_score, $lp_freq, RESCTRL-MBA-$MBA_CLOS_3, $SST_ENABLE" >> $CSV_FILENAME
   elif [[ $exp_type == "resctrl-hwdrc" ]]; then
     echo "Append result for HP,LP corun with resctrl-hwdrc"
     hp_freq=$(get_cpu_freq "${hpworkload_string}_RESCTRL-HWDRC_avg.txt")
     lp_freq=$(get_cpu_freq "${lpworkload_string}_RESCTRL-HWDRC_avg.txt")
     hp_score=$(get_score "${hpworkload_string}_RESCTRL-HWDRC")
     lp_score=$(get_score "${lpworkload_string}_RESCTRL-HWDRC")
     echo "$HPWORKLOAD, N/A, $hp_score, $hp_freq, $LPWORKLOAD, N/A, $lp_score, $lp_freq, RESCTRL-HWDRC-$HWDRC_CAS, $SST_ENABLE" >> $CSV_FILENAME
  else
    echo "exp_mode $exp_mode not supported."
  fi
}

function get_cpu_freq() {
  avg_stat_file=$1
  
  echo "$(cat $avg_stat_file | tail -1 | awk '{print $3}')"
}

function get_score() {
  filename=$1
   
  workload=$(echo $filename | rev | cut -d"/" -f1 | rev | cut -d"_" -f1)

  case $workload in
    *"mlc"*)
      echo "$(cat ${filename}_rep_1 | tail -1 | cut -d','  -f2)"
    ;;
    *"rn50"*)
      echo "$(cat ${filename}_rep_1 | tail -1)"
    ;;
    *"fio"*)
      echo "N/A"
    ;;
    *"stressapp"*)
      echo "N/A"
    ;;
    *"redis"* | *"memcache"*)
      echo "$(cat ${filename}_rep_1 | cut -d',' -f10 | tail -1)"
    ;;
    *"ffmpeg"*)
      echo "$(cat ${filename}_rep_1 | cut -d':' -f2)"
    ;;
    *)
      echo "N/A"
    ;;
  esac
}

function main() {
  setup_env
  #init_core_variables

  #hp_solo_run
  #hp_lp_corun
  #hp_lp_corun_hwdrc
  
  SST_ENABLE=0 # 1:on; 0:off
  #hp_lp_corun_wo_qos
  #append_compiled_csv "na"
  #hp_lp_corun_mba
  #append_compiled_csv "mba" 
  #hp_lp_corun_resctrl "mba"
  #append_compiled_csv "resctrl-mba"
  hp_lp_corun_resctrl "hwdrc"
  append_compiled_csv "resctrl-hwdrc"
  #hp_lp_corun_hwdrc
  #append_compiled_csv "hwdrc"
  
  SST_ENABLE=1 # 1:on; 0:off
  #hp_lp_corun_wo_qos
  #hp_lp_corun_mba
  #append_compiled_csv "na"
  #hp_lp_corun_hwdrc
  #append_compiled_csv "hwdrc"
}

main $@
