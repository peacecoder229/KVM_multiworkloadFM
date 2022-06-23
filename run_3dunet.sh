#!/bin/bash
#cd /home/unit-tests/sweep_cas_mlc/rnn_t


result_file=$1
rep=2 # no of times the model will run. 1 = 307, 2 = 615, 3 =  

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

start=`date +%s`
for ((i=1; i<=$rep; i++ )); do
  docker exec tf-spr-ww19-$total_cores /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"
  echo 'docker exec tf-spr-ww19-$total_cores /bin/bash -c "$modeldir/unet.sh $total_cores $startcore"'
done
echo "Execution Completed"

cd -
cd $modeldir/log


end=`date +%s`
runtime=$((end-start))

# process data after run
start=$startcore
total_avg=0.0
for log in *.log; do
  avg=$(grep "Throughput:" $log | awk '{print $2}')

  total_avg=$(awk "BEGIN{ print $avg + $total_avg}")

  start=$((start+4))
done

cd -

echo "Throughput, Runtime" > $result_file
echo "$total_avg, $runtime" >> $result_file
