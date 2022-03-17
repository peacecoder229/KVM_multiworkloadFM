#!/bin/bash

for ins in  "2"
#ins=1
#for cc in "8" "10" "12" "16" "18" "20" "24" "26" "28" "32" "36"
do
	for con in "16"
	do
		#core=$(( cc*1 ))
		core=$(( ins*9 ))
		phi=$(( core-1 ))
		./mc_rds_sweep.sh 0-${phi} SPR_Memcache $ins $con "memcache_text"
		#./mc_rds_sweep.sh 0-${phi} SPR_Memcache 1 $con "redis"
	done
done

