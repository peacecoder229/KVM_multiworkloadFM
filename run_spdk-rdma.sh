#!/bin/bash

result_file=$1

cd spdk_exp_dir
bash do_run_spdk-rdma.sh | tee /root/$result_file
cd -
