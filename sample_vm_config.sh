# Number of VMs
NO_VMS=3

# Number of cpus for different VMs according to their priority
VM_CORES="5,3,3"

# Name of workloads to be run on the VMs accroding to their priority
VM_WORKLOADS="rn50,mlc,mlc"

# COS MBA parameters
MBA_COS_WL="0,3,3" # COS association of each workload
MBA_COS_VAL="0=100,3=20" # value for each COS

# HWDRC parameters
HWDRC_CAS_VAL=16

# COS LLC parameters
LLC_COS_WL="4,7,7"
