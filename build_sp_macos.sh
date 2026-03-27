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
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DSPM_ENABLE_SHARED=OFF \
    -DCMAKE_GENERATOR=Xcode \
    -DCMAKE_BUILD_TYPE=${CONFIG}

  cmake --build build_${ARCH}_${CONFIG} --config ${CONFIG} --parallel -- -arch ${ARCH} ONLY_ACTIVE_ARCH=YES
  mkdir -p dist/${ARCH}/${CONFIG}
  cmake --install build_${ARCH}_${CONFIG} --config ${CONFIG} --prefix dist/${ARCH}/${CONFIG}
}

build_for_arch x86_64
build_for_arch arm64

# Create universal binary.
mkdir -p dist/universal/${CONFIG}/lib
lipo -create dist/x86_64/${CONFIG}/lib/libsentencepiece.a dist/arm64/${CONFIG}/lib/libsentencepiece.a -output dist/universal/${CONFIG}/lib/libsentencepiece.a

# Copy headers.
cp -r dist/x86_64/${CONFIG}/include dist/universal/${CONFIG}/include

mkdir -p ../dist
tar -C dist/universal/${CONFIG} -cvf ../dist/libsentencepiece-macos-${CONFIG}-${PKG_VERSION}.tar.gz .
