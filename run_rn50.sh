result_file=$1

xzcat  /root/rn50.img.xz |docker load
docker run --rm --name=rn50 -e OMP_NUM_THREADS=$(getconf _NPROCESSORS_ONLN) mxnet_benchmark 2>  ${result_file}_temp

img_per_sec=$(grep "images per second" ${result_file}_temp | awk '{print $3}')
echo "img/sec" > $result_file
echo "$img_per_sec" >> $result_file

rm -f ${result_file}_temp
