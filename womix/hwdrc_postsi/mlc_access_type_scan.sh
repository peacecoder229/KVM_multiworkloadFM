
for MLC_WL in {"R","W2","W3","W4","W5","W6","W7","W8","W9","W10","W11","W12"}; do

#./workload_set_workload.sh S0 $MLC_WL
mlc -$MLC_WL --loaded_latency -k1-23,48-71

done
