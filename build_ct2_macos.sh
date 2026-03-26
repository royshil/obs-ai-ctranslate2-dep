#!/bin/bash
set -euo pipefail

CONFIG=${1?}
PKG_VERSION=${2?}

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

function build_for_arch() {
  ARCH=$1
  echo "Building for ${ARCH}"
  cmake . -B build_${ARCH}_${CONFIG} \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_ACCELERATE=ON \
    -DOPENMP_RUNTIME=NONE \
    -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
    -DWITH_CUDA=OFF \
    -DWITH_MKL=OFF \
    -DWITH_TESTS=OFF \
    -DWITH_EXAMPLES=OFF \
    -DWITH_TFLITE=OFF \
    -DWITH_TRT=OFF \
    -DWITH_PYTHON=OFF \
    -DWITH_SERVER=OFF \
    -DWITH_COVERAGE=OFF \
    -DWITH_PROFILING=OFF \
    -DBUILD_CLI=OFF \
    -DWITH_OPENBLAS=OFF \
    -DCMAKE_GENERATOR=Xcode \
    -DCMAKE_BUILD_TYPE=${CONFIG}

  cmake --build build_${ARCH}_${CONFIG} --config ${CONFIG} -- -arch ${ARCH} ONLY_ACTIVE_ARCH=YES
  mkdir -p dist/${ARCH}/${CONFIG}
  cmake --install build_${ARCH}_${CONFIG} --config ${CONFIG} --prefix dist/${ARCH}/${CONFIG}
}

build_for_arch x86_64
build_for_arch arm64

if [ -d dist/universal/${CONFIG}/lib ]; then
  rm -rf dist/universal/${CONFIG}/lib
fi
# Create universal binary.
mkdir -p dist/universal/${CONFIG}/lib
lipo -create dist/x86_64/${CONFIG}/lib/libctranslate2.a dist/arm64/${CONFIG}/lib/libctranslate2.a -output dist/universal/${CONFIG}/lib/libctranslate2.a
cp build_x86_64_${CONFIG}/third_party/cpu_features/${CONFIG}/libcpu_features.a dist/universal/${CONFIG}/lib

# Copy headers.
cp -r dist/x86_64/${CONFIG}/include dist/universal/${CONFIG}/include

mkdir -p ../dist
tar -C dist/universal/${CONFIG} -cvf ../dist/libctranslate2-macos-${CONFIG}-${PKG_VERSION}.tar.gz .
