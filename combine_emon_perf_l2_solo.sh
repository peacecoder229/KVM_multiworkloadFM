
#wl="speccpu:511.povray_r:1"
#wl_perf="511.povray_r"
#wl="speccpu:502.gcc_r:1"
#wl_perf="502.gcc_r"

#wl="mlc"
#wl_perf="mlc"
#parent_dir="hostexp_l2c_${wl}_1_256kb-w5"

wl="nginx"
wl_perf="nginx"

no_of_cores=48
core_range="96-143"
root_dir="/home/muktadir/nutanix_data"
parent_dir="hostexp_l2c_${wl}_${no_of_cores}_1"

echo "Default"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-default/${wl_perf}_${core_range}_co_na_sst-0
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-default/emon.xlsx

echo "0x1"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0x1/${wl_perf}_${core_range}_co_na_sst-0_l2c-0x1
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0x1/emon.xlsx

echo "0x3"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0x3/${wl_perf}_${core_range}_co_na_sst-0_l2c-0x3
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0x3/emon.xlsx

echo "0xf"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xf/${wl_perf}_${core_range}_co_na_sst-0_l2c-0xf
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xf/emon.xlsx

echo "0xff"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xff/${wl_perf}_${core_range}_co_na_sst-0_l2c-0xff
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xff/emon.xlsx

echo "0xfff"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xfff/${wl_perf}_${core_range}_co_na_sst-0_l2c-0xfff
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xfff/emon.xlsx


echo "0xffff"
cat $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xffff/${wl_perf}_${core_range}_co_na_sst-0_l2c-0xffff
python extract_core_number.py $root_dir/$parent_dir/${wl}_${no_of_cores}_l2c-0xffff/emon.xlsx


