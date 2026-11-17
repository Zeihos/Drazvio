$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $root 'build-amx'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$sdk = Join-Path $env:RUNNER_TEMP 'drazvio-samp-plugin-sdk'
if (!(Test-Path $sdk)) {
    git clone --quiet https://github.com/samp-forks/samp-plugin-sdk.git $sdk
    if ($LASTEXITCODE -ne 0) { throw 'Cannot download SA-MP headers' }
}
git -C $sdk checkout --quiet --detach 938781bafd8089cdb26af0617af24f862b2c3831
if ($LASTEXITCODE -ne 0) { throw 'Cannot check out pinned SDK' }
$vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path $vswhere)) { throw 'Missing Visual Studio vswhere.exe' }
$vs = (& $vswhere -latest -products '*' -property installationPath).Trim()
if (!$vs) { throw 'Missing Visual Studio' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars32.bat'
if (!(Test-Path $vcvars)) { throw 'Missing 32-bit Visual C++ toolchain' }
$dll = Join-Path $outDir 'FileFunctions.compat.EXPERIMENTAL.dll'
$src = Join-Path $PSScriptRoot 'filefunctions.cpp'
$def = Join-Path $PSScriptRoot 'exports.def'
$line = 'call "' + $vcvars + '" >nul && cl /nologo /std:c++17 /O2 /EHsc /MT /LD /W4 /I "' + $sdk + '" /Fe:"' + $dll + '" "' + $src + '" /link /DEF:"' + $def + '"'
cmd.exe /d /s /c $line
if ($LASTEXITCODE -ne 0 -or !(Test-Path $dll)) { throw 'Native plugin build failed' }
$bytes = [System.IO.File]::ReadAllBytes($dll)
$ascii = [System.Text.Encoding]::ASCII.GetString($bytes).ToUpperInvariant()
foreach ($bad in @('MSVCR100D.DLL','VCRUNTIME140D.DLL','UCRTBASED.DLL','MSVCP140D.DLL')) {
    if ($ascii.Contains($bad)) { throw "Debug CRT import: $bad" }
}
$testExe = Join-Path $outDir 'FileFunctions.compat.selftest.exe'
$testSrc = Join-Path $PSScriptRoot 'selftest.cpp'
$testCmd = 'call "' + $vcvars + '" >nul && cl /nologo /std:c++17 /O2 /EHsc /MT /W4 /I "' + $sdk + '" /Fe:"' + $testExe + '" "' + $testSrc + '"'
cmd.exe /d /s /c $testCmd
if ($LASTEXITCODE -ne 0 -or !(Test-Path $testExe)) { throw 'Native self-test compilation failed' }
& $testExe $dll
if ($LASTEXITCODE -ne 0) { throw 'Native plugin self-test failed' }
Write-Host 'EXPERIMENTAL DLL passed ABI/filesystem self-tests; no automatic installation. Full SA-MP runtime compatibility still unverified.'
