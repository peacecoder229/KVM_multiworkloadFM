result_file=$1

cd spdk_exp_dir
bash do_run_spdk-rdma.sh 2> $result_file
