#!/bin/bash

: '
Individual results are stored in a file in /root/nutanix_data directory in the following format: <HPWORKLOAD>_<LPWORKLOAD>_<HPVM_CORES>_<LPVM_CORES>_rep_<repetition number>
Summary of all the runs are stored in a file in /root/nutanix_data directory in the following format: Summary_<HPWORKLOAD>_<LPWORKLOAD>_<Timestamp in Year/Month/Data/Hour/Min/Sec format>
'

HPWORKLOAD=${1}-hp
LPWORKLOAD=${2}-lp
CSV_FILENAME=$3 # stores the results from different HPWORKLOAD, LPWORKLOAD combo

# pqos monitoring on/off
MONITORING=0 # 1:on; 0:off

# hwdrc and mba parameters
HWDRC_CAS=20 # 1 to 255
MBA_CLOS_0=100
MBA_CLOS_3=10

# core variables
HPVM_CORES=""
LPVM_CORES=""
HPCORE_RANGE=""
LPCORE_RANGE=""

cpupower frequency-set -u 2700000 -d 2700000

function init_core_variables() {
  local lcore=$(lscpu |grep node0 | cut -f2 -d:)
  local phyc_hi=$(echo $lcore | cut -f2 -d-)
  local phyc_lo=$(echo $lcore | cut -f1 -d-)

  local node0_cpus=$(( phyc_hi-phyc_lo+1 ))

  HPVM_CORES=$(( node0_cpus / 2))
  LPVM_CORES=$(( node0_cpus / 2)) # default we split the cores equally
  
  local lpcore_hi=$(( LPVM_CORES-1))
  
  LPCORE_RANGE="0-${lpcore_hi}"
  HPCORE_RANGE="${LPVM_CORES}-${phyc_hi}"
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
  hpworkload_file=$1
  if (( $MONITORING == 1))
  then
    exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:[$LPCORE_RANGE],[$HPCORE_RANGE]" ${hpworkload_file}_mon &
    mon_pid=$!
  fi
}

function stop_monitoring() {
  if (( $MONITORING == 1))
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
  start_monitoring "$hpworkload_file"

  # run the experiment
  echo "Starting benchmark now ...."
  ./run.sh -T vm -S run -O $hpworkload_file
   
  #clean up
  stop_monitoring # stop monitor, if enabled
  destroy_vms
  sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun() {
  echo "hp,lp corun."
  sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py
  
  # init output file for hp and lp workloads 
  local hpworkload_file="${HPWORKLOAD}_${LPWORKLOAD}_${HPCORE_RANGE}_${LPCORE_RANGE}"
  local lpworkload_file="${LPWORKLOAD}_${HPWORKLOAD}_${LPCORE_RANGE}_${HPCORE_RANGE}"
  local mode="na"
  if [[ $# -eq 1 ]]; then
    mode=$1 # MBA or HWDRC
  fi
  hpworkload_file=${hpworkload_file}_${mode}
  lpworkload_file=${lpworkload_file}_${mode}

  # set up the VMs
  sudo dhclient -r $ sudo dhclient
  ./run.sh -T vm -S setup -C $HPVM_CORES,$LPVM_CORES -W $HPWORKLOAD,$LPWORKLOAD
  restart_vms

  # monitor, if enabled
  start_monitoring "$hpworkload_file"
 
  # Run experiments in the VMs
  ./run.sh -T vm -S run -O $hpworkload_file,$lpworkload_file

  # Reset and clean up
  stop_monitoring # stop monitor, if enabled
  destroy_vms
  sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun_mba() {
  echo "Setting COS0 to HPVM_CORES cores $HPCORE_RANGE and COS3 to LPVM_CORES cores $LPCORE_RANGE."

  pqos -a "core:0=$HPCORE_RANGE"
  pqos -a "core:3=$LPCORE_RANGE"

  pqos -e 'mba:0=100'
  pqos -e 'mba:3=10'
  
  hp_lp_corun "MBA"
}

function hp_lp_corun_hwdrc() {
  pqos -R
	
  # enable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh
  cd -

  hp_lp_corun "HWDRC" #HWDRC_CAS (1 to 255)
  
  # disable HWDRC
  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_disable.sh
  cd -
}

function append_compiled_csv() {
  # Append result for solo run
  hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_na_${HPCORE_RANGE}_na"
  local hp_score=$(get_score "$hpworkload_string")
  echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, N/A, N/A, N/A, N/A" >> $CSV_FILENAME
  
  hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_${LPWORKLOAD}_${HPCORE_RANGE}_${LPCORE_RANGE}"
  lpworkload_string="/root/nutanix_data/${LPWORKLOAD}_${HPWORKLOAD}_${LPCORE_RANGE}_${HPCORE_RANGE}"
  
  # Append result for HP,LP corun without QoS
  hp_score=$(get_score "${hpworkload_string}_na")
  lp_score=$(get_score "${lpworkload_string}_na")
  echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, N/A" >> $CSV_FILENAME
  
  # Append result for HP,LP corun with MBA
  hp_score=$(get_score "${hpworkload_string}_MBA")
  lp_score=$(get_score "${lpworkload_string}_MBA")
  echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, MBA" >> $CSV_FILENAME

  # Append result for HP,LP corun with HWDRC
  hp_score=$(get_score "${hpworkload_string}_HWDRC")
  lp_score=$(get_score "${lpworkload_string}_HWDRC")
  echo "$HPWORKLOAD, $HPCORE_RANGE, $hp_score, $LPWORKLOAD, $LPCORE_RANGE, $lp_score, HWDRC" >> $CSV_FILENAME
}

function get_score() {
  filename=$1
   
  workload=$(echo $filename | rev | cut -d"/" -f1 | rev | cut -d"_" -f1)
  #echo "Getting score for $workload."

  case $workload in
    *"mlc"*)
      echo "$(cat ${filename}_* | tail -1 | cut -d','  -f2)"
    ;;
    *"rn50"*)
      echo "$(cat ${filename}_* | tail -1)"
    ;;
    *"fio"*)
      echo "N/A"
    ;;
    *"stressapp"*)
      echo "N/A"
    ;;
    *"redis"* | *"memcache"*)
      echo "$(cat ${filename}_* | cut -d',' -f10 | tail -1)"
    ;;
    *)
      echo "N/A"
    ;;
  esac
}

function main() {
  setup_env
  init_core_variables

  hp_solo_run
  hp_lp_corun
  hp_lp_corun_mba
  hp_lp_corun_hwdrc

  append_compiled_csv
}

main $@
