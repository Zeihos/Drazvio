$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$target = Join-Path $env:RUNNER_TEMP ('drazvio_samp_smoke_' + [Guid]::NewGuid().ToString('N'))
$pawn = Join-Path $target 'pawn'
$server = Join-Path $target 'server'
New-Item -ItemType Directory -Force -Path $pawn, (Join-Path $server 'gamemodes'), (Join-Path $server 'plugins'), (Join-Path $server 'scriptfiles') | Out-Null
try {
    $originalPawn = Join-Path $root 'server\pawno'
    foreach ($filename in @('pawncc.exe','pawnc.dll','libpawnc.dll')) {
        $file = Join-Path $originalPawn $filename
        if (Test-Path $file) { Copy-Item -LiteralPath $file -Destination (Join-Path $pawn $filename) }
    }
    Copy-Item -LiteralPath (Join-Path $originalPawn 'include') -Destination (Join-Path $pawn 'include') -Recurse
    $amx = Join-Path $server 'gamemodes\smoke.amx'
    $source = Join-Path $PSScriptRoot 'smoke.pwn'
    & (Join-Path $pawn 'pawncc.exe') $source "-i$(Join-Path $pawn 'include')" "-o$amx" '-d2'
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $amx)) { throw 'Cannot compile SA-MP smoke gamemode' }
    Copy-Item -LiteralPath (Join-Path $root 'server\samp-server.exe') -Destination (Join-Path $server 'samp-server.exe')
    Copy-Item -LiteralPath (Join-Path $root 'build-amx\FileFunctions.compat.EXPERIMENTAL.dll') -Destination (Join-Path $server 'plugins\FileFunctions.dll')
    $config = @(
        'echo DRAZVIO CI smoke test',
        'hostname DRAZVIO Smoke Test',
        'gamemode0 smoke 1',
        'plugins FileFunctions',
        'rcon 0',
        ('rcon_password ' + [Guid]::NewGuid().ToString('N')),
        'announce 0',
        'query 0',
        'port 17777',
        'maxplayers 2',
        'maxnpc 0',
        'lanmode 1'
    )
    [System.IO.File]::WriteAllLines((Join-Path $server 'server.cfg'), $config)
    $stdout = Join-Path $target 'stdout.txt'
    $stderr = Join-Path $target 'stderr.txt'
    $proc = Start-Process -FilePath (Join-Path $server 'samp-server.exe') -WorkingDirectory $server -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $proc.WaitForExit(20000)) {
        $proc.Kill()
        $proc.WaitForExit()
        throw 'SA-MP smoke test did not stop within 20 seconds'
    }
    $output = (Get-Content $stdout -Raw -ErrorAction SilentlyContinue) + (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
    if (Test-Path (Join-Path $server 'server_log.txt')) {
        $output += Get-Content (Join-Path $server 'server_log.txt') -Raw
    }
    Write-Host $output
    if ($output -notmatch 'DRAZVIO_FILEFUNCTIONS_SMOKE_PASS') { throw 'SA-MP runtime smoke test did not report PASS' }
    if ($output -match 'Run time error 19|Loading plugin: FileFunctions\s+Failed') { throw 'SA-MP reported missing FileFunctions native/plugin' }
    Write-Host 'SA-MP 0.3.7 runtime smoke test passed.'
}
finally {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
}
