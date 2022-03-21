total_round=1


while [ 1 ]
do
echo ----------total_round $total_round----------
echo "==mclos3 min chnage from 0 to 255=="
for i in {1..255}; do
echo =====min=$i=====;
sleep 1;
./hwdrc_change_mclos3_min.sh $i
./workload.sh S0
 
done 

echo "==setpoint chnage from 32 to 0=="
for i in {32..0}; do
echo =====setopint=$i=====;
sleep 1;
./hwdrc_change_mclos3_min.sh $i
./workload.sh S0

done

let total_round+=1;

done 
