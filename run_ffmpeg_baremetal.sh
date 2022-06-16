# Author: Rohan Tabish
# Organization: Intel Corporation
# Description: This script runs ffmpeg. Always launch as multiple of 8 cores

result_file=$1

rm -rf *.log
rm -rf *.csv
rm -rf uhd*.mp4

total_cores=$(getconf _NPROCESSORS_ONLN)
instances=$((total_cores/8))
echo "instances: $instances"
start=0
for ((i=1; i <=$instances;i++)); do
  export FFREPORT=file=/root/ffmpeg_$(date +%Y%m%s)_${i}.log
  taskset -c $start-$((start+8-1)) ffmpeg -i uhd1.webm -preset ultrafast -c:v libx264 -b:v 100M -bufsize 200M -maxrate 200M -threads 32 -g 120 -tune psnr -report uhd_$start.mp4 2> cores_${start}_ffmpeg.out &
  
  echo "taskset -c $start-$((start+8-1)) ffmpeg -i uhd1.webm -preset ultrafast -c:v libx264 -b:v 100M -bufsize 200M -maxrate 200M -threads 32 -g 120 -tune psnr -report uhd_$start.mp4 2> cores_${start}_ffmpeg.out &"
  start=$((start+8))
done

# waiting for the jobs to finish before we copy results back
for job in `jobs -p`
do
 echo "Waiting for $job to finish ...."
 wait $job
done

# process data after run
start=0
total_avg=0.0
for log in ffmpeg_*.log; do
  grep " fps=" $log | cut -d"=" -f3 | awk '{print $1}' > temp_$start.out
  avg=$(cat temp_${start}.out | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }')
  total_avg=$(awk "BEGIN{ print $avg + $total_avg}")

  start=$((start+8))
done

echo "$total_avg" > $result_file

python3 client.py $result_file
