
#for core_count in {48,32,16,8,4,2}; do
#for core_count in $(seq 2 2 32);do

echo "======HP 16,LP changed 2-48"

for core_count in $(seq 2 2 48); do
echo "./workload_ecs.sh S0 16 $core_count 0"
#./workload_ecs.sh S0 16 $core_count 0
./workload_ecs_no_hwdrc.sh S0 16 $core_count 0
done

echo "======HP changed 2-16,LP fixed at 48"


for core_count in $(seq 2 2 16); do
echo "./workload_ecs.sh S0 $core_count 16 0"
#./workload_ecs.sh S0 $core_count 48 0
./workload_ecs_no_hwdrc.sh S0 $core_count 48 0
done

