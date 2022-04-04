summary_file_name="/root/nutanix_data/Summary_hp-rn50_lp-rn50_HWDRC_$(date +%Y-%m-%d_%H-%M-%S)"

echo "HPWORKLOAD, HPCORE_RANGE, HPSCORE, LPWORKLOAD, LPCORE_RANGE, LPSCORE, QoS, QoS value" > $summary_file_name

#./nutanix_testcases.sh "rn50" "rn50" $summary_file_name 0 0

# For HWDRC Sweep; MBA is 10; You can comment out MBA for this
for hwdrc_val in {16..256..4} # sweep with an increment of 4
do
  for hp_wl in "rn50"; do
    for lp_wl in "rn50"; do
      ./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name $hwdrc_val 10
    done
  done
done

:'
# For MBA Sweep; HWDRC = 10; You can comment out the HWDRC function for this
for mba_val in {20..100..10} # sweep with an increment of 10
do
  for hp_wl in "rn50"; do
    for lp_wl in "rn50"; do
      ./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name 16 $mba_val
    done
  done
done
'
