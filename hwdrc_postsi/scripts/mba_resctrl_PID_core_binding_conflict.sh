#32c 2s
#LP_CORES=32-47,96-111 
#HP_CORES=48-63,112-127
#24c
#NUMA node0 CPU(s):     0-23,48-71
#NUMA node1 CPU(s):     24-47,72-95
#LP_CORES=24-35,72-83 
#HP_CORES=36-47,84-95

LP_CORES=24-47,72-95 
HP_CORES=24-47,72-95

init_resctrl(){

echo "remount resctrl to reset the CLOS setting"
umount resctrl
mount resctrl -t resctrl /sys/fs/resctrl/ 
mkdir -p /sys/fs/resctrl/{C01,C02,C03,C04,C05,C06,C07,C08,C09,C10,C11,C12,C13,C14}

}

g_mapclostomclos=0
g_CLOSToMEMCLOS=0

map_clos_to_mclos(){
#map CLOS to MCLOS
#input 1:CLOS (C01~C14)
#input 2:MCLOS (0~3)
#return in $g_mapclostomclos
clos=$1
mclos=$2

closid=`cat /sys/fs/resctrl/$clos/closid`
g_mapclostomclos=$[mclos << closid *2]

}

prepare_CLOStoMCLOS(){
#map CLOS4 to MCLOS0 HP
#map CLOS5 to MCLOS1 
#map CLOS6 to MCLOS2
#map CLOS7 to MCLOS3 LP
#return in $g_CLOSToMEMCLOS

map_clos_to_mclos C04 0
g_CLOSToMEMCLOS=$[g_CLOSToMEMCLOS + g_mapclostomclos]

map_clos_to_mclos C05 1
g_CLOSToMEMCLOS=$[g_CLOSToMEMCLOS + g_mapclostomclos]

map_clos_to_mclos C06 2
g_CLOSToMEMCLOS=$[g_CLOSToMEMCLOS + g_mapclostomclos]

map_clos_to_mclos C07 3
g_CLOSToMEMCLOS=$[g_CLOSToMEMCLOS + g_mapclostomclos]

#printf 'CLOSToMEMCLOS=%x\n' $g_CLOSToMEMCLOS
}

associate_cores_to_clos(){

echo "associate S1_ALL_CORES:"$S1_ALL_CORES" to C02"
echo "associate HP task PID"$LP_CORES" to C03"

echo $S1_ALL_CORES>/sys/fs/resctrl/C02/cpus_list

#cat /sys/fs/resctrl/{C04,C05,C06,C07}/cpus_list
}

init_resctrl


echo "MB:0=10;1=10" > /sys/fs/resctrl/C02/schemata 
echo "MB:0=100;1=100" > /sys/fs/resctrl/C03/schemata 

#echo "associate LP_CORES:"$LP_CORES" to C02"
#echo $LP_CORES>/sys/fs/resctrl/C02/cpus_list


rm -rf "/sys/fs/cgroup/cpu,cpuacct/C02" "/sys/fs/cgroup/cpu,cpuacct/C03"

mkdir "/sys/fs/cgroup/cpu,cpuacct/C02"
mkdir "/sys/fs/cgroup/cpu,cpuacct/C03"


echo "====stream HP+LP mix===="
time taskset -c $HP_CORES /home/longcui/benchmark/stream/stream_c_200times_hp|grep Triad &

echo "associate HP task PID"$HP_CORES" to C03"
ID=`ps -efL | grep stream_c_200times_hp | grep -v "grep" | awk '{print $4}'`

for single_id in $ID
do
echo "$single_id" > /sys/fs/resctrl/C03/tasks
echo "$single_id" > /sys/fs/cgroup/cpu,cpuacct/C03/tasks
done 
#cat /sys/fs/resctrl/C03/tasks

time taskset -c $LP_CORES /home/longcui/benchmark/stream/stream_c_200times_lp|grep Triad &

echo "associate LP task PID"$HP_CORES" to C02"
ID=`ps -efL | grep stream_c_200times_lp | grep -v "grep" | awk '{print $4}'`

for single_id in $ID
do
echo "$single_id" > /sys/fs/resctrl/C02/tasks
echo "$single_id" > /sys/fs/cgroup/cpu,cpuacct/C02/tasks
done


echo 1024 > /sys/fs/cgroup/cpu,cpuacct/C02/cpu.shares
echo 10240 > /sys/fs/cgroup/cpu,cpuacct/C03/cpu.shares

#quota = 10ms,period = 50ms
#take 10ms every 50ms:1 cpu 20% in total
#echo 10000 > /sys/fs/cgroup/cpu,cpuacct/C02/cpu.cfs_quota_us
#echo 50000 > /sys/fs/cgroup/cpu,cpuacct/C02/cpu.cfs_period_us 

#enable core schduling
echo 1 > "/sys/fs/cgroup/cpu,cpuacct/C02/cpu.core_tag"
echo 1 > "/sys/fs/cgroup/cpu,cpuacct/C03/cpu.core_tag"

