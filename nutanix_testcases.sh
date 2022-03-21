
HPVM=4
LPVM=2

HPWORKLOAD=$1
LPWORKLOAD=$2

function setup_env() {
  cpupower frequency-set -u 2700Mhz
  pqos -R
  rm -rf /root/.ssh/known_hosts
  echo off > /sys/devices/system/cpu/smt/control
  
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
  sed -i "s/${HPWORKLOAD}_STRING=/${HPWORKLOAD}_STRING=${HPWORKLOAD}_hp/g" run.sh
  sed -i 's/"5G" :0/"5G" :1/g' vm_cloud-init.py

  ./run.sh -T vm -S setup -C $HPVM -W $HPWORKLOAD
  restart_vms 
  
  # run the experiment
  echo "Starting benchmark now ...."
  ./run.sh -T vm -S run
  
  #clean up 
  destroy_vms
  sed -i "s/${HPWORKLOAD}_STRING=${HPWORKLOAD}_hp/${HPWORKLOAD}_STRING=/g" run.sh
  sed -i 's/"5G" :1/"5G" :0/g' vm_cloud-init.py
  rm -rf /home/vmimages2/*
}

function hp_lp_corun() {
  hpworkload_string=${HPWORKLOAD}_${LPWORKLOAD}
  lpworkload_string=${LPWORKLOAD}_${HPWORKLOAD}
  if [[ $# -eq 1 ]]; then 
    mode=$1 # MBA or HWDRC
    hpworkload_string=${hpworkload_string}_$mode
    lpworkload_string=${lpworkload_string}_$mode
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

  # Run experiments in the VMs
  ./run.sh -T vm -S run
  
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
  pqos -a 'core:0=22-55'
  pqos -a 'core:3=0-21'

  pqos -e 'mba:0=100'
  pqos -e 'mba:3=10'
  
  hp_lp_corun "MBA"
}

function hp_lp_corun_hwdrc() {
  pqos -R

  cd $PWD/hwdrc_postsi/scripts
  ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh
  cd -

  hp_lp_corun "HWDRC" 
}

function main() {
  setup_env
  
  hp_solo_run
  hp_lp_corun
  hp_lp_corun_mba
  hp_lp_corun_hwdrc
}

main $@ 
