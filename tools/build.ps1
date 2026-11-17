param([switch]$Install)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server = Join-Path $root 'Мод'
$compiler = Join-Path $server 'pawno\pawncc.exe'
$include = Join-Path $server 'pawno\include'
$outputDir = Join-Path $root 'build-amx'
if (!(Test-Path $compiler) -or !(Test-Path (Join-Path $include 'a_samp.inc'))) {
    throw 'Missing Pawn compiler or a_samp.inc'
}
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$targets = @('gamemodes/mod05', 'filterscripts/gatesys2', 'filterscripts/reklama')
foreach ($name in $targets) {
    $source = Join-Path $server ($name + '.pwn')
    $temp = Join-Path $outputDir (($name -replace '/', '_') + '.amx')
    if (!(Test-Path $source)) { throw "Missing Pawn source: $name" }
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    Write-Host "Building $name"
    & $compiler $source "-i$include" "-o$temp" '-d2'
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $temp) -or (Get-Item $temp).Length -lt 512) {
        throw "Pawn compilation failed: $name. Existing server AMX files were NOT changed."
    }
}
if ($Install) {
    foreach ($name in $targets) {
        $compiled = Join-Path $outputDir (($name -replace '/', '_') + '.amx')
        $dest = Join-Path $server ($name + '.amx')
        if (Test-Path $dest) { Copy-Item -LiteralPath $dest -Destination ($dest + '.before_build') -Force }
        Copy-Item -LiteralPath $compiled -Destination $dest -Force
    }
    Write-Host 'New AMX files installed; previous versions saved as .before_build.'
} else {
    Write-Host "Compilation succeeded. Artifacts: $outputDir (server files untouched)."
}
