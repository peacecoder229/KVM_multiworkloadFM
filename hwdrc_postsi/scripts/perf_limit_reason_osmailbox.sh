#
g_ret_data=0
g_ret_interface=0

wait_until_run_busy_cleared(){
run_busy=1
while [[ $run_busy -ne 0 ]]
do 
  rd_interface=`rdmsr -p $core_id 0xb0`
  run_busy=$[rd_interface & 0x80000000]
  if [ $run_busy -eq 0 ]; then
    #not busy, just return
    break
  else
    echo "====warning:RUN_BUSY=1.sleep 1,then retry"
    sleep 1
  fi
done
}

hwdrc_write(){
#input 1: the value of OS Mailbox Interface for write operation
#input 2: the value of OS Mailbox Data
#return OSmailbox interface status in g_ret_interface
value_interface=$1
value_data=$2

wait_until_run_busy_cleared
wrmsr -p $core_id 0xb1 $value_data
#the value_interface should include the RUN_BUSY,and all other fileds including COMMANDID,sub-COMMNADID,MCLOS ID(for attribute)
wrmsr -p $core_id 0xb0 $value_interface

wait_until_run_busy_cleared
g_ret_interface=`rdmsr -p $core_id 0xb0`
}

hwdrc_read(){
#input: the value of OS Mailbox Interface for read operation
#retrun hwdrc reg read value in $g_ret_data
#return OSmailbox interface status in $g_ret_interface
value_interface=$1

wait_until_run_busy_cleared
wrmsr -p $core_id 0xb0 $value_interface

wait_until_run_busy_cleared

g_ret_interface=`rdmsr -p $core_id 0xb0`
#g_ret_data=`rdmsr -p $core_id 0xb1`
g_ret_data=`rdmsr -p $core_id 0xb1 --zero-pad`
g_ret_data=${g_ret_data:8:8}
}

hwdrc_read 0x800FF0b0
echo "high level read OSmailbox-800ff0b0,high level="$g_ret_data

echo "write high level bit to 1 to clear, hwdrc_write 0x800ff1b0 0xefffffff"
hwdrc_write 0x800ff1b0 0xefffffff
#hwdrc_write 0x800ff1b0 0x80010000

sleep 1

hwdrc_read 0x800FF0b0
echo "high level read OSmailbox-800ff0b0,high level="$g_ret_data

echo "fine level read from pcode"
for cpu in $(seq 0 63 );do

core_perf_limit=`printf "0x%08x\n" $((0x800002b0 + $cpu*4096))`
hwdrc_read $core_perf_limit
echo "OSmailbox-"$core_perf_limit",fine level="$g_ret_data
done


echo "fine level read from acode "
for cpu in $(seq 0 63 );do

core_perf_limit=`printf "0x%08x\n" $((0x800003b0 + $cpu*4096))`
hwdrc_read $core_perf_limit
echo "OSmailbox-"$core_perf_limit",fine level="$g_ret_data
done
