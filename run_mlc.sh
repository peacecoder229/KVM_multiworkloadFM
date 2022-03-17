ip="10.219.66.160"
#scp -oStrictHostKeyChecking=no root@${ip}:/usr/local/bin/mlc /usr/local/bin/

result_file=$1_$(getconf _NPROCESSORS_ONLN)
mlc --loaded_latency -R -t300 -d0 -k1-$[$(getconf _NPROCESSORS_ONLN)-1] > $result_file
