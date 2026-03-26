Param($Configuration)

$Version = "0.2.1"

# Clone CTranslate2 repo.
git clone https://github.com/google/sentencepiece.git "sentencepiece-$Version"
Set-Location "sentencepiece-$Version"
git checkout "v$Version"
git submodule update --init --recursive

if ($Configuration -eq "Release") {
    $runtimeFlag = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL"
  } else {
    $runtimeFlag = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDebugDLL"
  }

cmake . -B build_$Configuration `
    -DSPM_ENABLE_SHARED=ON `
    -DBUILD_SHARED_LIBS=ON `
    $runtimeFlag

cmake --build build_$Configuration --config $Configuration

New-Item -ItemType Directory -Force -Path "..\dist\"

cmake --install build_$Configuration --config $Configuration --prefix "..\dist\$Configuration"

Compress-Archive "..\dist\$Configuration\*" "..\dist\sentencepiece-windows-$Version-$Configuration.zip" -Verbose

Set-Location "..\"
Remove-Item "sentencepiece-$Version" -Recurse -Force
Remove-Item "dist\$Configuration" -Recurse -Force
