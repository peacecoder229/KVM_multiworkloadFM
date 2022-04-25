#!/bin/bash
TARGET=""
STAGE=""
TestCase_s=""
n_cpus_per_vm=""
workload_per_vm=""
file_suffix=""
cpu_affinity=0

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
 while getopts "AT:S:C:W:O:" opt
 do 
   case $opt in 
     A) cpu_affinity=1
	;;
     T) TARGET="$OPTARG"
        TestCase_s=$(echo "${TestCase_s}_${TARGET}")
        ;;
     S) STAGE="$OPTARG"
        ;;
     C) n_cpus_per_vm="$OPTARG"
	;;
     W) workload_per_vm="$OPTARG"
	;;
     O) file_suffix="$OPTARG"
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

function setup_vm() {
  echo "Creating VMs with the following configurations: number of cpus per vm = $n_cpus_per_vm, workload per vm = $workload_per_vm."
  if (( $cpu_affinity == 0 )); then
    echo "python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm"
    python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm
  else
    echo "python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm --cpu_affinity"
    python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm --cpu_affinity
  fi
  
  chmod 777 ./virt-install-cmds.sh
  ./virt-install-cmds.sh
  echo "Waiting 3 minutes for the VM to boot"
  sleep 180
  
  virsh list --all --name|xargs -i virsh destroy {} --graceful
  virsh list --all --name|xargs -i virsh start {}
  virsh list
  sleep 60

  setup_workloads
  sleep 180 # sleep for sometime to make sure the workload setup is successful
}

function setup_workloads()
{
  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
    local vm_ip=$(get_ip_from_vm_name "$vm_name")
    
    # setup yum
    scp -oStrictHostKeyChecking=no update_yum_repo.sh root@${vm_ip}:/root
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/update_yum_repo.sh"
    
    # setup individual workloads
    case $vm_name in
      *"mlc"*)
	scp -oStrictHostKeyChecking=no /root/mlc root@${vm_ip}:/usr/local/bin/
      ;;
      *"rn50"*)
	scp -oStrictHostKeyChecking=no /root/rn50.img.xz root@${vm_ip}:/root/
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "xzcat  /root/rn50.img.xz |docker load"
      ;;
      *"fio"*)
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "scp yum -y install fio"
      ;;
      *"stressapp"*)
	scp -oStrictHostKeyChecking=no /root/streeapp.tar root@${vm_ip}:/root/
      ;;
      *"redis"*)
	scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"
      ;;
      *"memcache"*)
	scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"
      ;;
      *"ffmpeg"*)
	scp -r -oStrictHostKeyChecking=no /root/ffmpeg root@${vm_ip}:/root/
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "docker load < /root/ffmpeg/ffmpeg.tar"
      ;;
      *)
        echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
  done
}

function run_exp_vm_2()
{
  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
    local vm_ip=$(get_ip_from_vm_name "$vm_name")
    workload_script="" 
    case $vm_name in
      *"mlc"*)
	workload_script="run_mlc.sh"
      ;;
      *"rn50"*)
	workload_script="run_rn50.sh"
      ;;
      *"fio"*)
	workload_script="run_fio.sh"
      ;;
      *"stressapp"*)
	workload_script="run_stressapp.sh"
      ;;
      *"redis"*)
	workload_script="run_redis.sh"
      ;;
      *"memcache"*)
	workload_script="run_memcache.sh"
      ;;
      *"ffmpeg"*)
	workload_script="run_ffmpeg.sh"
      ;;
      *)
        echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
    
    echo "Run $workload_script in $vm_name: $vm_ip"   
  
    for iteration in 1
    do
      result_file=${vm_name}_${file_suffix}_${iteration}
      echo "Result file is $result_file"
      
      scp -oStrictHostKeyChecking=no ${workload_script} root@${vm_ip}:/root/
      ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/$workload_script $result_file" &
    done # iteration
  done # VMs
 
 # waiting for the jobs to finish before we copy results back
 for job in `jobs -p`
 do
   echo "Waiting for $job to finish ...."
   wait $job
 done
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
    result_file=${vm_name}_${file_suffix}_${iteration}
    
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
    result_file=${vm_name}_${file_suffix}_${iteration}
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
  scp -oStrictHostKeyChecking=no run_fio.sh root@${vm_ip}:/root

  for iteration in 1
  do
    result_file=${vm_name}_${file_suffix}_${iteration}
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
    result_file=${vm_name}_${file_suffix}_${iteration}
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
    result_file=${vm_name}_${file_suffix}_${iteration}
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
     result_file=${vm_name}_${file_suffix}_${iteration}
     echo "Copy result: $result_file"
     scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/${result_file} /root/nutanix_data/
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
  run_exp_vm_2
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
