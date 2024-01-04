
#wl="speccpu:511.povray_r:1"
#wl_perf="511.povray_r"
: '
wl_1="speccpu:502.gcc_r:1"
wl_2="speccpu:502.gcc_r:1"
wl_perf_1="502.gcc_r"
wl_perf_2="502.gcc_r"
'

wl_1="mlc"
wl_2="mlc"
wl_perf_1="mlc"
wl_perf_2="mlc"

no_of_cores_1=48
no_of_cores_2=48
core_range_1="0-47"
core_range_2="96-143"
root_dir="/home/muktadir/nutanix_data"
parent_dir="hostexp_l2c_${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}"

echo "***default***"
cat $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-default/${wl_perf_1}_${core_range_1}_co_na_sst-0
cat $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-default/${wl_perf_2}_${core_range_2}_co_na_sst-0
python extract_thread.py $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-default/emon.xlsx

for cacheways in "0x1-0xfffe" "0x3-0xfffc" "0xf-0xfff0" "0xff-0xff00" "0xfffe-0x1"; do
  echo "***$cacheways***"
  cat $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-$cacheways/${wl_perf_1}_${core_range_1}_co_na_sst-0_l2c-${cacheways}
  cat $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-$cacheways/${wl_perf_2}_${core_range_2}_co_na_sst-0_l2c-${cacheways}
  echo "python extract_thread.py $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-$cacheways/emon.xlsx"
  python extract_thread.py $root_dir/$parent_dir/${wl_1}-${wl_2}_${no_of_cores_1}-${no_of_cores_2}_l2c-$cacheways/emon.xlsx
done

