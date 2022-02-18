result_file=$1_$(getconf _NPROCESSORS_ONLN)
mlc --max_bandwidth > $result_file
