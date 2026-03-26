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

$cmakeArgs = @()
$cmakeArgs += ("-DBUILD_SHARED_LIBS=ON",
    "-DOPENMP_RUNTIME=COMP",
    "-DWITH_MKL=OFF",
    "-DWITH_EXAMPLES=OFF",
    "-DWITH_TFLITE=OFF",
    "-DWITH_TRT=OFF",
    "-DWITH_PYTHON=OFF",
    "-DWITH_SERVER=OFF",
    "-DWITH_COVERAGE=OFF",
    "-DWITH_PROFILING=OFF",
    "-DBUILD_CLI=OFF",
    "-DWITH_OPENBLAS=ON",
    "-DOPENBLAS_INCLUDE_DIR=`"OpenBLAS-$OpenBLASVersion-x64\include`"",
    "-DOPENBLAS_LIBRARY=`"OpenBLAS-$OpenBLASVersion-x64\lib\libopenblas.dll.a`"")

# download OpenBLAS
$OpenBLASVersion = "0.3.32"
Invoke-WebRequest -Uri https://github.com/OpenMathLib/OpenBLAS/releases/download/v$OpenBLASVersion/OpenBLAS-$OpenBLASVersion-x64.zip `
  -OutFile OpenBLAS-$OpenBLASVersion-x64.zip
Expand-Archive OpenBLAS-$OpenBLASVersion-x64.zip -DestinationPath OpenBLAS-$OpenBLASVersion-x64 -Force
Remove-Item OpenBLAS-$OpenBLASVersion-x64.zip

if ($Configuration -eq "Release") {
  $cmakeArgs += ("-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL")
} else {
  $cmakeArgs += ("-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDebugDLL")
}

# if CUDA_PATH exists on env variables, then build with CUDA
$cudaBuild = [System.Environment]::GetEnvironmentVariable("CUDA_PATH", "Machine")
$hipBuild = [System.Environment]::GetEnvironmentVariable("HIP_PATH", "Machine")
if ($cudaBuild -ne $null) {
  $cudaPathUnix = $cudaBuild -replace '\\', '/'
  $cmakeArgs += ("-DWITH_CUDA=ON",
    "-DWITH_FLASH_ATTN=ON",
    "-DCUDA_TOOLKIT_ROOT_DIR=`"$cudaPathUnix`"",
    "-DWITH_HIP=OFF")
} elseif ($hipBuild -ne $null) {
  # List supported ROCm GPU targets in ROCm 6.4.2, and also some unsupported ones that might work
  # See https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html and https://rocm.docs.amd.com/en/docs-6.4.2/reference/gpu-arch-specs.html
  # gfx950 is supported in 7.1.0 but not 6.4.2 that we're using
  # Supported GPU targets gfx908 gfx90a gfx942 gfx1030 gfx1100 gfx1200 gfx1201
  # Unsupported GPU targets gfx803 gfx900 gfx906 gfx950 gfx1010 gfx1011 gfx1012 gfx1031 gfx1032 gfx1101 gfx1102 gfx1150 gfx1151 gfx1152)
  $cmakeArgs += ("-DWITH_CUDA=OFF",
    "-DWITH_HIP=ON",
    "-DCMAKE_HIP_ARCHITECTURES=`"gfx908;gfx90a;gfx942;gfx1030;gfx1100;gfx1200;gfx1201;gfx803;gfx900;gfx906;gfx950;gfx1010;gfx1011;gfx1012;gfx1031;gfx1032;gfx1101;gfx1102;gfx1150;gfx1151;gfx1152`"",
    "-DCMAKE_GENERATOR=Unix Makefiles",
    "-DCMAKE_C_COMPILER='$env:HIP_PATH\bin\clang.exe'",
    "-DCMAKE_CXX_COMPILER='$env:HIP_PATH\bin\clang++.exe'")
} else {
  $cmakeArgs += ("-DWITH_CUDA=OFF", "-DWITH_HIP=OFF")
}

$command = "cmake . -B build_$Configuration " + @accelArgs

Write-Host $command
Invoke-Expression $command

cmake --build build_$Configuration --config $Configuration

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
