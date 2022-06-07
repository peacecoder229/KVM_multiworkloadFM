#!/bin/bash

#select Total threads and no of instance.
#case=(["Totalthreads"]="No_of_server_instance")
#incase HT is OFF then actual Totalthreads = Totalthreads/2
#If intended to use 12 physical core , and each instance to use 6 core, then Totalthreads = 24 , hypt=off and No_of_server_instance=2
#lcore, dir, no_of_instance, connections, type


#case=(["28"]="2" ["56"]="4" ["32"]="2")
#for core in "8" "16" "24"
#Configurations  hypt is Hyperthread on/off
#dsize  datasize in B
#rundir is absolute path to memc_rds  dir
#ms = memtier_benchmark load core 1 and me=loadcore 2 from socket1
#ci=start memtier_benchmark core while doing 80% read and 20% write from socket1
hypt="off"
dsize=8192 #2048, 4096, 8192
rundir="/root/memc_redis"


#ci=48
lcore=$1
res_file=$2
ins=$3
mccon=$4
type=$5
memtiercore=$6

if [ "$type" = "redis" ]
then
	servtype="launchredis"
	protocol="redis"
else
	servtype="launchmemcache"
	protocol="memcache_text"
fi


me=$(( memtiercore+1 ))
ms=$memtiercore
ci=$memtiercore

#protocol="redis"
#servtype="launchredis"
#protocol="memcache_text"
#servtype="launchmemcache"
pkill -9 memcached
pkill -9 redis-server


echo "physcores, totalcores,instance, connections, min, max, avg, p99, p75, throughput, HTstatus, Protocol" >> $res_file


# Need to update start of physical core i and start of HT cores j 
# if a system with different number of cores are used
if [ $hypt = "on" ]
then
	highg=$(echo $lcore | cut -f2 -d,)
	lowg=$(echo $lcore | cut -f1 -d,)
	phyc_hi=$(echo $lowg | cut -f2 -d-)
	phyc_lo=$(echo $lowg | cut -f1 -d-)
	ht_hi=$(echo $highg | cut -f2 -d-)
	ht_lo=$(echo $highg | cut -f1 -d-)
	total=$(( ht_hi-ht_lo+phyc_hi-phyc_lo+2 ))
	ht=$(( total/4 ))
	i=$phyc_lo
	j=$ht_lo
else
	phyc_hi=$(echo $lcore | cut -f2 -d-)
	phyc_lo=$(echo $lcore | cut -f1 -d-)
	total=$(( phyc_hi-phyc_lo+1 ))
	ht=$(( total ))
	i=$phyc_lo
	ht_lo=112
	j=$ht_lo
fi


#export runnuma="yes"
export runnuma="None"
serv=0
port=9000
#below for taking core boundaryies for collecting perf stat 
perfstep=$(( total/2 ))
perfstep=$(( perfstep-1 ))

cpi=$(( ht/ins ))
#Please note without HT ON actual no of cores per instance is ht or cpi/2
step=$(( cpi-1 ))
#ccore change multiplier from 1 to 2 for ht runs
#ccore=$(( ht*1 ))
ccore=$(( cpi*1 ))
#changing clinet core to 1x from 2x date July 13th for nginx and mc combo runs .. there is not enough cores in other socket
#ccore=$(( cpi*2 ))
#ccore=$(( cpi*1 ))
cstep=$(( ccore-1 ))
#below cores on the socket 1 are used for metier_bench launch

#ms=32
#me=33

# Starting of the load phase

while [ "${serv}" -lt "${ins}" ]
do
#server cores
	stc1=${i}
	stc2=${j}
	edc1=$(( stc1+step ))
	edc2=$(( stc2+step ))
	port=$(( port+1 ))
	cstc1=${ci}
	cstc2=${cj}
	cedc1=$(( cstc1+cstep ))
	cedc2=$(( cstc2+cstep ))
#client cores
#each amd_mem instance is run with a specific port no  and /run_client_and_server_memtier_r1p1_emon.py uses that port no only to launch all clients.

#echo "./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1} ${port} "4" ${servtype} & "
if [ "$hypt" == "on" ]
then

	export hypt="on"
	echo "./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${dsize} ${servtype} &"
	if [ "${protocol}" == "redis" ]
	then
		./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${cstc1}-${cedc1},${cstc2}-${cedc2} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${dsize} ${servtype} &
	else

		echo "Line 131 ....."
		./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${dsize} ${servtype} &
	fi

else
	 export hypt="off"

	echo "Line 137: ./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1} ${port} "4" ${dsize} ${servtype} &"
	if [ "${protocol}" == "redis" ]
	then
		./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${cstc1}-${cedc1} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${dsize} ${servtype} &
	else
		echo "Line 141 ...."
		./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1} ${port} "4" ${dsize} ${servtype} &
	fi
fi
#echo "./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${servtype} &"
#./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:0 inst${serv}${core} ${protocol} ${ms}-${me} $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} "4" ${servtype} &
wrpids[$serv]=$!
serv=$(( serv+1 ))

i=$(( edc1+1 ))
j=$(( edc2+1 ))
ms=$(( ms+2 ))
me=$(( me+2 ))
done

for pid in ${wrpids[*]}; do
	echo $pid
	wait $pid
done
echo "End of Loading phase"

sleep 5


# for each core config run three connection experiments

#for connections in "2" "4" "8" "16"
for connections in "${mccon}"
do
i=$phyc_lo
j=$ht_lo
serv=0
port=9000
#changing back to total 32 threads as MC is run on 16 cores
#ci=48
#Below is HT start core
cj=72
perfend=$(( ht_lo+perfstep ))
if [ "$hypt" == "on" ]
then
	perf="phton"
# 	echo "perf stat -D 10000 -C 0-${perfstep},56-${perfend} -e tsc,r0300,r00c0,cycle_activity.stalls_mem_any -I2000  --interval-count=60 -o ${perf}${core}_${ins}_${connections}_stat.txt &"
 #	perf stat -D 10000 -C 0-${perfstep},56-${perfend} -e tsc,r0300,r00c0,cycle_activity.stalls_mem_any -I2000  --interval-count=60 -o ${perf}${core}_${ins}_${connections}_stat.txt &

else
	perf="phtoff"
 #	echo "perf stat -D 30000 -C 0-${perfstep} -e tsc,r0300,r00c0,cycle_activity.stalls_mem_any -I2000  --interval-count=60 -o ${perf}${core}_${ins}_${connections}_stat.txt &"
 #	perf stat -D 30000 -C 0-${perfstep} -e tsc,r0300,r00c0,cycle_activity.stalls_mem_any -I2000  --interval-count=60 -o ${perf}${core}_${ins}_${connections}_stat.txt &

fi

 sleep 1

#All files are being removed here insance files as well as ip127files 
cd $rundir/core_scale;  rm -rf inst*; rm -rf memtier_ip*; sleep 1;
rm -f ip127.0.0.1prt90*
sleep 1
echo "All previous inst files being  removed"
cd -
sleep 5

while [ "$serv" -lt "${ins}" ]

do
#server cores
	stc1=${i}
	stc2=${j}
	edc1=$(( stc1+step ))
	edc2=$(( stc2+step ))
	port=$(( port+1 ))
#client cores
	cstc1=${ci}
	cstc2=${cj}
	cedc1=$(( cstc1+cstep ))
	cedc2=$(( cstc2+cstep ))
	perfe=$(( 56+perfstep ))
#003c is  thread cycles when thread is not in halt state and 013c core crystal clocks when thread is unhalted
#CPU_CLK_UNHALTED.REF_TSC EV=x00 UMASK=0x03 so r0300
#CPU_CLK_UNHALTED.REF_XCLK r013c crystal clock
if [ "$hypt" == "on" ]
then

	echo "Line 223: ...."
	./amd_memcached_core_scale.sh 524288 127.0.0.1 1:4 inst${serv}${core} ${protocol} ${cstc1}-${cedc1},${cstc2}-${cedc2}  $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} ${connections} ${dsize} &

else
	# The following line gets executed. Change the param in this line. 
	# 393216 = 10 min, 1048576 = 30 min
	echo "Line 227: ./amd_memcached_core_scale.sh 393216(no. of requests) 127.0.0.1 2:3(write:read) inst${serv}${core} ${protocol} ${cstc1}-${cedc1}  $rundir/core_scale ${stc1}-${edc1} ${port} ${connections} ${dsize} &"
	#./amd_memcached_core_scale.sh 393216 127.0.0.1 1:4 inst${serv}${core} ${protocol} ${cstc1}-${cedc1}  $rundir/core_scale ${stc1}-${edc1} ${port} ${connections} ${dsize} &
	./amd_memcached_core_scale.sh 393216 127.0.0.1 2:3 inst${serv}${core} ${protocol} ${cstc1}-${cedc1}  $rundir/core_scale ${stc1}-${edc1} ${port} ${connections} ${dsize} &
fi

#echo "./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:4 inst${serv}${core} ${protocol} ${cstc1}-${cedc1},${cstc2}-${cedc2}  $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} ${connections} &"
#./amd_memcached_core_scale.sh 1048576 127.0.0.1 1:4 inst${serv}${core} ${protocol} ${cstc1}-${cedc1},${cstc2}-${cedc2}  $rundir/core_scale ${stc1}-${edc1},${stc2}-${edc2} ${port} ${connections} &

#mapping of ports.. port(sweep)->curport-(amd_mem)>servport( client_memt)->memtier_client_server_modules

ldpids[$serv]=$!
serv=$(( serv+1 ))
i=$(( edc1+1 ))
j=$(( edc2+1 ))

ci=$(( cedc1+1 ))
cj=$(( cedc2+1 ))

done


for pid in ${ldpids[*]}; do
	 echo $pid
	 wait $pid
 done
 sleep 2

 echo "FUll read/write done"
sleep 1 
echo "processing all runs launched with each of the amd_memcached..sh call"
cd $rundir/core_scale
#./process_stats_of_file.py  --filepattern="inst*${core}_con${connections}_d${dsize}.txt" --indexpattern="GET" --statpos=1 --indexpos=0 --outfile=testsum
#./process_stats_of_file.py  --filepattern="inst[0-9]${core}_con${connections}_d${dsize}.txt" --indexpattern="GET" --statpos=1 --indexpos=0 --outfile=testsum
./process_stats_of_file.py  --filepattern="inst[0-9]_con${connections}_d${dsize}.txt" --indexpattern="GET" --statpos=1 --indexpos=0 --outfile=testsum
sum=$(cat testsum | grep -v "filename" | awk -F, '{sum2 += $6} END {print sum2}')
p99=$(cat testsum | grep -v "filename" | awk -F, '{sum3 += $7} END {print sum3}')
p75=$(cat testsum | grep -v "filename" | awk -F, '{sum4 += $8} END {print sum4}')
sumavg=$(echo "scale=2; ${sum}/${ins}" | bc)
p99avg=$(echo "scale=2; ${p99}/${ins}" | bc)
p75avg=$(echo "scale=2; ${p75}/${ins}" | bc)

max=$(sort -rnk4 -t, testsum | head -1 | awk -F , '{print $4}')
min=$(sort -nk2 -t, testsum | grep -v max | head -1 | awk -F , '{print $2}')

reshp="${min},${max},${sumavg},${p99avg},${p75avg}"

#hpthrput=$(cat inst[0-9]${core}_con${connections}_d${dsize}.txt  | grep "Totals" | awk '{sumt += $2} END {print sumt}')
hpthrput=$(cat inst[0-9]_con${connections}_d${dsize}.txt  | grep "Totals" | awk '{sumt += $2} END {print sumt}')

sleep 1

#rm -f ip127.0.0.1prt900*

cd -
#metric=$(./process_stats_of_perf_r1.py  --filepattern="${perf}${core}_${ins}_${connections}_stat.txt" --indexpattern="tsc,r0300,r00c0,stalls_mem_any" --statpos=1  --indexpos=2 | grep -v "file")
sleep 1
#echo "${core} ${ins} ${connections} ${res}  ${metric}" >> memc_scale_sum_halfc_HT_july5th_lphp.txt


tot_con=$(( connections*32 ))
echo "$lcore, ${total}, ${ins}, ${connections}, ${reshp}, ${hpthrput}, ${hypt}, ${protocol}" >> $res_file
echo "cur-physcores, totalcores,instance, connections, min, max, avg, p99, p75, throughput, HTstatus"
echo "mcresults:${stc1}-${edc1},${total},${ins},${tot_con},${reshp},${hpthrput},${hypt}"

sleep 1

#deleting all files with SET / GET processed data cannot be done from amd_mem script as multiple of them are running in parallel
#rm -f ip127.0.0.1prt900*

done
