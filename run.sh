#!/bin/bash

TARGET=""
STAGE=""
TestCase_s=""
n_cpus_per_vm=""
workload_per_vm=""
file_suffix=""
cpu_affinity=1

BENCHMARK_DIR="/home"
vm_config=""

declare -A result_file_ip # list of result file names and their corresponding vm's ip

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
 while getopts "AT:S:C:W:F:O:D:" opt
 do 
   case $opt in 
     A) cpu_affinity=0
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
     F) vm_config="$OPTARG"
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
  #local mac=$(virsh domiflist $vm_name | awk '{ print $5 }' | tail -2 | head -1)
  local mac=$(virsh domiflist $vm_name |  awk '{ print $5 }' | head -3 | tail -1)
  #echo $mac
  local ip=$(arp -a | grep $mac | awk '{ print $2 }' | sed 's/[()]//g')
  echo $ip
}

function setup_vm() 
{
  echo "Creating VMs with the following configurations: number of cpus per vm = $n_cpus_per_vm, workload per vm = $workload_per_vm. vm config = $vm_config"
  if (( $cpu_affinity == 0 )); then
    echo "python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm -f $vm_config"
    python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm -f $vm_config
  else
    echo "python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm --cpu_affinity -f $vm_config"
    python3 vm_cloud-init.py -c $n_cpus_per_vm -w $workload_per_vm --cpu_affinity -f $vm_config
  fi
  
  chmod 777 ./virt-install-cmds.sh
  ./virt-install-cmds.sh
  echo "Waiting 3 minutes for the VM to boot"
  sleep 180
  
  virsh list --all --name|xargs -i virsh destroy {} --graceful
  virsh list --all --name|xargs -i virsh start {}
  virsh list
  sleep 120

  setup_workloads
  sleep 60 # sleep for sometime to make sure the workload setup is successful
}

function setup_workloads()
{
  echo "Setting up workloads ....."
  vm_name_list=$(virsh list --name)
  
  for vm_name in $vm_name_list
  do
    local vm_ip=$(get_ip_from_vm_name "$vm_name")
    
    # setup yum and install python3
    scp -oStrictHostKeyChecking=no update_yum_repo.sh root@${vm_ip}:/root
    scp -oStrictHostKeyChecking=no client.py root@${vm_ip}:/root
    ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/update_yum_repo.sh"
    
    # setup individual workloads
    case $vm_name in
      *"mlc"*)
  	echo "Setting up mlc ....."
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
	scp -oStrictHostKeyChecking=no $BENCHMARK_DIR/mlc root@${vm_ip}:/usr/local/bin/	
	
	# Increase the memory of VM
        #echo "Increasing memory of VM $vm_name ..."
	#virsh shutdown $vm_name; sleep 1m
	#virsh setmaxmem $vm_name 50G --config
	#virsh setmem $vm_name 50G --config 
	#virsh start $vm_name; sleep 1m
        #echo "Done increasing memory of VM $vm_name."
      ;;
      
      *"rn50"*)
        echo "Setting up rn50 ....."
        scp -oStrictHostKeyChecking=no $BENCHMARK_DIR/rn50.img.xz root@${vm_ip}:/root/
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "xzcat  /root/rn50.img.xz |docker load"
      ;;
      
      *"spdk_fio"*)
        echo "Setting up SPDK and fio ....."
        scp -r -oStrictHostKeyChecking=no spdk_exp_dir root@${vm_ip}:/root
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/spdk_exp_dir/setup_spdk.sh"
      ;;
       
      *"spdk-rdma"*) # Run spdk-rdma experiment b/w 346T and 319T
        echo "Setting up SPDK to run with RDMA ....."
        scp -r -oStrictHostKeyChecking=no spdk_exp_dir root@${vm_ip}:/root
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/spdk_exp_dir/setup_spdk_rdma.sh"
	# Copy the VM's public key (created in setup_spdk_rdma.sh) to this machine
        scp -r -oStrictHostKeyChecking=no root@${vm_ip}:/root/.ssh/id_rsa.pub spdk_exp_dir/
	# Copy the VM's public key from this machine to 319T
        cat spdk_exp_dir/id_rsa.pub | ssh -oStrictHostKeyChecking=no root@10.242.51.105 "cat >> /root/.ssh/authorized_keys"
      ;;

      *"stressapp"*)
        echo "Setting up stressup ....."
        scp -oStrictHostKeyChecking=no $BENCHMARK_DIR/streeapp.tar root@${vm_ip}:/root/
      ;;
      
      *"redis"*)
        echo "Setting up redis ....."
        
	# Increase the memory of VM
        #echo "Increasing memory of VM $vm_name ..."
	#virsh shutdown $vm_name; sleep 1m
	#virsh setmaxmem $vm_name 100G --config
	#virsh setmem $vm_name 100G --config 
	#virsh start $vm_name; sleep 1m
        #echo "Done increasing memory of VM $vm_name."
	
	    scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
	    ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"
      ;;
      
      *"memcache"*)
        echo "Setting up memcache ....."
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
        scp -r -oStrictHostKeyChecking=no memc_redis root@${vm_ip}:/root
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "/root/memc_redis/install.sh"
      ;;
      
      *"ffmpegdocker"*)
        echo "Setting up ffmpegdocker ....."
        scp -r -oStrictHostKeyChecking=no $BENCHMARK_DIR/ffmpeg root@${vm_ip}:/root/
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "docker load < /root/ffmpeg/ffmpeg.tar"
      ;;
      
      *"ffmpegbm"*)
        echo "Setting up ffmpegbm ....."
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf install -y https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm" 
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf install -y https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum-config-manager --enable powertools"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "dnf -y install ffmpeg"
        scp -r -oStrictHostKeyChecking=no $BENCHMARK_DIR/uhd1.webm root@${vm_ip}:/root/
      ;;
     
      *"rnnt"*)
        echo "Setting up rnnt ....."
        echo "Starting setup for RNNT"
      
        # Increase the volume of VM disk
        virsh shutdown $vm_name; sleep 10
        qcow_file=$(virsh domblklist $vm_name | grep vda | awk '{print $2}')
        echo "qemu-img resize $qcow_file +200G"
        qemu-img resize $qcow_file +200G
        virsh start $vm_name; sleep 60

        # create docker
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "docker pull dcsorepo.jf.intel.com/dlboost/pytorch:2022_ww16"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "docker run -itd --privileged --net host --shm-size 4g --name pytorch_spr_2022_ww16 -v /home/dataset/pytorch:/home/dataset/pytorch -v /home/dl_boost/log/pytorch:/home/dl_boost/log/pytorch dcsorepo.jf.intel.com/dlboost/pytorch:2022_ww16 bash"
        
        # copy rnnt
        scp -r -oStrictHostKeyChecking=no $BENCHMARK_DIR/rnnt root@${vm_ip}:/home/dataset/pytorch/
        scp -r -oStrictHostKeyChecking=no run_rnnt_exec.sh root@${vm_ip}:/home/dataset/pytorch/
      ;;
      
      *"speccpu"*)
        echo "Install speccpu in VM."
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y libnsl"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y numactl "
        scp -r -oStrictHostKeyChecking=no $BENCHMARK_DIR/spec17.tar.gz root@${vm_ip}:/root/
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "cd /root; tar -xf spec17.tar.gz; cd .."
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "rm -rf /root/spec17.tar.gz"
        scp -r -oStrictHostKeyChecking=no run_speccpu.sh root@${vm_ip}:/root/
        scp -r -oStrictHostKeyChecking=no speccpu_script/ root@${vm_ip}:/root/
      ;;
      
      *"unet"*)
        # Increase the volume of VM disk
        virsh shutdown $vm_name; sleep 10
        qcow_file=$(virsh domblklist $vm_name | grep vda | awk '{print $2}')
        echo "qemu-img resize $qcow_file +200G"
        qemu-img resize $qcow_file +200G
        virsh start $vm_name; sleep 60

        echo "Installing unet in the VM ...."
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "mkdir -p /rocknvme1/dataset/tensorflow/log"
        scp -r -oStrictHostKeyChecking=no $BENCHMARK_DIR/3d_unet_mlperf_inference root@${vm_ip}:/rocknvme1/dataset/tensorflow/
        scp -r -oStrictHostKeyChecking=no unet_script/ root@${vm_ip}:/root/
      ;;

      *"dpdk"*)
        echo "Setup the VM for dpdk ...."
        scp -r -oStrictHostKeyChecking=no dpdk_exp_dir root@${vm_ip}:/root
    	ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum groupinstall -y 'Development Tools'"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "pip3 install meson ninja pyelftools"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y numactl-devel"
        
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "git clone https://github.com/DPDK/dpdk"
      ;;
      
      *"nginx"*)
        echo "Setup the VM for nginx ...."
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "yum install -y python3"
        scp -r -oStrictHostKeyChecking=no nginx_exp_dir/ root@${vm_ip}:/root/
	ssh -oStrictHostKeyChecking=no root@${vm_ip} "cd /root/nginx_exp_dir; ./install-nginx-wrk.sh"
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
      *"speccpu"*)
        # speccpu has the following format: speccpu:502.gcc_r:3:46-47, so run the exp and store the result_file here
        benchmark=$(echo $vm_name | cut -d: -f2)
        n_iteration=$(echo $vm_name | cut -d: -f3)
        asm=$(echo $vm_name | cut -d: -f4)
        start_core=$(echo $vm_name | cut -d: -f5 | cut -d- -f1)
        end_core=$(echo $vm_name | cut -d: -f5 | cut -d- -f2)
        echo "$benchmark will run in core range: $start_core-$end_core"

        result_file=${benchmark}_${start_core}-${end_core}_${file_suffix}

        for iteration in 1
        do
          scp -oStrictHostKeyChecking=no run_speccpu.sh root@${vm_ip}:/root/
          ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash chmod +x /root/run_speccpu.sh"
          ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash run_speccpu.sh ${result_file}_${iteration} $start_core $end_core True $benchmark $n_iteration $asm" &
          result_file_ip[${result_file}_${iteration}]=$vm_ip
        done
      ;;
      *"unet"*)
        workload_script="run_3dunet.sh"
      ;;
      *"spdk_fio"*)
        workload_script="run_spdk_fio.sh"
      ;;
      *"nginx"*)
        workload_script="run_nginx.sh"
      ;;
      *"spdk-rdma"*)
	    workload_script="run_spdk-rdma.sh"
      ;;
      *)
        echo "The VM name should match the name of the workload in lowercase."
      ;;
    esac
    
    # For workloads other than speccpu do the following 
    if [[ "$vm_name" != *"speccpu"* ]]; then
      echo "Run $workload_script in $vm_name: $vm_ip"
  
      for iteration in 1
      do
        wl_name=$(echo $vm_name | cut -d: -f1 )
        start_core=$(echo $vm_name | cut -d: -f2 | cut -d"-" -f1)
        end_core=$(echo $vm_name | cut -d: -f2 | cut -d"-" -f2)
        result_file=${wl_name}_${start_core}-${end_core}_${file_suffix}_rep_${iteration}
        echo "Store $result_file in dictionary."
        result_file_ip[${result_file}]=$vm_ip
      
        scp -oStrictHostKeyChecking=no ${workload_script} root@${vm_ip}:/root/
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash chmod +x /root/$workload_script"
        ssh -oStrictHostKeyChecking=no root@${vm_ip} "bash /root/$workload_script $result_file" &
      done # iteration
    fi
  done # VMs
 
 # waiting for the jobs to finish before we copy results back
 echo "waiting for the jobs to finish before we copy results back"
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
  # loop over the keys
  echo "Copy result data to $res_dir ....."
  for result_file in "${!result_file_ip[@]}"; do
     vm_ip=${result_file_ip[${result_file}]}
     echo "Copy $result_file from $vm_ip to $res_dir"
     scp -oStrictHostKeyChecking=no root@${vm_ip}:/root/${result_file} $res_dir
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
