## Set-up HWDRC
1. Goto the mahine's remote desktop (using VNC or Remote Desktop) and do the following:
```	
startspr
itp.unlock()
```	
2. Copy ``` /home/longcui/ ``` directory from GDC3200-28T090T.
3. Assuming you copied the directory in ``` /home ```, you do the following:
```
cd /home/longcui/microcode_spr/20220303_fe8731f0_RPQ_CAS_maxmemBW_percentage_v2
cp ./patch_default_server_bios.pdb /lib/firmware/intel-ucode/06-8f-04
echo 1 > /sys/devices/system/cpu/microcode/reload
grep micro /proc/cpuinfo |tail 
 # Ouput of the command should be same as the following
 microcode       : 0xfe8731f0
  microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
 microcode       : 0xfe8731f0
```	

## Do the smoke test:
1. mlc is used for the test, if you don't have mlc download it from <https://www.intel.com/content/www/us/en/download/736633/763324/intel-memory-latency-checker-intel-mlc.html>.
2. ``` cd /home/muktadir/nutanix_vm_wl/hwdrc_postsi/scripts ```
3. Assign CAS value 16: ``` ./hwdrc_icx_2S_xcc_init_to_default_pqos_CAS.sh 16 ```
4. Open workload.sh script in nutanix_vm_wl/hwdrc_postsi/scripts and change HP, LP cores according to your Scoket 0's core config. 
5. Run the script: ./workload.sh S0.
6. HP cores should have higher memory bandwidth than that of LP cores.
