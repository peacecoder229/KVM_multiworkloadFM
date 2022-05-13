#!/bin/bash

# Author: Rohan Tabish
# Organization: Intel Corporation
# Email: rohan.tabish@intel.com
# Description: This script processes the data of turbostat to get per-core metrics. 
# It is tailored for the following example turbostat -s Core,CPU,Avg_MHz,Busy%,Bzy_MHz,TSC_MHz,CoreTmp,PkgTmp,PkgWatt -c 0-31 -n 2 > output.txt

rm -rf output_*
input=$1
COUNTER=0
CORES=$2
CORE_ENTRIES=0
START=$3
OFFSET=$((CORES + 2))


while IFS= read -r line
do
  let COUNTER++

done < "$input"

echo $COUNTER

CORE_ENTRIES=$(( COUNTER/CORES))

echo $CORE_ENTRIES
line='3!d'
# Outer Loop controls how many entries are there
for (( entry=$START; entry < $CORE_ENTRIES; entry++ ))
do
   for (( core=0; core < $CORES; core++ )) # Inner loop: Seperate for each core and write to a file
   do
        line=$((66+$core+$((entry*OFFSET))))!d
        #For machine 28T090T use this line: line=$((83+$core+$((entry*OFFSET))))!d
	#echo $line  // for debugging
	sed $line $input >> output_$((core+START))
   done
done


echo "Core Avg_Mhz Busy% Busy_MHz TSC_MHz CoreTmp PkgTMp" 
# Loop Below reads per core samples 
for (( core = 0 ; core < CORES; core++ ))
do
    
   Avg_MHz=$(cat output_$((core+START)) | awk '{ sum += $3; n++ } END { if (n > 0) print sum / n; }')	
   BusyPer=$(cat output_$((core+START)) | awk '{ sum += $4; n++ } END { if (n > 0) print sum / n; }')
 
   Busy_MHz=$(cat output_$((core+START)) | awk '{ sum += $5; n++ } END { if (n > 0) print sum / n; }')	
   TSC_MHz=$(cat output_$((core+START)) | awk '{ sum += $6; n++ } END { if (n > 0) print sum / n; }')
   
   CoreTmp=$(cat output_$((core+START)) | awk '{ sum += $7; n++ } END { if (n > 0) print sum / n; }')	
   PkgTmp=$(cat output_$((core+START)) | awk '{ sum += $8; n++ } END { if (n > 0) print sum / n; }')
   
   #echo "Core Avg_Mhz Busy% Busy_MHz TSC_MHz CoreTmp PkgTMp" 
   #echo $((core+START))  $Avg_MHz  $BusyPer  $Busy_MHz  $TSC_MHz  $CoreTmp  $PkgTmp # For printing to console
   echo $((core+START)) $Avg_MHz $BusyPer $Busy_MHz $TSC_MHz $CoreTmp $PkgTmp >> output_average_per_core.txt

done

Avg_MHz=$(cat output_average_per_core.txt | awk '{ sum += $2; n++ } END { if (n > 0) print sum / n; }')	
BusyPer=$(cat output_average_per_core.txt | awk '{ sum += $3; n++ } END { if (n > 0) print sum / n; }')
   
Busy_MHz=$(cat output_average_per_core.txt | awk '{ sum += $4; n++ } END { if (n > 0) print sum / n; }')	
TSC_MHz=$(cat output_average_per_core.txt | awk '{ sum += $5; n++ } END { if (n > 0) print sum / n; }')
   
CoreTmp=$(cat output_average_per_core.txt | awk '{ sum += $6; n++ } END { if (n > 0) print sum / n; }')	
PkgTmp=$(cat output_average_per_core.txt | awk '{ sum += $7; n++ } END { if (n > 0) print sum / n; }')

echo "Avg_MHz Busy% Busy_MHz TSC_MHz CoreTmp PkgTmp"
   
echo $Avg_MHz $BusyPer $Busy_MHz $TSC_MHz $CoreTmp $PkgTmp
