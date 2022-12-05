#!/bin/bash

result_file=$1

cd nginx_exp_dir

start=`date +%s`
./run_nginx.sh > /root/$result_file
end=`date +%s`
runtime=$((end-start))
echo "runtime = $runtime" >> /root/$result_file
