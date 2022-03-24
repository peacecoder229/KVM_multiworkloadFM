for hp_wl in "redis" "memcache" "rn50" "mlc"; do
  for lp_wl in "stressapp" "rn50" "mlc"; do
    ./nutanix_testcases.sh $hp_wl $lp_wl
  done
done
