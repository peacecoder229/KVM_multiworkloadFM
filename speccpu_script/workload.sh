#!/usr/bin/env bash
#------------------------------------------------------------------------------
# INTEL CONFIDENTIAL
# Copyright 2021 Intel Corporation All Rights Reserved.
#
# The source code contained or described herein and all documents related to the
# source code ("Material") are owned by Intel Corporation or its suppliers or
# licensors. Title to the Material remains with Intel Corporation or its
# suppliers and licensors. The Material contains trade secrets and proprietary
# and confidential information of Intel or its suppliers and licensors. The
# Material is protected by worldwide copyright and trade secret laws and treaty
# provisions. No part of the Material may be used, copied, reproduced, modified,
# published, uploaded, posted, transmitted, distributed, or disclosed in any way
# without Intel's prior express written permission.
#
# No license under any patent, copyright, trade secret or other intellectual
# property right is granted to or conferred upon you by disclosure or delivery
# of the Materials, either expressly, by implication, inducement, estoppel or
# otherwise. Any license under such intellectual property rights must be express
# and approved by Intel in writing.
#------------------------------------------------------------------------------

# Select workload and config
workload=$1
copies=$2

# Config files
speed_cfg='ic19.1u1-lin-core-avx512-speed-20200306_revA.cfg'
rate_cfg='ic19.1u1-lin-core-avx512-rate-20200306_revA.cfg'

if [[ ${workload#*_}  == "s" ]]; then
    config=${speed_cfg}
else
    config=${rate_cfg}
fi

# source spec17 environment if needed
#hash runcpu || source shrc 
source shrc 

# Clear Cache again inside the docker
ulimit -s unlimited
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches

runcpu \
    -c ${config} \
    --nobuild \
    --noreportable \
    --define cores=${copies} \
    --threads=${copies} \
    --define numcopies=${copies} \
    --iterations 1 \
    ${workload} |  tee -a workload.log

sleep 1

