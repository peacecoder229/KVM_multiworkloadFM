# Turn on the flag to run the exp in host; turn it off to run the exp in VM
HOST_EXP=1

# Number of cpus for different VMs according to their priority
VM_CORES="5,3,3"

# Name of workloads to be run on the VMs accroding to their priority
VM_WORKLOADS=rn50,mlc,redis

# Configuration file for launching the VMs
VM_CONFIG="sample_vm_config.yaml"

# enable/disable monitoring technology (CMT and MBM)
MONITORING=0 # 1:enable; 0:disable TODO: Need to fix

# CoS MBA parameters
MBA_ENABLE=0 # on=1, off=0
MBA_COS_WL="0,3,3"
MBA_COS_VAL="0=100,3=20" # value for each COS

# HWDRC parameters
HWDRC_ENABLE=1 # on=1, off=0
HWDRC_CAS_VAL=16
HWDRC_COS_WL="4,7,7" # CoS association of each workload: Smaller the value, higher the priority

# CoS LLC ways parameters
LLC_CACHE_WAYS_ENABLE=1
LLC_COS_WL="1,2,2"
LLC_COS_WAYS="0x7fff,0x7fff,0x7fff"

# CoS L2C ways parameters
L2C_CACHE_WAYS_ENABLE=1
L2C_COS_WL="1,2,2"
L2C_COS_WAYS="0x7fff,0x7fff,0x7fff"


# SST CoS parameters
SST_ENABLE=1 # on=1, off=0
SST_COS_WL="0,3,3"
# CoS:MinFreqency-MaxFrequency; if MinFreqency=0 only MaxFrequency will be specified in SST command. 
# If MaxFrequency=0 only MinFreqency will be specified in the SST command
SST_COS_FREQ="0:3000-3100,3:0-500"

# Resctrl flag; if turned on uses resctrl interface rathher than pqos tool
RESCTRL=1 #
