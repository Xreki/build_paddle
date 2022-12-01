#!/bin/bash

PATH=/usr/local/ssl:${GOROOT}/bin:${GOPATH}/bin:${PATH}
LIBRARY_PATH=/usr/local/ssl/lib:$LIBRARY_PATH

#### Set default sources root
if [ -z $PROJ_ROOT ]; then
  PROJ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
fi
if [ -z $SOURCES_ROOT ]; then
  SOURCES_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." && pwd )"
fi

#### Set suffix of build directory
PY_VERSION=3.9

NVCC=`which nvcc`
if [ ${NVCC} != "" ]; then
  NVCC_VERSION=`nvcc --version | tail -n 2 | grep "V[0-9][0-9]*\.[0-9]" -o | uniq`
  NVCC_VERSION=${NVCC_VERSION//V/}
  SUFFIX=${SUFFIX}"_cuda${NVCC_VERSION}"
fi
GCC_VERSION=`gcc --version | head -n 1 | grep "[0-9]\.[0-9]\.[0-9]" -o | uniq`
SUFFIX=${SUFFIX}"_gcc${GCC_VERSION}"
if [ "${PY_VERSION}" != "" ]; then
  SUFFIX=${SUFFIX}"_py${PY_VERSION}"
fi

if [ "${NVCC_VERSION}" = "11.2" ]; then
  WITH_CINN=ON
else
  WITH_CINN=OFF
fi
WITH_CINN=OFF

if [ "${WITH_CINN}" = "ON" ]; then
  SUFFIX=${SUFFIX}_cinn
fi

cd ${SOURCES_ROOT}
GIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
cd ${PROJ_ROOT}
echo "GIT_BRANCH: ${GIT_BRANCH}"
if [[ $GIT_BRANCH =~ "release/" ]]; then
  GIT_BRANCH=`echo $GIT_BRANCH | sed 's/release\//r/'`
  SUFFIX=${SUFFIX}"_$GIT_BRANCH"
fi

BUILD_ROOT=${PROJ_ROOT}/build$SUFFIX
DEST_ROOT=$PROJ_ROOT/dist$SUFFIX
THIRD_PARTY_PATH=$PROJ_ROOT/third_party$SUFFIX

echo "PROJ_ROOT: ${PROJ_ROOT}"
echo "SOURCES_ROOT: ${SOURCES_ROOT}"
echo "BUILD_ROOT: ${BUILD_ROOT}"
echo "THIRD_PARTY_PATH: ${THIRD_PARTY_PATH}"

OSNAME=`cat /etc/issue | head -n 1 | awk '{print $1}'`
if [ "${OSNAME}" != "CentOS" ] && [ "${OSNAME}" != "Ubuntu" ] && [ -f /etc/redhat-release ] ; then
  OSNAME=`cat /etc/redhat-release | awk '{print $1}'`
fi
echo "OSNAME: ${OSNAME}"

function set_python_env() {
  if [ "${OSNAME}" == "CentOS" ];
  then
    if  [ "${PY_VERSION}" == "3.7" ]; then
      export PYTHON_ABI="cp37-cp37m"
    else
      echo "Python${PY_VERSION} is not supported!"
      exit
    fi

    echo "using python abi: $1"
    export LD_LIBRARY_PATH=/opt/python/${PYTHON_ABI}/lib:${LD_LIBRARY_PATH}
    export PATH=/opt/python/${PYTHON_ABI}/bin/:${PATH}
  fi
}
