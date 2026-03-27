#!/bin/bash
set -euo pipefail

CONFIG=${1?}
ACCEL=${2?}
PKG_VERSION=${3?}

VERSION="4.7.1"

if [ ! -d "CTranslate2-$VERSION" ]; then
  # Clone CTranslate2 repo.
  git clone https://github.com/OpenNMT/CTranslate2.git "CTranslate2-$VERSION"
  cd "CTranslate2-$VERSION"
  git checkout v$VERSION
  git submodule update --init --recursive
  cd ..
fi

cd CTranslate2-$VERSION

extra_cxx_flags="-fPIC"

if [[ ${ACCEL} = "nvidia" ]]; then
  additional_args="-DWITH_CUDA=ON -DWITH_CUDNN=OFF -DWITH_TENSOR_PARALLEL=OFF -DWITH_HIP=OFF"
elif [[ ${ACCEL} = "amd" ]]; then
  additional_args="-DWITH_CUDA=OFF -DWITH_CUDNN=OFF -DWITH_TENSOR_PARALLEL=OFF -DWITH_HIP=ON -DCMAKE_C_COMPILER=hipcc -DCMAKE_CXX_COMPILER=hipcc"

  # GPU_TARGETS and CMAKE_HIP_ARCHITECTURES seems to be broken on Linux v.v
  readarray -d ";" -t gpu_targets <<< $AMD_GPU_TARGETS
  for target in "${gpu_targets[@]}"
  do
    extra_cxx_flags="${extra_cxx_flags} --offload-arch=${target}"
  done
else
  additional_args="-DWITH_CUDA=OFF -DWITH_CUDNN=OFF -DWITH_TENSOR_PARALLEL=OFF -DWITH_HIP=OFF"
fi

function build_for_arch() {
  ARCH=$1
  echo "Building for ${ARCH}"
  cmake . -B build_${ARCH}_${CONFIG}_${ACCEL} \
    -DCMAKE_GENERATOR="Unix Makefiles" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DOPENMP_RUNTIME=COMP \
    -DWITH_ACCELERATE=OFF \
    -DWITH_MKL=OFF \
    -DWITH_DNNL=OFF \
    -DWITH_OPENBLAS=ON \
    -DWITH_RUY=OFF \
    -DENABLE_CPU_DISPATCH=ON \
    -DENABLE_PROFILING=OFF \
    -DBUILD_CLI=OFF \
    -DBUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=${CONFIG} \
    -DCMAKE_CXX_FLAGS="-fPIC" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    ${additional_args}

  cmake --build build_${ARCH}_${CONFIG}_${ACCEL} --config ${CONFIG} --parallel
  mkdir -p ../dist/${ARCH}/${CONFIG}-${ACCEL}
  cmake --install build_${ARCH}_${CONFIG}_${ACCEL} --config ${CONFIG} --prefix ../dist/${ARCH}/${CONFIG}-${ACCEL}
}

build_for_arch x86_64
# build_for_arch arm64

if [ -d ../dist/${ARCH}/${CONFIG}/lib ]; then
  rm -rf ../dist/${ARCH}/${CONFIG}/lib
fi

tar -C ../dist/${ARCH}/${CONFIG}-${ACCEL} -cvf ../dist/libctranslate2-linux-${ARCH}-${CONFIG}-${ACCEL}-${PKG_VERSION}.tar.gz .
