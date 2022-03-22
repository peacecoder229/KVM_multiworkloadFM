

echo "please dump the hwdrc pcode vars-after power on"
read myinput

./hwdrc_icx_2S_xcc_init_to_default_pqos.sh 


echo "please dump the hwdrc pcode vars-after hwdrc enable"
read myinput

#for upgrade_microcode in '8df001b0' '8df101b0' '8df201b0' '8df301b0' '8df401b0' '8df501b0' '8df601b0' '8df701b0' '8df801b0' '8df901b0'
for upgrade_microcode in '8df00280' '8df10280' '8df20280' '8df30280' '8df40280' '8df50280' '8df60280' '8df70280' '8df80280' '8df90280'
do
#stress the os patch load. without hwdrc reenable
echo $upgrade_microcode
cat /proc/cpuinfo |grep micro|tail -1

./workload.sh S0 
#if leave backgroud running lp there, the lp will impact the next lp workload!


iucode_tool -K/lib/firmware/intel-ucode  /home/longcui/icx_microcode/20210413_8d520280_21ww14a_PV_rc2_kp_0x8_ki_0x10/${upgrade_microcode}_patch_default_server_bios.pdb --overwrite

echo "please prepare dump the hwdrc pcode vars-after os patch load,#echo 1 > /sys/devices/system/cpu/microcode/reload"
read myinput

./workload.sh S0 
#sleep 1
#we must not disable/re-enable during the test, because that will fix any problems a patch load could have caused
#echo 1 > /sys/devices/system/cpu/microcode/reload
cat /proc/cpuinfo |grep micro|tail -1
done
