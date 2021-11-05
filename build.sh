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

export runtime_include_dir=${THIRD_PARTY_PATH}/CINN/src/external_cinn-build/dist/cinn/include/cinn/runtime/cuda

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
          -DCUDA_ARCH_NAME=Volta \
          -DWITH_CINN=ON \
          -DON_INFER=OFF \
          -DWITH_DISTRIBUTE=ON \
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
    if [ "$PYTHON_ABI" == "cp27-cp27m" ]; then
      PYTHON_EXECUTABLE=/opt/python/${PYTHON_ABI}/bin/python
      PYTHON_INCLUDE_DIR=/opt/python/${PYTHON_ABI}/include/python2.7
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython2.7.so
      pip uninstall -y protobuf
      pip install -r ${SOURCES_ROOT}/python/requirements.txt
    elif [ "$PYTHON_ABI" == "cp27-cp27mu" ]; then
      PYTHON_EXECUTABLE=/opt/python/cp27-cp27mu/bin/python
      PYTHON_INCLUDE_DIR=/opt/python/cp27-cp27mu/include/python2.7
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython2.7.so
      pip uninstall -y protobuf
      pip install -r ${SOURCES_ROOT}/python/requirements.txt
    elif [ "$PYTHON_ABI" == "cp35-cp35m" ]; then
      PYTHON_EXECUTABLE=/opt/python/${PYTHON_ABI}/bin/python3
      PYTHON_INCLUDE_DIR=/opt/python/${PYTHON_ABI}/include/python3.5m
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython3.so
      pip3.5 uninstall -y protobuf
      pip3.5 install -r ${SOURCES_ROOT}/python/requirements.txt
    elif [ "$PYTHON_ABI" == "cp36-cp36m" ]; then
      PYTHON_EXECUTABLE=/opt/python/${PYTHON_ABI}/bin/python3
      PYTHON_INCLUDE_DIR=/opt/python/${PYTHON_ABI}/include/python3.6m
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython3.so
      pip3.6 uninstall -y protobuf
      pip3.6 install -r ${SOURCES_ROOT}/python/requirements.txt
    elif [ "$PYTHON_ABI" == "cp37-cp37m" ]; then
      PYTHON_EXECUTABLE=/opt/python/${PYTHON_ABI}/bin/python3.7
      PYTHON_INCLUDE_DIR=/opt/python/${PYTHON_ABI}/include/python3.7m
      PYTHON_LIBRARIES=/opt/python/${PYTHON_ABI}/lib/libpython3.so
      pip3.7 uninstall -y protobuf
      pip3.7 install -r ${SOURCES_ROOT}/python/requirements.txt
    fi

    cmake -DCMAKE_INSTALL_PREFIX=$DEST_ROOT \
          -DTHIRD_PARTY_PATH=$THIRD_PARTY_PATH \
          -DCMAKE_BUILD_TYPE=Release \
          -DWITH_GPU=${WITH_GPU} \
          -DCUDA_ARCH_NAME=Volta \
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
  export FLAGS_fraction_of_gpu_memory_to_use=0.1
  #export FLAGS_benchmark=1

  cd $BUILD_ROOT
  #export GLOG_vmodule=fusion_group_pass=4
  export GLOG_vmodule=operator=4
  #export GLOG_vmodule=pass_builder=1
  #export GLOG_vmodule=build_strategy=1
  #export GLOG_v=4
  #UNIT_TEST_NAME=test_parallel_executor_run_cinn
  #ctest -V -R ${UNIT_TEST_NAME}
  
  export GLOG_vmodule=cinn_launch_op=4
  export GLOG_vmodule=graph_compiler=4
  export FLAGS_allow_cinn_ops="conv2d"
  python ${BUILD_ROOT}/python/paddle/fluid/tests/unittests/test_resnet50_with_cinn.py
}

function main() {
  local CMD=$1
  source $PROJ_ROOT/env.sh
  git config --global http.sslverify false
  set_python_env
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
