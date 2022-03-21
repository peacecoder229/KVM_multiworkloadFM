
let i=0;while [ $i -le 5 ] ;do let i+=1;
echo =====test round $i=====;
./hwdrc_change_setpoint.sh 1
./workload_120s.sh S0 

sleep 30;

./hwdrc_change_setpoint.sh 1
./workload_120s.sh S0 

./hwdrc_change_setpoint.sh 19
./workload_120s.sh S0 

done 

