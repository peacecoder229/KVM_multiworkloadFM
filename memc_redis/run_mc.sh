#!/bin/bash

		#core=$(( cc*1 ))
		cc=$(getconf _NPROCESSORS_ONLN)
		servcore=$(( cc/2 ))
		phi=$(( servcore-1 ))
		./mc_rds_in_vm.sh 0-${phi} memcache_result 2 16 "memcache_text" $servcore

