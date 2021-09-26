#!/bin/bash

set -xe

export PROJ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
. ${PROJ_ROOT}/env.sh

#export FLAGS_fraction_of_gpu_memory_to_use=0.1
#export GLOG_v=4
unset CUDA_VISIBLE_DEVICES
export CUDA_VISIBLE_DEVICES=1

OP_TYPE=bilinear_interp_v2_grad
FILENAME=${SOURCES_ROOT}/paddle/fluid/operators/benchmark/configs/${OP_TYPE}.config
${BUILD_ROOT}/paddle/fluid/operators/benchmark/op_tester \
    --op_config_list=${FILENAME} \
    --specified_config_id=0
