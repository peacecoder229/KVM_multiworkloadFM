for hp_wl in "rn50" "redis" "memcache"; do
  for lp_wl in "rn50" "mlc"; do
    ./nutanix_testcases.sh $hp_wl $lp_wl
  done
done
