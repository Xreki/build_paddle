#!/bin/bash

set -xe

export PROJ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
. ${PROJ_ROOT}/env.sh

set_python_env
export PYTHONPATH=${BUILD_ROOT}/python:${PYTHONPATH}

export FLAGS_fraction_of_gpu_memory_to_use=0.1
unset CUDA_VISIBLE_DEVICES
export CUDA_VISIBLE_DEVICES="2"
#export FLAGS_benchmark=1

cd $BUILD_ROOT
#export GLOG_vmodule=fusion_group_pass=4
#export GLOG_vmodule=operator=4
#export GLOG_v=4
UNIT_TEST_NAME=test_svd_op
ctest -V -R ${UNIT_TEST_NAME}
