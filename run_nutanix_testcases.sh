

summary_file_name="/root/nutanix_data/Summary_hp-redis-mlc_lp-stressapp-rn50_$(date +%Y-%m-%d_%H-%M-%S)"

echo "HPWORKLOAD, HPCORE_RANGE, HPSCORE, LPWORKLOAD, LPCORE_RANGE, LPSCORE, QoS" > $summary_file_name

# For HWDRC Sweep; MBA is 10; You can comment out MBA for this
for hwdrc_val in {16..256..4} # sweep with an increment of 4
do
	for hp_wl in "rn50"; do
		for lp_wl in "rn50"; do
    			./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name $hwdrc_val 10
  		done
	done
done

# For MBA Sweep; HWDRC = 10; You can comment out the HWDRC function for this 

for mba_val in {10..100..10} # sweep with an increment of 4
do
	for hp_wl in "rn50"; do
		for lp_wl in "rn50"; do
    			./nutanix_testcases.sh $hp_wl $lp_wl $summary_file_name 16 $mba_val
  		done
	done
done



