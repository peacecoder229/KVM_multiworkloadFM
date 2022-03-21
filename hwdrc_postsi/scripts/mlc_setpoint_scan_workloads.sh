total_round=1

for MLC_WL in {"R","W2","W3","W4","W5","W6","W7","W8","W9","W10","W11","W12"}; do
#for MLC_WL in {"W4","W5","W6","W7","W8","W9","W10","W11","W12"}; do

test_mclos_min=1
echo "==setpoint chnage from 0 to 255==Workload=$MLC_WL="
for test_setpoint in {0..255}; do
#test_setpoint=120
echo =====mclos_min=$test_mclos_min=setpoint=$test_setpoint=====Workload=$MLC_WL=;
sleep 1;
./hwdrc_change_setpoint_mclos_min.sh $test_setpoint $test_mclos_min
./workload_setpoint_scan_workload_scan.sh S0 0 $MLC_WL
done

done

