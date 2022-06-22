#/bin/bash
total_cores=$1
instances=$((total_cores/4))
modeldir=/rocknvme1/dataset/tensorflow

start=$2


for ((i=1; i <=$instances;i++)); do
  numactl --physcpubind=$start-$((start+4-1)) -m 0 python /home/workspace/benchmark/3d_unet_mlperf/models/benchmarks/launch_benchmark.py --benchmark-only --model-name 3d_unet_mlperf  --framework tensorflow  --mode inference  --precision bfloat16 --batch-size 1 --num-intra-threads=4 --num-inter-threads=1 --verbose  --in-graph /home/workspace/pbfiles/3DUNet/bfloat16/3dunet_dynamic_ndhwc.pb -- warmup_steps=7 steps=15 --data-num-intra-threads=4 --data-num-inter-threads=1 &> $modeldir/log/test_$start-$((start+4-1)).log &
  pids[$start]=$!
  start=$((start+4))
done

# waiting for the jobs to finish before we copy results back
for pid in ${pids[*]};do
  echo "waiting on pid $pid"
  wait $pid
done

echo "All tasks completed"
