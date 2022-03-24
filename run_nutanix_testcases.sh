summary_file_name="/root/nutanix_data/Summary_${HPWORKLOAD}_${LPWORKLOAD}_$(date +%Y-%m-%d_%H-%M-%S)"

for hp_wl in "redis" "memcache" "rn50" "mlc"; do
  for lp_wl in "stressapp" "rn50" "mlc"; do
    ./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name
  done
done
