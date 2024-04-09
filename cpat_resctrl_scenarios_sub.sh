#!/bin/bash

hpCores=$1
lpCores=$2
total_cores=$3
hp_threads=$4
lp_threads=$5

HP_CORES=0-$((hpCores - 1))
LP_CORES=0-$((lpCores - 1)),$((2*total_cores))-$((2*total_cores + lpCores -1 ))

hp_cores=0-$((hpCores - 1))
lp_cores=0-$((lpCores - 1))
#Resctrl based scenarios

echo $HP_CORES, $LP_CORES, $hp_cores, $lp_cores

./cpat_resctrl.sh $HP_CORES $LP_CORES

echo "Start Colocated CPAT Disabled Scenario Resctrl"
#umount /sys/fs/resctrl

mount resctrl -t resctrl /sys/fs/resctrl/

#with l2cat, we could only use 7 CLOS
mkdir -p /sys/fs/resctrl/{COS1,COS2,COS3,COS4,COS5,COS6,COS7}



./cpat_disable.sh

#Unmount resctrl interface if it was previously mounted. 
#umount /sys/fs/resctrl

#./cpat_resctrl.sh $HP_CORES $LP_CORES

cd linpack
./runme_xeon64_over_under $hp_threads > ../hp_cpat_disabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt &
hp_process=$!
./runme_xeon64_over_under $lp_threads > ../lp_cpat_disabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt &
lp_process=$!
cd ..

#echo $hp_process > /sys/fs/resctrl/COS4/tasks
#echo $lp_process > /sys/fs/resctrl/COS7/tasks

wait $hp_process

killall -9 xlinpack_xeon64

echo "Start CPAT HP Only Resctrl"
./cpat_resctrl.sh $HP_CORES $LP_CORES
echo "120-179" > /sys/fs/resctrl/COS7/cpus_list

cd linpack
./runme_xeon64_over_under $hp_threads > ../hp_cpat_enabled_resctrl_${hp_cores}_${hp_threads}.txt &
hp_process=$!
wait $hp_process
cd ..

echo $hp_process > /sys/fs/resctrl/COS4/tasks

wait $hp_process
killall -9 xlinpack_xeon64


sleep 5

echo "Start CPAT Enabled Scenario Resctrl"

#./cpat_resctrl.sh $HP_CORES $LP_CORES
#echo "120-179" > /sys/fs/resctrl/COS7/cpus_list

cd linpack
./runme_xeon64_over_under $hp_threads  > ../hp_cpat_enabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt &
hp_process=$!
./runme_xeon64_over_under $lp_threads  > ../lp_cpat_enabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt &
lp_process=$!
cd ..


echo $hp_process > /sys/fs/resctrl/COS4/tasks
echo $lp_process > /sys/fs/resctrl/COS7/tasks


wait $hp_process
killall -9 xlinpack_xeon64



#Process HP/LP Disabled 

duration_HP_CPAT_DIS=$(awk '/Time\(s\)/{getline; getline; print $4}' "hp_cpat_disabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt")
gflops_HP_CPAT_DIS=$(awk '/GFlops/{getline; getline; print $5}' "hp_cpat_disabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt")
duration_LP_CPAT_DIS=$(awk '/Time\(s\)/{getline; getline; print $4}' "lp_cpat_disabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt")
gflops_LP_CPAT_DIS=$(awk '/GFlops/{getline; getline; print $5}' "lp_cpat_disabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt")



# CPAT HP Only

duration_HP_ONLY_CPAT_EN=$(awk '/Time\(s\)/{getline; getline; print $4}' "hp_cpat_enabled_resctrl_${hp_cores}_${hp_threads}.txt")
gflops_HP_ONLY_CPAT_EN=$(awk '/GFlops/{getline; getline; print $5}' "hp_cpat_enabled_resctrl_${hp_cores}_${hp_threads}.txt")


#CPAT HP/LP 

duration_HP_CPAT_EN=$(awk '/Time\(s\)/{getline; getline; print $4}' "hp_cpat_enabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt")
gflops_HP_CPAT_EN=$(awk '/GFlops/{getline; getline; print $5}' "hp_cpat_enabled_resctrl_${hp_cores}_${lp_cores}_${hp_threads}.txt")
duration_LP_CPAT_EN=$(awk '/Time\(s\)/{getline; getline; print $4}' "lp_cpat_enabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt")
gflops_LP_CPAT_EN=$(awk '/GFlops/{getline; getline; print $5}' "lp_cpat_enabled_resctrl_${lp_cores}_${hp_cores}_${lp_threads}.txt")

echo "Scenario","HP_CORES", "LP_CORES", "HP_FREQ", "LP_FREQ", "HP_DURATION", "HP_GFLOP", "LP_DURATION", "LP_GFLOPS"
echo "HP/LP CPAT Disabled Resctrl",$hp_cores, $lp_cores, "-", "-", $duration_HP_CPAT_DIS, $gflops_HP_CPAT_DIS, $duration_LP_CPAT_DIS, $gflops_LP_CPAT_DIS
echo "HP Only", $hp_cores,"-", "-", "-", $duration_HP_ONLY_CPAT_EN, $gflops_HP_ONLY_CPAT_EN, "-", "-"
echo "HP/LP CPAT Enabled Resctrl", $hp_cores, $lp_cores, "-", "-", $duration_HP_CPAT_EN, $gflops_HP_CPAT_EN, $duration_LP_CPAT_EN, $gflops_LP_CPAT_EN



