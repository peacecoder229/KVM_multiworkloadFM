summary_file_name="/root/nutanix_data/Summary_hp-redis-mlc_lp-stressapp-rn50_$(date +%Y-%m-%d_%H-%M-%S)"

echo "HPWORKLOAD, HPCORE_RANGE, HPSCORE, LPWORKLOAD, LPCORE_RANGE, LPSCORE, QoS" > $summary_file_name

for hp_wl in "memcache" "rn50"; do
  for lp_wl in "rn50"; do
    ./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name
  done
done
