#!/bin/bash
TARGET=""
STAGE=""
TestCase_s=""
n_cpus_per_vm=""
workload_name=""

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
     W) workload_name="$OPTARG"
	;;
     \?)
        echo "Invalid option: -$OPTARG"
        exit 1 
       ;;
    esac 
 done
}

function summary()
{
 id=$1
 sed -n 1p /tmp/5g_kernel_perf* | tail -n 1 > ${id}_summary.csv
 for test_case in $(seq 2 1 8)
 do
  WL=$(ls /tmp/5g_kernel_perf* | xargs -i sed -n ${test_case}p {} |tail -n 1 | cut -d',' -f1)
  avgs=$(ls /tmp/5g_kernel_perf* | xargs -i sed -n ${test_case}p {} | awk -v n=$( ls /tmp/5g_kernel_perf* | wc -l ) -F',' '{sum+=$2;sum2+=$3} END{print sum/n","sum2/n}')
  echo "${WL},${avgs}" >> ${id}_summary.csv
 done
}

function setup_VM()
{
 echo "setup_VM: Calling vm_cloud_init.py"
 python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_name
 chmod 777 ./virt-install-cmds.sh
 ./virt-install-cmds.sh
 #mkdir -p results
 echo "Waiting 3 minutes for the VM to boot"
 sleep 180
}

function run_VM()
{
 rm -f ${HOME}/.ssh/known_hosts
 iplist=() #list for the IPs of running vms
 #pids=()   #list for the pids used to wait the wrk load to complete before collecting the results
 declare -A dic # ip:pid dict
 ips=$( virsh net-list --name | xargs -i virsh net-dhcp-leases --network {} | cut -f 1 -d "/" | cut -f 16 -d " "| grep -v "-")
 for ip in ${ips}
 do
  ping -c 3 -w 3 ${ip} > /dev/null
  if (( $? == 0 ))
   then
    iplist+=($ip)
  fi
  done
 if [ -n "${iplist[0]}" ]
 then
  for ip in ${iplist[@]}
  do
   scp -oStrictHostKeyChecking=no /usr/local/bin/mlc root@${ip}:/usr/local/bin/
   scp -oStrictHostKeyChecking=no run_${workload_name}.sh root@${ip}:/root
   for iteration in 1
   do
    result_file=${workload_name}_rep_${iteration}_ncores
    # ssh -oStrictHostKeyChecking=no root@${ip} "rm -rf /root/results/*"
    ssh -oStrictHostKeyChecking=no root@${ip} "/root/run_$workload_name.sh $result_file" &
   done
  done
 fi

 for job in `jobs -p`
 do
 echo $job
   wait $job
 done
}

function copy_result_from_VM()
{ 
  rm -f ${HOME}/.ssh/known_hosts
 iplist=() #list for the IPs of running vms
 #pids=()   #list for the pids used to wait the wrk load to complete before collecting the results
 declare -A dic # ip:pid dict
 ips=$( virsh net-list --name | xargs -i virsh net-dhcp-leases --network {} | cut -f 1 -d "/" | cut -f 16 -d " "| grep -v "-")
 for ip in ${ips}
 do
  ping -c 3 -w 3 ${ip} > /dev/null
  if (( $? == 0 ))
   then
    iplist+=($ip)
  fi
  done
 if [ -n "${iplist[0]}" ]
 then
  for ip in ${iplist[@]}
  do
   for iteration in 1
   do
    result_file=${workload_name}_rep_${iteration}_ncores
    # ssh -oStrictHostKeyChecking=no root@${ip} "rm -rf /root/results/*"
    scp -oStrictHostKeyChecking=no root@${ip}:/root/$result_file* /root/muktadir/
   done
  done
 fi
}

function setup_5G()
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
  setup_VM
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
  run_VM
  copy_result_from_VM
 fi
}

function main ()
{
 get_config
 handle_args $@
 if [ "setup" = "${STAGE}" ]
 then
  setup_5G
 elif [ "run" = "${STAGE}" ]
 then
  run_exp
  # summary "${TestCase_s}"
 else
  echo "Stage not available"
 fi
}

main $@

