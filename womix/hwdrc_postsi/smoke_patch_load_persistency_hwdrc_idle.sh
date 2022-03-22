

echo "please dump the hwdrc pcode vars-after power on"
#read myinput

./hwdrc_icx_2S_xcc_init_to_default_pqos.sh 


echo "please dump the hwdrc pcode vars-after hwdrc enable"
#read myinput

for upgrade_microcode in '8df00280' '8df10280' '8df20280' '8df30280' '8df40280' '8df50280' '8df60280' '8df70280' '8df80280' '8df90280'
do
#stress the os patch load. without hwdrc reenable
echo $upgrade_microcode
cat /proc/cpuinfo |grep micro|tail -1

./workload.sh S0 
#if leave backgroud running lp there, the lp will impact the next lp workload!

#we must not disable/re-enable during the test, because that will fix any problems a patch load could have caused
iucode_tool -K/lib/firmware/intel-ucode  /home/longcui/icx_microcode/20210424_8d550280_21ww14a_PV_rc5/${upgrade_microcode}_patch_default_server_bios.pdb --overwrite
echo 1 > /sys/devices/system/cpu/microcode/reload
cat /proc/cpuinfo |grep micro|tail -1
./workload.sh S0

echo "please dump the hwdrc pcode vars-after os patch load"
#read myinput
done
