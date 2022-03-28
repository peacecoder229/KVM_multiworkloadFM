#!/bin/bash
TARGET=""
STAGE=""
TestCase_s=""
n_cpus_per_vm=""
workload_per_vm=""

HP_WL_FILE="" # <HP_WORKLOAD>-hp_<LP_WORKLOAD>-lp_<HPCORE_RANGE>_<LPCORE_RANGE>_<QoS Mode>
LP_WL_FILE="" # <LP_WORKLOAD>-lp_<HP_WORKLOAD>-hp_<LPCORE_RANGE>_<HPCORE_RANGE>_<QoS Mode>

# Since we don't support host experiments, we don't use it.
function get_config()
{
 if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null
 then
   # echo "AMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI."
   VTD_b=1
 else
#    echo "AMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI"
   VTD_b=0
 fi
 IOMMU_SV_b=$(cat /proc/cmdline | grep -woc "intel_iommu=on,sm_on")
 
 if [ ${VTD_b} -eq 0 ];
 then
   TestCase_s="VTdOff"
 else
   TestCase_s="VTdOn"
 fi
 if [ ${IOMMU_SV_b} -eq 0 ];
 then
   TestCase_s=$(echo "${TestCase_s}_SVoff")
 else
   TestCase_s=$(echo "${TestCase_s}_SVon")
 fi
# echo "${TestCase_s}"
}

function handle_args()
{
 echo "handle args."
 while getopts ":T:S:C:W:O:" opt
 do 
   case $opt in 
     T) TARGET="$OPTARG"
        TestCase_s=$(echo "${TestCase_s}_${TARGET}")
        ;;
     S) STAGE="$OPTARG"
        ;;
     C) n_cpus_per_vm="$OPTARG"
	;;
     W) workload_per_vm="$OPTARG"
	;;
     O) outfiles="$OPTARG"
	local total_vms=$(echo $outfiles | awk -F',' '{print NF}')
	HP_WL_FILE=$(echo $outfiles | cut -d"," -f1)
	if (( $total_vms == 2 )); then
	  LP_WL_FILE=$(echo $outfiles | cut -d"," -f2)
	fi
	echo "The results will be written to $HP_WL_FILE, $LP_WL_FILE"
	;;
     \?)
        echo "Invalid option: -$OPTARG"
        exit 1
       ;;
    esac 
 done
}

function get_ip_from_vm_name()
{
  local vm_name=$1
  local mac=$(virsh domiflist $vm_name | awk '{ print $5 }' | tail -2 | head -1)
  #echo $mac
  local ip=$(arp -a | grep $mac | awk '{ print $2 }' | sed 's/[()]//g')
  echo $ip
}

function setup_vm()
{
 echo "Creating VMs with the following configurations: number of cpus per vm = $n_cpus_per_vm, workload per vm = $workload_per_vm."
 
 python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm
 chmod 777 ./virt-install-cmds.sh
 ./virt-install-cmds.sh
 
 echo "Waiting 2 minutes for the VM to boot"
 sleep 120
}

function run_exp_vm()
{
  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
    local vm_ip=$(get_ip_from_vm_name "$vm_name")
    
    # setup yum
    scp -oStrictHostKeyChecking=no update_yum_repo.sh root@${vm_ip}:/root
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/update_yum_repo.sh" &

    case $vm_name in
      *"mlc"*)
        run_mlc_vm "$vm_name" "$vm_ip"
      ;;
      *"rn50"*)
        run_rn50_vm "$vm_name" "$vm_ip"
      ;;
      *"fio"*)
        run_fio_vm "$vm_name" "$vm_ip"
      ;;
      *"stressapp"*)
        run_stressapp_vm "$vm_name" "$vm_ip"
      ;;
      *"redis"*)
        run_redis_vm "$vm_name" "$vm_ip"
      ;;
      *"memcache"*)
        run_memcache_vm "$vm_name" "$vm_ip"
      ;;
    *)
      echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
  done
 
 # waiting for the jobs to finish before we copy results back
 for job in `jobs -p`
 do
   #echo "Waiting for $job to finish ...."
   wait $job
 done
}

function run_mlc_vm() # [TODO Rohan]: Have one function and take the name of benchmark. Just call it run VM
{
  vm_name=$1
  vm_ip=$2
  echo "Run mlc in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -oStrictHostKeyChecking=no /root/mlc root@${vm_ip}:/usr/local/bin/
  #scp -oStrictHostKeyChecking=no /root/rn50.img.xz root@${ip}:/root/
  scp -oStrictHostKeyChecking=no run_mlc.sh root@${vm_ip}:/root
  
  for iteration in 1
  do
    result_file=$HP_WL_FILE
    
    if [[ $vm_name == *"mlc-lp"* ]]; then
      result_file=$LP_WL_FILE
    fi
 
    result_file=${result_file}_rep_${iteration}
    echo "Result file is $result_file"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_mlc.sh $result_file" &
  done
}

function run_rn50_vm() # [TODO Rohan]: Have one function and take the name of benchmark. Just call it run VM
{
  vm_name=$1
  vm_ip=$2
  echo "Run rn50 in $vm_name: $vm_ip"   
  echo "Copying to ${vm_ip}"
  scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${vm_ip}:/usr/local/bin/
  scp -oStrictHostKeyChecking=no /root/rn50.img.xz root@${vm_ip}:/root/
  scp -oStrictHostKeyChecking=no run_rn50.sh root@${vm_ip}:/root
  
  for iteration in 1
  do
    result_file=$HP_WL_FILE
    
    if [[ $vm_name == *"rn50-lp"* ]]; then
      result_file=$LP_WL_FILE
    fi
 
    result_file=${result_file}_rep_${iteration}
    echo "Result file is $result_file"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_rn50.sh $result_file" &
  done 
}


function run_stressapp_vm() # [TODO Rohan]: Have one function and take the name of benchmark. Just call it run VM
{
  vm_name=$1
  vm_ip=$2
  echo "Run rn50 in $vm_name: $vm_ip"   
  echo "Copying to ${vm_ip}"
  scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${vm_ip}:/usr/local/bin/
  scp -oStrictHostKeyChecking=no /root/streeapp.tar root@${vm_ip}:/root/
  scp -oStrictHostKeyChecking=no run_stressapp.sh root@${vm_ip}:/root
  
  for iteration in 1
  do
    result_file="dummy"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_stressapp.sh $result_file" &
  done
}

function run_fio_vm()
{
  vm_name=$1
  vm_ip=$2
  echo "Run fio in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${vm_ip}:/usr/local/bin/
  scp -oStrictHostKeyChecking=no run_fio.sh root@${vm_ip}:/root

  for iteration in 1
  do
    result_file=$HP_WL_FILE
    
    if [[ $vm_name == *"fio-lp"* ]]; then
      result_file=$LP_WL_FILE
    fi
 
    result_file=${result_file}_rep_${iteration}
    echo "Result file is $result_file"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_fio.sh $result_file" &
  done 
}

function run_redis_vm()
{
  vm_name=$1
  vm_ip=$2
  echo "Run redis in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
  scp -oStrictHostKeyChecking=no run_redis.sh root@${vm_ip}:/root
  ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"

  for iteration in 1
  do
    result_file=$HP_WL_FILE
    
    if [[ $vm_name == *"redis-lp"* ]]; then
      result_file=$LP_WL_FILE
    fi
 
    result_file=${result_file}_rep_${iteration}
    echo "Result file is $result_file"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_redis.sh $result_file" &
  done
}

function run_memcache_vm()
{
  vm_name=$1
  vm_ip=$2
  echo "Run memcache in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
  scp -oStrictHostKeyChecking=no run_memcache.sh root@${vm_ip}:/root
  ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"

  for iteration in 1
  do
    result_file=$HP_WL_FILE
    
    if [[ $vm_name == *"memcache-lp"* ]]; then
      result_file=$LP_WL_FILE
    fi
 
    result_file=${result_file}_rep_${iteration}
    echo "Result file is $result_file"
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_memcache.sh $result_file" &
  done
}

function copy_result_from_vms()
{
  # Copy the result data to `nutanix_data` directory, create if does not exist.
  mkdir -p /root/nutanix_data

  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
   local vm_ip=$(get_ip_from_vm_name "$vm_name")
   
   for iteration in 1
   do
      case $vm_name in
        *"hp"*)
          scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/${HP_WL_FILE}_rep_${iteration} /root/nutanix_data/
        ;;
        *"lp"*)
          scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/${LP_WL_FILE}_rep_${iteration} /root/nutanix_data/
	;;
	*)
        echo "The VM name should contain "hp" or "lp"."
        ;;
      esac
    done
  done
}

function setup_exp()
{
 if [ "host" = "${TARGET}" ]
 then
  docker -v &>2
  docker_code=$(echo $?)
  if [ "127" = "${docker_code}" ]
  then
    echo "Please install docker using the pnpwls script"
  elif [ "0" = "${docker_code}" ]
  then
    echo "System has docker and is ready to run 5G script"
  else
    echo "Script could not figure if docker is installed, if it is ignore and execute run stage"
  fi
 elif [ "vm" = "${TARGET}" ]
 then
  setup_vm
 else
  echo "Target not valid use 'host' or 'vm' as option"
 fi
}

function run_exp()
{
 if [ "host" = "${TARGET}" ]
 then
  virsh list --name | xargs -i destroy {}
  for iteration in 1 2 3
  do
    echo "Running experiements in host is not supported yet. Exiting ..."
    exit
  done
 elif [ "vm" = "${TARGET}" ]
 then
  run_exp_vm
  copy_result_from_vms
 fi
}

function main ()
{  
  # Since we don't support host experiments, we don't use it.
  get_config
 
  handle_args $@
 
  if [ "setup" = "${STAGE}" ]
  then
    setup_exp
  elif [ "run" = "${STAGE}" ]
  then
    run_exp
  else
    echo "Stage not available"
  fi
}

main $@
