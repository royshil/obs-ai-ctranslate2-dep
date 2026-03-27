#!/bin/bash
set -euo pipefail

CONFIG=${1?}
PKG_VERSION=${2?}
VERSION="0.2.1"

if [ ! -d "sentencepiece-$VERSION" ]; then
  # Clone sentencepiece repo.
  git clone https://github.com/google/sentencepiece.git "sentencepiece-$VERSION"
  cd "sentencepiece-$VERSION"
  git checkout v$VERSION
  git submodule update --init --recursive
  cd ..
fi

cd sentencepiece-$VERSION

function build_for_arch() {
  ARCH=$1
  echo "Building for ${ARCH}"
  cmake . -B build_${ARCH}_${CONFIG} \
    -DSPM_ENABLE_SHARED=OFF \
    -DCMAKE_BUILD_TYPE=${CONFIG}

  cmake --build build_${ARCH}_${CONFIG} --config ${CONFIG} --parallel
  cmake --install build_${ARCH}_${CONFIG} --config ${CONFIG} --prefix ../dist/${ARCH}/${CONFIG}
}

mkdir -p ../dist

build_for_arch x86_64
# build_for_arch arm64

tar -C ../dist/${ARCH}/${CONFIG} -cvf ../dist/libsentencepiece-linux-${ARCH}-${CONFIG}-${PKG_VERSION}.tar.gz .
