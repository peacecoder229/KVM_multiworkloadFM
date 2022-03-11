#!/bin/bash
TARGET=""
STAGE=""
TestCase_s=""
n_cpus_per_vm=""
workload_per_vm=""

MLC_STRING="mlc"
FIO_STRING="fio"

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
 while getopts ":T:S:C:W:" opt
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
 echo "setup_vm: Calling vm_cloud-init.py"
 python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm
 chmod 777 ./virt-install-cmds.sh
 ./virt-install-cmds.sh
 #mkdir -p results
 echo "Waiting 3 minutes for the VM to boot"
 sleep 180
}

function run_exp_vm()
{
  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
    local vm_ip=$(get_ip_from_vm_name "$vm_name")
    
    case $vm_name in
      *"$MLC_STRING"*)
      run_mlc_vm "$vm_name" "$vm_ip"
      ;;
      
      *"$FIO_STRING"*)
      run_fio_vm "$vm_name" "$vm_ip"
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

function run_mlc_vm()
{
  vm_name=$1
  vm_ip=$2
  echo "Run mlc in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${vm_ip}:/usr/local/bin/
  scp -oStrictHostKeyChecking=no run_${MLC_STRING}.sh root@${vm_ip}:/root
  
  for iteration in 1
  do
    result_file=${MLC_STRING}_rep_${iteration}_ncores
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_mlc.sh $result_file" &
  done
}

function run_fio_vm()
{
  vm_name=$1
  vm_ip=$2
  echo "Run fio in $vm_name: $vm_ip"   
  # echo "Copying to ${ip}"
  scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${vm_ip}:/usr/local/bin/
  scp -oStrictHostKeyChecking=no run_${FIO_STRING}.sh root@${vm_ip}:/root
  
  for iteration in 1
  do
    result_file=${FIO_STRING}_rep_${iteration}_ncores
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/run_fio.sh $result_file" &
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
        *"$MLC_STRING"*)
        result_file=${MLC_STRING}_rep_${iteration}_ncores
        scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/$result_file* /root/nutanix_data/
        ;;
        *"$FIO_STRING"*)
        result_file=${FIO_STRING}_rep_${iteration}_ncores
        scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/$result_file* /root/nutanix_data/
        ;;
        *)
        echo "The VM name should match the name of the workload in lowercase."
        ;;
      esac
    done
  done
}

function setup_exp()
{
 echo "In setup_5g"
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
 #mkdir -p results 
 #mkdir -p results.old
 #mv results/* results.old/*
 #rm -rf /tmp/5g_kernel_perf* &>2
 if [ "host" = "${TARGET}" ]
 then
  virsh list --name | xargs -i destroy {}
  for iteration in 1 2 3
  do
   ./run_${workload_name}.sh
   #mv results/*/5g_kernel_perf.csv /tmp/5g_kernel_perf${iteration}.csv &>2
   #mv results/* results.old/
  done
 elif [ "vm" = "${TARGET}" ]
 then
  run_exp_vm
  copy_result_from_vms
 fi
}

function main ()
{
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

