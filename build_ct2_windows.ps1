Param(
    $Configuration,
    $CudaVersionOrCpu
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
$OpenBLASVersion = "0.3.26"
Invoke-WebRequest -Uri https://github.com/xianyi/OpenBLAS/releases/download/v$OpenBLASVersion/OpenBLAS-$OpenBLASVersion-x64.zip `
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
if ($cudaBuild -ne $null) {
  $cudaPathUnix = $cudaBuild -replace '\\', '/'
  $cudaFlag = " -DWITH_CUDA=ON -DCUDA_TOOLKIT_ROOT_DIR=`"$cudaPathUnix`""
} else {
  $cudaFlag = "-DWITH_CUDA=OFF"
}

$command = "cmake . -B build_$Configuration " +
    "-DBUILD_SHARED_LIBS=ON " +
    "-DOPENMP_RUNTIME=COMP " +
    "-DWITH_MKL=OFF " +
    "-DWITH_EXAMPLES=OFF " +
    "-DWITH_TFLITE=OFF " + 
    "-DWITH_TRT=OFF " + 
    "-DWITH_PYTHON=OFF " + 
    "-DWITH_SERVER=OFF " + 
    "-DWITH_COVERAGE=OFF " + 
    "-DWITH_PROFILING=OFF " +
    "-DBUILD_CLI=OFF " +
    "-DWITH_OPENBLAS=ON " +
    "-DOPENBLAS_INCLUDE_DIR=`"OpenBLAS-$OpenBLASVersion-x64\include`" " +
    "-DOPENBLAS_LIBRARY=`"OpenBLAS-$OpenBLASVersion-x64\lib\libopenblas.dll.a`" " +
    "$extraFlag  $cudaFlag"

Write-Host $command
Invoke-Expression $command

cmake --build build_$Configuration --config $Configuration

New-Item -ItemType Directory -Force -Path "..\dist\"

cmake --install build_$Configuration --config $Configuration --prefix "..\dist\$Configuration"
# copy openblas .dll to dist folder, first create the folder
New-Item -ItemType Directory -Force -Path "..\dist\$Configuration\bin"
Copy-Item -Force "OpenBLAS-$OpenBLASVersion-x64\bin\libopenblas.dll" "..\dist\$Configuration\bin\libopenblas.dll"

$cudaConfig = "-cpu"

# copy the cublas dll if this is a cuda build
if ($cudaBuild -ne $null) {
  Copy-Item -Force "$cudaBuild\bin\cublas*.dll" -Destination "..\dist\$Configuration\bin\"
  $cudaConfig = "-cuda$CudaVersionOrCpu"
}

Remove-Item -Force "..\dist\libctranslate2-windows-$Version-$Configuration$cudaConfig.zip" -ErrorAction SilentlyContinue
Compress-Archive "..\dist\$Configuration\*" "..\dist\libctranslate2-windows-$Version-$Configuration$cudaConfig.zip" -Verbose

Set-Location "..\"
Remove-Item "CTranslate2-$Version" -Recurse -Force
Remove-Item "dist\$Configuration" -Recurse -Force
