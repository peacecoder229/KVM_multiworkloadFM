

#HP_CORES=$1
#LP_CORES=48-63,112-127

#XCC D0 QWAE:32C 300W, 2.9Ghz,2S HT on.
#NUMA node0 CPU(s):   0-31,64-95
#NUMA node1 CPU(s):   32-63,96-127
#HP_CORES=0-15,64-79,32-47,96-111
#LP_CORES=16-31,80-95,48-63,112-127

#XCC D1 QWMA, Ali customized SKU:24C, 185W, 2.5Ghz,2S HT on
#NUMA node0 CPU(s):     0-23,48-71
#NUMA node1 CPU(s):     24-47,72-95
#HP_CORES=0-11,48-59,24-35,72-83
#LP_CORES=12-23,60-71,36-47,84-95


function invalind_params()
{
echo "./workload_ecs.sh on [S0|S1] [pyhsical_core_count_HP] [pyhsical_core_count_LP] [mlc delay for HP]"
echo "S0/S1:workload on Socket0 or Socket1"
echo "pyhsical_core_count:core list for High priority TASK."
echo "Samples:"
echo "1)run 2 MLC workloads on S0 with 2 MEM CLOS:"
echo "./workload.sh S0"
echo "2)run 2 MLC workload on S1, specify the core 32-47 to HP workload"
echo "./workload.sh S1 32-47"

exit 1
}

if [ $# -eq 0 ]; then

invalind_params

elif [ $# -eq 4 ]; then
  if [ $1 == "S0" ];then
  echo "workload on Socket 0"
  #D0
  #HP_CORES=0-15,64-79
  #LP_CORES=16-31,80-95

#32 cpu for HP,rest for lp
#HP_CORES=0-15,48-63
#LP_CORES=16-23,64-71

  input_HP_core_count=$2
  input_LP_core_count=$3
  input_mlc_delay=$4

  HP_start_1st_half=0
  HP_start_2nd_half=64

  HP_end_1st_half=$((HP_start_1st_half + $input_HP_core_count / 2 -1))
  HP_end_2nd_half=$(($HP_start_2nd_half + $input_HP_core_count / 2 -1))
  HP_CORES="$HP_start_1st_half-$HP_end_1st_half,$HP_start_2nd_half-$HP_end_2nd_half"

  LP_start_1st_half=$(($HP_end_1st_half + 1 ))
  LP_start_2nd_half=$(($HP_end_2nd_half +1 ))

  LP_end_1st_half=$(($LP_start_1st_half + $input_LP_core_count / 2 -1))
  LP_end_2nd_half=$(($LP_start_2nd_half + $input_LP_core_count / 2 -1))

  LP_CORES="$LP_start_1st_half-$LP_end_1st_half,$LP_start_2nd_half-$LP_end_2nd_half"

  echo $HP_CORES
  echo $LP_CORES

  #./ecs_hwdrc_change_setpoint_mclos_min.sh 42 $HP_CORES $LP_CORES
pqos -e llc:1=0x7ff
pqos -e llc:2=0x7ff
pqos -e mba:1=100
pqos -e mba:2=10

pqos -a llc:1=$HP_CORES
pqos -a llc:2=$LP_CORES


  elif [ $1 == "S1" ];then 
  echo "workload on Socket 1"
  #D0
  #HP_CORES=32-47,96-111
  #LP_CORES=48-63,112-127
  #D1
  HP_CORES=24-35,72-83
  LP_CORES=36-47,84-95


  else
  invalind_params
  fi

else
invalind_params
fi


TIME=10

function benchmark()
{
        core=$1
        tag=$2
        delay=$3
        #high memBW
        string_delay=`printf "%5.5d" $3`
        
        #echo "$(mlc --loaded_latency -R -t${TIME} -T -k${core} -d${delay}"
        score=$(mlc --loaded_latency -R -t${TIME} -T -k${core} -d${delay} | grep ${string_delay} | awk '{print $3}')

        #printf "=%s=%.1f=\n" $tag $score
        printf "delay=%d=%s=%.1f=" $delay $tag $score
}

function col()
{

	mlc_delay=$1
        benchmark $LP_CORES lp 0 &
        lp_process_id=$!
        benchmark $HP_CORES hp $mlc_delay 
        ##sleep 2
        #wait for lp process finished
        #other wise, it may impact the next mlc workload calc
        wait $!
}


echo "HP_CORES="$HP_CORES
echo "LP_CORES="$LP_CORES
#<<'COMMENT'
printf "\n====MLC LP only===="
#printf "====MLC HP only===="
#printf "====MLC HP+LP mix====\n"
benchmark $LP_CORES lp 0

##sleep 1
##echo "sleep 1" 
printf "\n====MLC HP only===="
benchmark $HP_CORES hp $input_mlc_delay

##sleep 1
##echo "sleep 1" 
#COMMENT

printf "\n====MLC HP+LP mix===="
col $input_mlc_delay

printf "\n"

<<'COMMENT'
#echo "====stream HP+LP mix===="
#time taskset -c $HP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad &
#time taskset -c $LP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad

echo "====stream LP only===="
taskset -c $LP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad 

sleep 1
echo "sleep 1" 

echo "====stream HP only===="
taskset -c $HP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad 

sleep 1
echo "sleep 1" 

echo "====stream HP+LP mix===="
taskset -c $LP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad &
taskset -c $HP_CORES /home/longcui/benchmark/stream/stream_c_200times|grep Triad
COMMENT
