Param(
    $Configuration,
    $Acceleration
)

# stop on error
$ErrorActionPreference = "Stop"

$Version = "4.7.1"

# Clone CTranslate2 repo.
git clone https://github.com/OpenNMT/CTranslate2.git "CTranslate2-$Version"
Set-Location "CTranslate2-$Version"
git checkout "v$Version"
git submodule update --init --recursive

# download OpenBLAS
$OpenBLASVersion = "0.3.32"
Invoke-WebRequest -Uri https://github.com/OpenMathLib/OpenBLAS/releases/download/v$OpenBLASVersion/OpenBLAS-$OpenBLASVersion-x64.zip `
  -OutFile OpenBLAS-$OpenBLASVersion-x64.zip
Expand-Archive OpenBLAS-$OpenBLASVersion-x64.zip -DestinationPath OpenBLAS-$OpenBLASVersion-x64 -Force
Remove-Item OpenBLAS-$OpenBLASVersion-x64.zip

if ($Configuration -eq "Release") {
  $extraFlag = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL"
} else {
  $extraFlag = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDebugDLL"
}

# if CUDA_PATH exists on env variables, then build with CUDA
$cudaBuild = [System.Environment]::GetEnvironmentVariable("CUDA_PATH", "Machine")
$hipBuild = [System.Environment]::GetEnvironmentVariable("HIP_PATH", "Machine")
if ($cudaBuild -ne $null) {
  $cudaPathUnix = $cudaBuild -replace '\\', '/'
  $accelFlag = " -DWITH_CUDA=ON -DWITH_FLASH_ATTN=ON -DCUDA_TOOLKIT_ROOT_DIR=`"$cudaPathUnix`" -DWITH_HIP=OFF"
} elseif ($hipBuild -ne $null) {
  $accelFlag = " -DWITH_CUDA=OFF " +
    "-DWITH_HIP=ON " +
    "-DCMAKE_HIP_ARCHITECTURES=`"$env:AMD_GPU_TARGETS`" " +
    "-DGPU_TARGETS=`"$env:AMD_GPU_TARGETS`" " +
    "-DCMAKE_GENERATOR=`"Unix Makefiles`" " +
    "-DCMAKE_C_COMPILER='$env:HIP_PATH\bin\clang.exe' " +
    "-DCMAKE_CXX_COMPILER='$env:HIP_PATH\bin\clang++.exe' " +
    "-DCMAKE_CXX_FLAGS=`"-Wno-deprecated -Wno-deprecated-declarations -Wno-deprecated-literal-operator -Wno-ignored-attributes -Wno-ignored-pragmas -Wno-unused-parameter -Wno-unused-result -Wno-unused-value -Wno-unused-variable -Wno-reorder-ctor`""
  $env:ROCM_PATH = $env:HIP_PATH
} else {
  $accelFlag = "-DWITH_CUDA=OFF -DWITH_HIP=OFF"
}

$command = "cmake . -B build_$Configuration " +
    "-DCMAKE_POLICY_VERSION_MINIMUM=`"3.5`" " +
    "-DBUILD_SHARED_LIBS=ON " +
    "-DOPENMP_RUNTIME=COMP " +
    "-DWITH_MKL=OFF " +
    "-DENABLE_PROFILING=OFF " +
    "-DBUILD_CLI=OFF " +
    "-DWITH_OPENBLAS=ON " +
    "-DOPENBLAS_INCLUDE_DIR=`"OpenBLAS-$OpenBLASVersion-x64\include`" " +
    "-DOPENBLAS_LIBRARY=`"OpenBLAS-$OpenBLASVersion-x64\lib\libopenblas.dll.a`" " +
    "$extraFlag  $accelFlag"

Write-Host $command
Invoke-Expression $command

cmake --build build_$Configuration --config $Configuration --parallel

New-Item -ItemType Directory -Force -Path "..\dist\"

cmake --install build_$Configuration --config $Configuration --prefix "..\dist\$Configuration"
# copy openblas .dll to dist folder, first create the folder
New-Item -ItemType Directory -Force -Path "..\dist\$Configuration\bin"
Copy-Item -Force "OpenBLAS-$OpenBLASVersion-x64\bin\libopenblas.dll" "..\dist\$Configuration\bin\libopenblas.dll"

$accelConfig = "-cpu"

# copy the cublas dll if this is a cuda build
if ($cudaBuild -ne $null) {
  Copy-Item -Force "$cudaBuild\bin\cublas*.dll" -Destination "..\dist\$Configuration\bin\"
  $accelConfig = "-cuda12.8.1"
}

Remove-Item -Force "..\dist\libctranslate2-windows-$Version-$Configuration$accelConfig.zip" -ErrorAction SilentlyContinue
Compress-Archive "..\dist\$Configuration\*" "..\dist\libctranslate2-windows-$Version-$Configuration$accelConfig.zip" -Verbose

Set-Location "..\"
Remove-Item "CTranslate2-$Version" -Recurse -Force
Remove-Item "dist\$Configuration" -Recurse -Force
