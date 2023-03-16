result_file=$1

runtime=1000
#mlc --loaded_latency -R -t600 -d0 -k1-$[$(getconf _NPROCESSORS_ONLN)-1] > ${result_file}_temp
#time mlc --loaded_latency -W6 -t1200 -d0 -k1-$[$(getconf _NPROCESSORS_ONLN)-1] > ${result_file}_temp

# -W6 is 6  - 0:1 read-Non Temporal Write ratio. Non-temporal in this context means the data will not be reused soon, so there is no reason to cache it. These non-temporal write operations do not read a cache line and then modify it; instead, the new content is directly written to memory. 
time mlc --loaded_latency -W3 -t${runtime} -d0 -k1-$[$(getconf _NPROCESSORS_ONLN)-1] -b512000 > ${result_file}_temp

lat=$(cat ${result_file}_temp | grep 00000 | awk '{print $2}')
bw=$(cat ${result_file}_temp | grep 00000 | awk '{print $3}')
echo "Latency(ns), Bandwidth(MB/s), Runtime" > $result_file
echo "$lat, $bw, $runtime" >> $result_file

rm -f ${result_file}_temp

#python3 client.py $result_file
