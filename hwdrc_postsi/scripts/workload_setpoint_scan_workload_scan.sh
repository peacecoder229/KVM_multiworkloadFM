

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
echo "./workload.sh on [S0|S1] [core_list_for_HP]"
echo "S0/S1:workload on Socket0 or Socket1"
echo "core_list_for_HP:core list for High priority TASK.Low priority work load on 32 cores"
echo "Samples:"
echo "1)run 2 MLC workloads on S0 with 2 MEM CLOS:"
echo "./workload.sh S0"
echo "2)run 2 MLC workload on S1, specify the core 32-47 to HP workload"
echo "./workload.sh S1 32-47"

exit 1
}

if [ $# -eq 0 ]; then

invalind_params

elif [ $# -eq 3 ]; then
  if [ $1 == "S0" ];then
  echo "workload on Socket 0"
  #D0
  #HP_CORES=0-15,64-79
  #LP_CORES=16-31,80-95

#32 cpu for HP,rest for lp
#HP_CORES=0-15,48-63
#LP_CORES=16-23,64-71

  #D1 24C
  #HP_CORES=0-11,48-59
  #LP_CORES=12-23,60-71
  #SP,24C 
  #HP_CORES=0,2,4,6,8,10,12,14,16,18,20,22,48,50,52,54,56,58,60,62,64,66,68,70
  #LP_CORES=1,3,5,7,9,11,13,15,17,19,21,23,49,51,53,55,57,59,61,63,65,67,69,71

  #SPR D0 ,56C
  #HP_CORES=0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,112,114,116,118,120,122,124,126,128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,158,160,162,164,166
  #LP_CORES=1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,113,115,117,119,121,123,125,127,129,131,133,135,137,139,141,143,145,147,149,151,153,155,157,159,161,163,165,167
  HP_CORES=0-27,112-139
  LP_CORES=28-55,140-167

  #D1 24c ECS: 32 HP+8 LP
  #HP_CORES=0-15,48-63
  #LP_CORES=16-19,64-67

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
<<'CORE_CONFIG'
elif [ $# -eq 2 ]; then
  if [ $1 == "S0" ];then
  echo "workload on Socket 0"
  HP_CORES=$2
  #D0
  #LP_CORES=16-31,80-95
  #D1
  LP_CORES=12-23,60-71
  elif [ $1 == "S1" ];then
  echo "workload on Socket 1"
  HP_CORES=$2
  #D0
  #LP_CORES=48-63,112-127
  #D1
  LP_CORES=36-47,84-95
  else
  invalind_params
  fi
CORE_CONFIG

else
invalind_params
fi


TIME=10
MLC_WL=$3
echo "$MLC_WL"

function benchmark()
{
        core=$1
        tag=$2
        delay=$3
        #high memBW
        string_delay=`printf "%5.5d" $3`

        score=$(mlc --loaded_latency -${MLC_WL} -t${TIME} -T -k${core} -d${delay} | grep ${string_delay} | awk '{print $3}')

        #printf "=%s=%.1f=\n" $tag $score
        printf "delay=%d=%s=%.1f=" $delay $tag $score
}

function col()
{

	mlc_delay=$1
        benchmark $LP_CORES lp $mlc_delay&
        lp_process_id=$!
        benchmark $HP_CORES hp $mlc_delay
        ##sleep 2
        #wait for lp process finished
        #other wise, it may impact the next mlc workload calc
        wait $!
}

#map CLOS4 to HP_CORES
#map CLOS7 to LP_CORES
#pqos -e llc:7=0xfff
#pqos -e llc:4=0xfff

pqos -a llc:7=$LP_CORES
pqos -a llc:4=$HP_CORES


echo "HP_CORES="$HP_CORES
echo "LP_CORES="$LP_CORES
#<<'COMMENT'
##printf "\n====MLC LP only====$MLC_WL=="
#printf "====MLC HP only===="
#printf "====MLC HP+LP mix====\n"
##input_mlc_delay=$2
##benchmark $LP_CORES lp $input_mlc_delay

##sleep 1
##echo "sleep 1" 
##printf "\n====MLC HP only====$MLC_WL=="
##benchmark $HP_CORES hp $input_mlc_delay

##sleep 1
##echo "sleep 1" 
#COMMENT

printf "\n====MLC HP+LP mix====$MLC_WL=="
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
