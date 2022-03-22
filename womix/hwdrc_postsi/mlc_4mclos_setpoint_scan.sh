#XCC 24C,D1
#CORES1=24-29,72-77
#CORES2=30-35,78-83
#CORES3=36-41,84-89
#CORES4=42-47,90-95

CORES1=0,4,8,12,16,20,48,52,56,60,64,68
CORES2=1,5,9,13,17,21,49,53,57,61,65,69
CORES3=2,6,10,14,18,22,50,54,58,62,66,70
CORES4=3,7,11,15,19,23,51,55,59,63,67,71


#XCC 32C,D1
#CORES1=32-39,96-103
#CORES2=40-47,104-111
#CORES3=48-55,112-119
#CORES4=56-63,120-127


#let i=0;while [ $i -le  2] ;
for test_setpoint in {0..255}; do
echo =====test round $test_setpoint=====;
sleep 1;
#./hwdrc_change_setpoint.sh $i
./hwdrc_change_setpoint_mclos_min.sh $test_setpoint 1
pqos -R
#pqos -a core:4=$CORES1
#pqos -a core:5=$CORES2
#pqos -a core:6=$CORES3
#pqos -a core:7=$CORES4


./workload_4mclos.sh

#do let i+=1;
done 

