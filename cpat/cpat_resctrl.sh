source osmailbox_config.inc.sh

hp_cores=$1
lp_cores=$2

core_id=1

cpat_init()
{
mailbox_write 0x800003ca 0x0

#update the map
#all clos and clos4=CPAT0(HP), clos5=CPAT1, clos6=CPAT2, clos7=CPAT3 (LP)
mailbox_write 0x800002ca 0x0000E400


#update the config
#max min priority for each cpat, only max works? no min, it is the key during power contention!!!
#CPAT0
#mailbox_write 0x800004ca 0x00280800
mailbox_write 0x800004ca 0x00280800
#CPAT1
#mailbox_write 0x800004ca 0x00240841
mailbox_write 0x800004ca 0x00240841
#CPAT2
#mailbox_write 0x800004ca 0x00220882
mailbox_write 0x800004ca 0x00220882
#CPAT3
#mailbox_write 0x800004ca 0x002008c3
mailbox_write 0x800004ca 0x001e08c3


#active it in ordered mode
mailbox_write 0x800003ca 0x3


}


cpat_init

dump_cpat

