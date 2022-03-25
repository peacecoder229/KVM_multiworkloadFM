#!/bin/bash

: '
Individual results are stored in a file in /root/nutanix_data directory in the following format: <HPWORKLOAD>_<LPWORKLOAD>_<HPVM>_<LPVM>_rep_<repetition number>
Summary of all the runs are stored in a file in /root/nutanix_data directory in the following format: Summary_<HPWORKLOAD>_<LPWORKLOAD>_<Timestamp in Year/Month/Data/Hour/Min/Sec format>
'

MONITORING=1 # 1:on; 0:off
HPWORKLOAD=$1
LPWORKLOAD=$2
HWDRC_CAS=20 # 1 to 255
MBA_CLOS_0=100
MBA_CLOS_3=10

HPVM=""
LPVM=""
HPCORE_RANGE=""
LPCORE_RANGE=""

cpupower frequency-set -u 2700000 -d 2700000

function init_core_variables() {
  local lcore=$(lscpu |grep node0 | cut -f2 -d:)
  local phyc_hi=$(echo $lcore | cut -f2 -d-)
  local phyc_lo=$(echo $lcore | cut -f1 -d-)

  local node0_cpus=$(( phyc_hi-phyc_lo+1 ))

  HPVM=$(( node0_cpus / 2))
  LPVM=$(( node0_cpus / 2)) # default we split the cores equally
  
  local lpcore_hi=$(( LPVM-1))
  
  LPCORE_RANGE="0-${lpcore_hi}"
  HPCORE_RANGE="${LPVM}-${phyc_hi}"
}

function setup_env() {
  cpupower frequency-set -u 2700Mhz
  
  pqos -R
  
  rm -rf /root/.ssh/known_hosts
  
  echo off > /sys/devices/system/cpu/smt/control
  sleep 15  
  
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

function hp_solo_run() {
  local hpworkload_string=${HPWORKLOAD}_na_${HPVM}_na
  sed -i "s/${HPWORKLOAD}_STRING=/${HPWORKLOAD}_STRING=${hpworkload_string}/g" run.sh
  sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py
  

  ./run.sh -T vm -S setup -C $HPVM -W $HPWORKLOAD
  restart_vms 
  
  if (( $MONITORING == 1 ))
  then
	exec ./pqos_mon_tool.py "pqos -r -i 20 -m mbl:$LPCORE_RANGE,$HPCORE_RANGE" ${hpworkload_string}_mon &
	mon_pid=$!
  fi

  # run the experiment
  echo "Starting benchmark now ...."
  ./run.sh -T vm -S run
   
  echo "Stop Monitoring now ......"
  kill -SIGINT $mon_pid

  #clean up 
  #destroy_vms
  sed -i "s/${HPWORKLOAD}_STRING=${hpworkload_string}/${HPWORKLOAD}_STRING=/g" run.sh
  sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun() {
  hpworkload_string=${HPWORKLOAD}_${LPWORKLOAD}_${HPVM}_${LPVM}
  lpworkload_string=${LPWORKLOAD}_${HPWORKLOAD}_${LPVM}_${HPVM}
  if [[ $# -eq 1 ]]; then
    mode=$1 # MBA or HWDRC
    hpworkload_string=${hpworkload_string}_$mode
    lpworkload_string=${lpworkload_string}_$mode
  else
    hpworkload_string=${hpworkload_string}_na
    lpworkload_string=${lpworkload_string}_na
  fi

  sed -i "s/${HPWORKLOAD}_STRING=/${HPWORKLOAD}_STRING=${hpworkload_string}/g" run.sh
  if [ $LPWORKLOAD != $HPWORKLOAD ]
  then
    sed -i "s/${LPWORKLOAD}_STRING=/${LPWORKLOAD}_STRING=${lpworkload_string}/g" run.sh
  fi
  sed -i 's/"5G" :0/"5G" :2/g' vm_cloud-init.py
  
  # set up the VMs
  sudo dhclient -r $ sudo dhclient
  ./run.sh -T vm -S setup -C $HPVM,$LPVM -W $HPWORKLOAD,$LPWORKLOAD
  restart_vms

  # for monitoring
  if (( $MONITORING == 1))
  then
        exec python3 pqos_mon_tool.py "pqos -r -i 20 -m mbl:$LPCORE_RANGE,$HPCORE_RANGE" ${hpworkload_string}_${lpworkload_string}_mon &
  	mon_pid=$!
   fi
 
  # Run experiments in the VMs
  ./run.sh -T vm -S run
  
  kill -SIGINT $mon_pid

  # Reset and clean up
  destroy_vms
  sed -i 's/"5G" :2/"5G" :0/g' vm_cloud-init.py
  sed -i "s/${HPWORKLOAD}_STRING=${hpworkload_string}/${HPWORKLOAD}_STRING=/g" run.sh
  if [ $LPWORKLOAD != $HPWORKLOAD ]
  then
    sed -i "s/${LPWORKLOAD}_STRING=${lpworkload_string}/${LPWORKLOAD}_STRING=/g" run.sh
  fi
  rm -rf /home/vmimages2/*
}

function hp_lp_corun_mba() {
  echo "Setting COS0 to HPVM cores $HPCORE_RANGE and COS3 to LPVM cores $LPCORE_RANGE."

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

function create_summary() {
  summary_file_name="/root/nutanix_data/Summary_${HPWORKLOAD}_${LPWORKLOAD}_$(date +%Y-%m-%d_%H-%M-%S)"
  
  hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_na_${HPVM}_na"
  echo "Solo Run ($HPWORKLOAD only) " > $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  cat ${hpworkload_string}_* >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name

  hpworkload_string="/root/nutanix_data/${HPWORKLOAD}_${LPWORKLOAD}_${HPVM}_${LPVM}"
  lpworkload_string="/root/nutanix_data/${LPWORKLOAD}_${HPWORKLOAD}_${LPVM}_${HPVM}"
  echo "HP and LP Co-Run ($HPWORKLOAD and $LPWORKLOAD) " >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  echo "${HPWORKLOAD}:" >> $summary_file_name
  cat ${hpworkload_string}_na_* >> $summary_file_name
  echo "${LPWORKLOAD}:" >> $summary_file_name
  cat ${lpworkload_string}_na_* >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  
  echo "HP and LP Co-Run ($HPWORKLOAD and $LPWORKLOAD) with static MBA." >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  echo "${HPWORKLOAD}:" >> $summary_file_name
  cat ${hpworkload_string}_MBA_* >> $summary_file_name
  echo "${LPWORKLOAD}:" >> $summary_file_name
  cat ${lpworkload_string}_MBA_* >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  
  echo "HP and LP Co-Run ($HPWORKLOAD and $LPWORKLOAD) with HWDRC." >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
  echo "${HPWORKLOAD}:" >> $summary_file_name
  cat ${hpworkload_string}_HWDRC_* >> $summary_file_name
  echo "${LPWORKLOAD}:" >> $summary_file_name
  cat ${lpworkload_string}_HWDRC_* >> $summary_file_name
  echo "-----------------------------" >> $summary_file_name
}

function main() {
  setup_env
  init_core_variables

  hp_solo_run
  hp_lp_corun
  hp_lp_corun_mba
  hp_lp_corun_hwdrc

  create_summary
}

main $@
