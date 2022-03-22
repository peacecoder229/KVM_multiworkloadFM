
#for core_count in {48,32,16,8,4,2}; do

<<COMMENTS
echo "MBA======HP 48,LP changed 2-16"

for core_count in $(seq 2 2 16); do
echo "./workload_ecs.sh S0 48 $core_count 0"
#./workload_ecs.sh S0 48 $core_count 0
./workload_ecs_mba.sh S0 48 $core_count 0
#./workload_ecs_no_hwdrc.sh S0 48 $core_count 0
done

echo "MBA======HP changed 2-48,LP fixed at 16"

for core_count in $(seq 2 2 48); do
echo "./workload_ecs.sh S0 $core_count 16 0"
#./workload_ecs.sh S0 $core_count 16 0
./workload_ecs_mba.sh S0 $core_count 16 0
#./workload_ecs_no_hwdrc.sh S0 $core_count 16 0
done
COMMENTS

echo "DRC======HP 48,LP changed 2-16"

for core_count in $(seq 2 2 16); do
echo "./workload_ecs.sh S0 48 $core_count 0"
./workload_ecs.sh S0 48 $core_count 0
#./workload_ecs_mba.sh S0 48 $core_count 0
#./workload_ecs_no_hwdrc.sh S0 48 $core_count 0
done

echo "DRC======HP changed 2-48,LP fixed at 16"

for core_count in $(seq 2 2 48); do
echo "./workload_ecs.sh S0 $core_count 16 0"
./workload_ecs.sh S0 $core_count 16 0
#./workload_ecs_mba.sh S0 $core_count 16 0
#./workload_ecs_no_hwdrc.sh S0 $core_count 16 0
done
