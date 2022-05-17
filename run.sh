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
 while getopts "AT:S:C:W:O:D:" opt
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
     D) res_dir="$OPTARG"
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
      *"ffmpegdocker"*)
	scp -r -oStrictHostKeyChecking=no /root/ffmpeg root@${vm_ip}:/root/
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "docker load < /root/ffmpeg/ffmpeg.tar"
      ;;
       *"ffmpegbm"*)
         ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf install -y https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm" 
         ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf install -y https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm"
         ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum-config-manager --enable powertools"
         ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf -y install ffmpeg"
	 scp -r -oStrictHostKeyChecking=no /home/uhd1.webm root@${vm_ip}:/root/
      ;;
     
      *"rnnt"*)
	# Increase the volume of VM disk
	virsh shutdown $vm_name; sleep 10
	qcow_file=$(virsh domblklist $vm_name | grep vda | awk '{print $2}')
	echo "qemu-img resize $qcow_file +150G"
	qemu-img resize $qcow_file +150G
 	virsh start $vm_name; sleep 60
	
	# copy rnnt
	scp -r -oStrictHostKeyChecking=no /home/rnnt root@${vm_ip}:/root/ &
        
	# create docker
	docker pull dcsorepo.jf.intel.com/dlboost/pytorch:2022_ww16
	docker run -itd --privileged --net host --shm-size 4g --name pytorch_spr_2022_ww16 -v /home/dataset/pytorch:/home/dataset/pytorch -v /home/dl_boost/log/pytorch:/home/dl_boost/log/pytorch dcsorepo.jf.intel.com/dlboost/pytorch:2022_ww16 bash
      ;;
      *)
        echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
  done
}

function run_exp_vm()
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
      *"ffmpegbm"*)
	workload_script="run_ffmpeg_baremetal.sh"
      ;;
      *"rnnt"*)
	workload_script="run_rnnt.sh"
      ;;
      *)
        echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
    
    echo "Run $workload_script in $vm_name: $vm_ip"   
  
    for iteration in 1
    do
      wl_name=$(echo $vm_name | cut -d"_" -f1 )
      start_core=$(echo $vm_name | cut -d"_" -f2 | cut -d"-" -f1)
      end_core=$(echo $vm_name | cut -d"_" -f2 | cut -d"-" -f2)
      result_file=${wl_name}_${start_core}-${end_core}_${file_suffix}_rep_${iteration}
      echo "Result file is $result_file"
      
      scp -oStrictHostKeyChecking=no ${workload_script} root@${vm_ip}:/root/
      ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/$workload_script $result_file" &
    done # iteration
  done # VMs
 
 # waiting for the jobs to finish before we copy results back
 for job in `jobs -p`
 do
   echo "Waiting for $job to finish ...."
   wait $job
 done
}

function copy_result_from_vms()
{
  # Copy the result data to `nutanix_data` directory, create if does not exist.
  mkdir -p  $res_dir #/root/nutanix_data

  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
   local vm_ip=$(get_ip_from_vm_name "$vm_name")
   
   for iteration in 1
   do
     wl_name=$(echo $vm_name | cut -d"_" -f1 )
     start_core=$(echo $vm_name | cut -d"_" -f2 | cut -d"-" -f1)
     end_core=$(echo $vm_name | cut -d"_" -f2 | cut -d"-" -f2)
     result_file=${wl_name}_${start_core}-${end_core}_${file_suffix}_rep_${iteration}

     echo "Copy result: $result_file"
     scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/${result_file} $res_dir
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
