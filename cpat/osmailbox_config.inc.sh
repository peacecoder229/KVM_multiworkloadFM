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

mailbox_write(){
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

mailbox_read(){
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

cpat_disable()
{
mailbox_write 0x800003ca 0x0
}

cpat_enable(){

mailbox_write 0x810054d0 0x2
echo "MEMCLOS_EN=0x2"

}

dump_cpat()
{
mailbox_read 0x800000ca
echo "CPAT_CAPABILITY="$g_ret_data

mailbox_read 0x800001ca
echo "CPAT_LEVELS="$g_ret_data

#mailbox_read 0x800002ca
#echo "CPAT_CLOStoPAT="$g_ret_data

#mailbox_read 0x800003ca
#echo "CPAT_CONTROL="$g_ret_data

#mailbox_read 0x800004ca
#echo "CPAT_CONFIG="$g_ret_data

#mailbox_read 0x800005ca
#echo "PWR_MGMT_CONTROL="$g_ret_data

}

