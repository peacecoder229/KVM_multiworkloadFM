ip="10.219.66.160"
#scp -oStrictHostKeyChecking=no root@${ip}:/usr/local/bin/mlc /usr/local/bin/

result_file=$1_$(getconf _NPROCESSORS_ONLN)_mlc
mlc --loaded_latency -R -t300 -T -d0 > $result_file
