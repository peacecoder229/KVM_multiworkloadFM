ip="10.219.66.160"


result_file=$1_$(getconf _NPROCESSORS_ONLN)

xzcat  /root/rn50.img.xz |docker load


docker run --rm --name=rn50 -e OMP_NUM_THREADS=$(getconf _NPROCESSORS_ONLN) mxnet_benchmark 2>  $result_file

