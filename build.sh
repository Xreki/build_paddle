#!/bin/bash

set -xe

WITH_GPU=ON
WITH_TESTING=ON

PROJ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
SOURCES_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." && pwd )"

function parse_version() {
  PADDLE_GITHUB_REPO=https://github.com/PaddlePaddle/Paddle.git
  git ls-remote --tags --refs ${PADDLE_GITHUB_REPO} > all_tags.txt
  latest_tag=`sed 's/refs\/tags\/v//g' all_tags.txt | awk 'END { print $NF }'`
  export PADDLE_VERSION=${latest_tag}
}

export OMP_NUM_THREADS=1
export no_proxy=bcebos.com

function cmake_gen() {
  export CC=gcc
  export CXX=g++
  source $PROJ_ROOT/clear.sh
  cd $BUILD_ROOT
  if [ ${OSNAME} != "CentOS" ];
  then
    # export CUDNN_ROOT=/work/packages/cudnn-v8.0.4
    cmake -DCMAKE_INSTALL_PREFIX=$DEST_ROOT \
          -DTHIRD_PARTY_PATH=$THIRD_PARTY_PATH \
          -DCMAKE_BUILD_TYPE=Release \
          -DWITH_GPU=${WITH_GPU} \
          -DCUDA_ARCH_NAME=Auto \
          -DWITH_CUDNN_FRONTEND=OFF \
          -DWITH_CINN=${WITH_CINN} \
          -DON_INFER=OFF \
          -DWITH_DISTRIBUTE=ON \
          -DWITH_MPI=OFF \
          -DWITH_DGC=ON \
          -DWITH_MKL=ON \
          -DWITH_AVX=ON \
          -DWITH_TESTING=ON \
          -DWITH_INFERENCE_API_TEST=ON \
          -DWITH_PYTHON=ON \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DPY_VERSION=${PY_VERSION} \
          $SOURCES_ROOT
  else
    if [ "$PYTHON_ABI" == "cp37-cp37m" ]; then
      PYTHON_EXECUTABLE=/opt/python/${PYTHON_ABI}/bin/python3.7
      PYTHON_INCLUDE_DIR=/opt/python/${PYTHON_ABI}/include/python3.7m
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython3.so
      pip3.7 uninstall -y protobuf
      pip3.7 install -r ${SOURCES_ROOT}/python/requirements.txt
    else
      echo "Python${PY_VERSION} is not supported!"
      exit
    fi

    cmake -DCMAKE_INSTALL_PREFIX=$DEST_ROOT \
          -DTHIRD_PARTY_PATH=$THIRD_PARTY_PATH \
          -DCMAKE_BUILD_TYPE=Release \
          -DWITH_GPU=${WITH_GPU} \
          -DCUDA_ARCH_NAME=Auto \
          -DON_INFER=OFF \
          -DWITH_DISTRIBUTE=ON \
          -DWITH_DGC=OFF \
          -DWITH_CRYPTO=ON \
          -DWITH_MKL=OFF \
          -DWITH_AVX=ON \
          -DWITH_TESTING=ON \
          -DWITH_INFERENCE_API_TEST=ON \
          -DWITH_PYTHON=ON \
          -DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE} \
          -DPYTHON_INCLUDE_DIR=${PYTHON_INCLUDE_DIR} \
          -DPYTHON_LIBRARIES=${PYTHON_LIBRARIES} \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DCMAKE_VERBOSE_MAKEFILE=OFF \
          -DPY_VERSION=${PY_VERSION} \
          $SOURCES_ROOT
  fi
  cd $PROJ_ROOT
}

function build() {
  cd $BUILD_ROOT
  cat <<EOF
  ============================================
  Building in $BUILD_ROOT
  ============================================
EOF
  make -j12
  cd $PROJ_ROOT
}

function inference_lib() {
  cd $BUILD_ROOT
  cat <<EOF
  ============================================
  Copy inference libraries to $DEST_ROOT
  ============================================
EOF
  make inference_lib_dist -j12
  cd ${PROJ_ROOT}
}

function run_unittest() {
  export CUDA_VISIBLE_DEVICES="2"
  export PYTHONPATH=${BUILD_ROOT}/python:${PYTHONPATH}
  export FLAGS_fraction_of_gpu_memory_to_use=0.8
  #export FLAGS_benchmark=1

  cd $BUILD_ROOT
  #export GLOG_vmodule=conv_cudnn_helper=4
  #export GLOG_v=4
  #UNIT_TEST_NAME=test_parallel_executor_run_cinn
  UNIT_TEST_NAME=test_nan_inf
  ctest -V -R ${UNIT_TEST_NAME}
  #python3.9 ${BUILD_ROOT}/python/paddle/fluid/tests/unittests/check_nan_inf_base.py
  MY_PYTHON_BIN=`which python${PY_VERSION}`
  UNIT_TEST_SCRIPT=`find -name ${UNIT_TEST_NAME}.py` 
  #${MY_PYTHON_BIN} -u ${UNIT_TEST_SCRIPT}
  
#  export GLOG_vmodule=cinn_launch_op=4
#  export GLOG_vmodule=build_cinn_pass=4
#  export GLOG_vmodule=graph_compiler=4
  #export FLAGS_allow_cinn_ops="batch_norm;batch_norm_grad;elementwise_add;elementwise_add_grad;relu;relu_grad"
  #export GLOG_vmodule=fetch_feed=4,cuda_util=4
#  export FLAGS_allow_cinn_ops="conv2d;conv2d_grad;batch_norm;batch_norm_grad;elementwise_add;elementwise_add_grad;relu;relu_grad;sum"
  #python ${BUILD_ROOT}/python/paddle/fluid/tests/unittests/test_resnet50_with_cinn.py
}

function main() {
  local CMD=$1
  source $PROJ_ROOT/env.sh
  git config --global http.sslverify false
  set_python_env

  CINN_INSTALL_PATH=${THIRD_PARTY_PATH}/CINN/src/external_cinn-build
  #CINN_INSTALL_PATH=/work/CINN/build_cinn/build_cuda11.2
  export runtime_include_dir=${CINN_INSTALL_PATH}/dist/cinn/include/cinn/runtime/cuda
  export LD_LIBRARY_PATH=${CINN_INSTALL_PATH}/dist/cinn/lib:${LD_LIBRARY_PATH}
  case $CMD in
    cmake)
#      parse_version
      cmake_gen
      ;;
    build)
#      parse_version
      build
      ;;
    inference_lib)
      inference_lib
      ;;
    ut)
      run_unittest
      ;;
    version)
      parse_version
      ;;
  esac
}

main $@
