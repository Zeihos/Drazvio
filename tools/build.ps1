param([switch]$Install)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server = Join-Path $root 'Мод'
$outputDir = Join-Path $root 'build-amx'
$targets = @('gamemodes/mod05', 'filterscripts/gatesys2', 'filterscripts/reklama')

# Pawn 3.2.3664 cannot open paths with Cyrillic characters on Windows.
# Compile binary-identical source copies under a temporary ASCII-only path.
$staging = Join-Path $env:TEMP ('drazvio_pawn_' + [Guid]::NewGuid().ToString('N'))
if ($staging -match '[^\x00-\x7F]') {
    throw 'Pawn compiler requires an ASCII-only TEMP path. Set TEMP to an ASCII directory.'
}
$stageInclude = Join-Path $staging 'pawno\include'
$stageCompiler = Join-Path $staging 'pawno\pawncc.exe'
New-Item -ItemType Directory -Force -Path $outputDir, $staging | Out-Null
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $staging 'pawno'), (Join-Path $staging 'gamemodes'), (Join-Path $staging 'filterscripts'), (Join-Path $staging 'out') | Out-Null
    foreach ($binary in @('pawncc.exe', 'pawnc.dll', 'libpawnc.dll')) {
        $from = Join-Path $server ('pawno\' + $binary)
        if (Test-Path $from) { Copy-Item -LiteralPath $from -Destination (Join-Path $staging ('pawno\' + $binary)) }
    }
    $includes = Join-Path $server 'pawno\include'
    if (!(Test-Path $stageCompiler) -or !(Test-Path (Join-Path $includes 'a_samp.inc'))) {
        throw 'Missing Pawn compiler or a_samp.inc'
    }
    Copy-Item -LiteralPath $includes -Destination $stageInclude -Recurse -Force
    foreach ($name in $targets) {
        $original = Join-Path $server ($name + '.pwn')
        $source = Join-Path $staging ($name + '.pwn')
        $compiled = Join-Path $staging ('out\' + ($name -replace '/', '_') + '.amx')
        if (!(Test-Path $original)) { throw "Missing Pawn source: $name" }
        Copy-Item -LiteralPath $original -Destination $source -Force
        Write-Host "Building $name from ASCII staging area"
        & $stageCompiler $source "-i$stageInclude" "-o$compiled" '-d2'
        if ($LASTEXITCODE -ne 0 -or !(Test-Path $compiled) -or (Get-Item $compiled).Length -lt 512) {
            throw "Pawn compilation failed: $name. Existing server AMX files were NOT changed."
        }
        Copy-Item -LiteralPath $compiled -Destination (Join-Path $outputDir (($name -replace '/', '_') + '.amx')) -Force
    }
    if ($Install) {
        foreach ($name in $targets) {
            $compiled = Join-Path $outputDir (($name -replace '/', '_') + '.amx')
            $dest = Join-Path $server ($name + '.amx')
            if (Test-Path $dest) {
                Copy-Item -LiteralPath $dest -Destination ($dest + '.before_build') -Force
            }
            Copy-Item -LiteralPath $compiled -Destination $dest -Force
        }
        Write-Host 'New AMX files installed; previous versions saved as .before_build.'
    } else {
        Write-Host "Compilation succeeded. Artifacts: $outputDir (server files untouched)."
    }
}
finally {
    Remove-Item -LiteralPath $staging -Force -Recurse -ErrorAction SilentlyContinue
}
