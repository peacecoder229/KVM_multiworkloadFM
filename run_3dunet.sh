#!/bin/bash
#cd /home/unit-tests/sweep_cas_mlc/rnn_t

result_file=$1
total_cores=$(getconf _NPROCESSORS_ONLN)
startcore=0

modeldir=/rocknvme1/dataset/tensorflow

cp -f unet_script/unet.sh $modeldir/

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
sleep 10

docker pull dcsorepo.jf.intel.com/dlboost/tensorflow/tf_wl_base:ww19-tf

docker run -itd --name tf-spr-ww19-$total_cores --privileged -v $modeldir:$modeldir  \
        -v /home/dl_boost/logs/tensorflow/:/home/dl_boost/logs/tensorflow/ \
  --shm-size=4g dcsorepo.jf.intel.com/dlboost/tensorflow/tf_wl_base:ww19-tf bash

sleep 10

echo "Executing 3DUNET_T"
sleep 1

docker exec tf-spr-ww19-$total_cores /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"
#docker exec tf-spr-ww19-$1 /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"
#docker exec tf-spr-ww19-$1 /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"
#docker exec tf-spr-ww19-$1 /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"

echo "Execution Completed"

cd -
cd $modeldir/log

# process data after run
start=$startcore
total_avg=0.0
for log in *.log; do
  avg=$(grep "Throughput:" $log | awk '{print $2}')

  total_avg=$(awk "BEGIN{ print $avg + $total_avg}")

  start=$((start+4))
done

cd -

echo "Throughput" > $result_file
echo "$total_avg" >> $result_file
