# Number of cpus for different VMs according to their priority
VM_CORES="5,3,3"

# Name of workloads to be run on the VMs accroding to their priority
VM_WORKLOADS=rn50,mlc,redis

# CoS MBA parameters
MBA_COS_WL="0,3,3"
MBA_COS_VAL="0=100,3=20" # value for each COS

# HWDRC parameters
HWDRC_CAS_VAL=16

# COS HWDRC parameters
HWDRC_COS_WL="4,7,7" # CoS association of each workload: Smaller the value, higher the priority

# SST CoS parameters
SST_COS_WL="0,3,3"
SST_COS_FREQ="0:3000-3100,3:0-500" # CoS:MinFreqency-MaxFrequency
