#!/bin/bash

set -xe

#export XREKI_IMAGE_NAME=paddlepaddle/paddle
#export XREKI_IMAGE_TAG=latest-gpu-cuda9.0-cudnn7-dev
#export DOCKER_SUFFIX=_dev_cuda90

cuda_version=10.1
if [ ${cuda_version} == "10.1" ]; then
  #export XREKI_IMAGE_NAME=paddlepaddle/paddle_manylinux_devel
  #export XREKI_IMAGE_TAG=cuda${cuda_version}-cudnn7
  export XREKI_IMAGE_NAME=paddlepaddle/paddle
  export XREKI_IMAGE_TAG=latest-dev-cuda${cuda_version}-cudnn7-gcc82
elif [ ${cuda_version} == "11.0" ]; then
  export XREKI_IMAGE_NAME=tianshuo78520a/paddle_manylinux_devel
  export XREKI_IMAGE_TAG=cuda${cuda_version}-cudnn8
fi

export DOCKER_SUFFIX=_dev_cuda${cuda_version}

WORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")/../.." && pwd )"

nvidia-docker run --name build_paddle_lyq${DOCKER_SUFFIX} --network=host -it --rm \
    --shm-size 16G --cap-add SYS_ADMIN \
    -v $WORK_ROOT:/work \
    -v /ssd3/datasets:/data \
    -w /work \
    $XREKI_IMAGE_NAME:$XREKI_IMAGE_TAG \
    bash

