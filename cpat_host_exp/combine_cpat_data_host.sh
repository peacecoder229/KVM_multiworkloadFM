#!/bin/bash
#gcc_55_default.out

hp="redis"
lp="gcc"

outfile="${hp}_${lp}_pqos_core_pinning.csv"

echo "HP-LP Core, HP Default Throughput, HP Default P99, LP Default, HP CPAT Throughput, HP CPAT P99 , LP CPAT" > $outfile

lp_core=30
while [ $lp_core -le 60 ]
do

  hp_default=$(tail -1 ${hp}_default_${lp_core})
  lp_default=$(cat ${lp}_default_${lp_core})
  hp_cpat=$(tail -1 ${hp}_cpat_${lp_core})
  lp_cpat=$(cat ${lp}_cpat_${lp_core})
  
  echo "30-$lp_core, $hp_default, $lp_default, $hp_cpat, $lp_cpat" >> $outfile

  lp_core=$((lp_core+5)) 
done
