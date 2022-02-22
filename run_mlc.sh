ip="10.219.66.160"
#scp -oStrictHostKeyChecking=no root@${ip}:/usr/local/bin/mlc /usr/local/bin/

result_file=$1_$(getconf _NPROCESSORS_ONLN)
mlc --max_bandwidth > $result_file
