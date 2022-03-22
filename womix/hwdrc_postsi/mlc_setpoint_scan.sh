total_round=1

#while [ 1 ]
#do
echo ----------total_round $total_round----------

<<'MCLOS_MIN_FULL_SCAN'
test_setpoint=0

for test_mclos_min in {255..0}; do
echo =====mclos_min=$j=====;
./hwdrc_change_setpoint_mclos_min.sh $test_setpoint $test_mclos_min
./workload_setpoint_scan.sh S0 0
done
MCLOS_MIN_FULL_SCAN

<<'SETPONIT_SCAN_WITH_MCLOS_MIN'
for test_mclos_min in {180,132,105,86,62,47,36,0}; do
echo "==setpoint chnage from 0 to 32=="
for test_setpoint in {0..32}; do
echo =====mclos_min=$test_mclos_min=setpoint=$test_setpoint=====;
sleep 1;
./hwdrc_change_setpoint_mclos_min.sh $test_setpoint $test_mclos_min
./workload_setpoint_scan.sh S0 0
done
done 
SETPONIT_SCAN_WITH_MCLOS_MIN

test_mclos_min=1
echo "==setpoint chnage from 0 to 255=="
for test_setpoint in {0..255}; do
echo =====mclos_min=$test_mclos_min=setpoint=$test_setpoint=====;
sleep 1;
./hwdrc_change_setpoint_mclos_min.sh $test_setpoint $test_mclos_min
./workload_setpoint_scan.sh S0 0
done

<<'COMMENTS'
echo "==setpoint chnage from 32 to 0=="
for i in {32..0}; do
echo =====setopint=$i=====;
sleep 1;
./hwdrc_change_setpoint.sh $i
./workload_setpoint_scan.sh S0 0

done
COMMENTS

let total_round+=1;

#done 
