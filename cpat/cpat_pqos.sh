source osmailbox_config.inc.sh

hp_cores=$1
lp_cores=$2

echo "cpat_pqos.sh: hp:$hp_cores lp:$lp_cores"

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

pqos_setup()
{
pqos -R
pqos -a core:4=0-10,120-130
pqos -a core:5=11-25,131-145
pqos -a core:6=26-40,146-160
pqos -a core:7=41-59,161-179
##pqos -a core:7=120-179
}

pqos_setup_all_ht_in_lp()
{
pqos -R
pqos -a core:4=0-10
pqos -a core:5=11-25
pqos -a core:6=26-40
pqos -a core:7=41-59
#pqos -a core:7=120-179
}


pqos_setup_all_c_in_lp()
{
pqos -R

pqos -a core:4=0-29
pqos -a core:7=30-59
pqos -a core:7=120-179

: '
pqos -a core:4=0-$((hp_cores - 1))
pqos -a core:7=120-$((hp_cores + 119 ))
pqos -a core:7=$hp_cores-$((hp_cores + lp_cores -1)),$((hp_cores + 120))-$((2*hp_cores +119))

echo "0-$((hp_cores - 1)),120-$((hp_cores + 119 ))"
echo "$hp_cores-$((hp_cores + lp_cores -1)),$((hp_cores + 120))-$((2*hp_cores +119))"
'
}

get_pid() {
    local pattern="$1"
    local pid=$(pgrep -f "$pattern")

    if [ -z "$pid" ]; then
        echo ""  # Return an empty string if no process is found
    else
        echo "$pid"  # Return the found PID(s)
    fi
}


echo "cpat init"
cpat_init

#cpat_disable

echo "dump cpat."
dump_cpat

#pqos_setup
#pqos_setup_all_ht_in_lp
#pqos_setup_all_c_in_lp
echo "pqos setup done."
#cd /home/speccpu/CPU2017/specCPU

#numactl --interleave=all runcpu --nobuild --action validate  --define cores=30     --define default-platform-flags --define numcopies=30 --copies=30  -c ic18.0-lin-core-avx2-rate-20170901.cfg --define invoke_with_interleave     --define drop_caches --tune base --noreportable -n 1 -o all perlbench_r &


#speccpu_pid=$!
#mlc --loaded_latency -R -d0 -T -b512M -t255 -k30-59 &
#mlc_pid=$!

#pqos -R
#pqos -a "pid:4=$speccpu_pid"
#pqos -a "pid:7=$mlc_pid"


