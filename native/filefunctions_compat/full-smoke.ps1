$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# Compile Stage 11 AMX from source; never replace files in the checkout.
& (Join-Path $root 'tools\build.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Stage 11 Pawn compilation failed' }
# Streamer 2.7.2 imports MSVCP100/MSVCR100 (x86). The hosted Windows
# runner does not include this legacy redistributable, unlike the user's PC.
# Use Microsoft's original x86 installer and verify its pinned SHA256.
$vc2010 = Join-Path $env:RUNNER_TEMP 'Drazvio-vcredist2010-x86.exe'
$source = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe'
$expected = '99dce3c841cc6028560830f7866c9ce2928c98cf3256892ef8e6cf755147b0d8'
Invoke-WebRequest -Uri $source -OutFile $vc2010
$actual = (Get-FileHash -LiteralPath $vc2010 -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'VC++ 2010 x86 redist hash does not match pinned official package' }
$p = Start-Process -FilePath $vc2010 -ArgumentList '/Q /NORESTART' -Wait -PassThru
if ($p.ExitCode -notin @(0,3010)) { throw "VC++ 2010 x86 redist install failed: $($p.ExitCode)" }
Write-Host 'Installed verified Microsoft VC++ 2010 x86 runtime for isolated CI test.'
$base = Join-Path $env:RUNNER_TEMP ('drazvio_full_smoke_' + [Guid]::NewGuid().ToString('N'))
$server = Join-Path $base 'server'
New-Item -ItemType Directory -Force -Path $base | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $root 'server') -Destination $server -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'build-amx\gamemodes_mod05.amx') -Destination (Join-Path $server 'gamemodes\mod05.amx') -Force
    Copy-Item -LiteralPath (Join-Path $root 'build-amx\filterscripts_gatesys2.amx') -Destination (Join-Path $server 'filterscripts\gatesys2.amx') -Force
    Copy-Item -LiteralPath (Join-Path $root 'build-amx\filterscripts_reklama.amx') -Destination (Join-Path $server 'filterscripts\reklama.amx') -Force
    Copy-Item -LiteralPath (Join-Path $root 'build-amx\FileFunctions.compat.EXPERIMENTAL.dll') -Destination (Join-Path $server 'plugins\FileFunctions.dll') -Force
    $config = @(
        'echo DRAZVIO full server CI smoke test',
        'hostname DRAZVIO - CI only',
        'gamemode0 mod05 1',
        'filterscripts BonusSys elevator2 Garage gatesys2 island keyscan MPSys myobj reklama gps radio3',
        'plugins FileFunctions sscanf streamer',
        'rcon 0',
        ('rcon_password ' + [Guid]::NewGuid().ToString('N')),
        'announce 0',
        'query 0',
        'port 17778',
        'maxplayers 10',
        'maxnpc 0',
        'lanmode 1',
        'lagcompmode 1'
    )
    [System.IO.File]::WriteAllLines((Join-Path $server 'server.cfg'),$config)
    $stdout = Join-Path $base 'stdout.txt'
    $stderr = Join-Path $base 'stderr.txt'
    $proc = Start-Process -FilePath (Join-Path $server 'samp-server.exe') -WorkingDirectory $server -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    Start-Sleep -Seconds 7
    $ended = $proc.HasExited
    if (-not $ended) { $proc.Kill(); $proc.WaitForExit(3000) | Out-Null }
    $output = (Get-Content $stdout -Raw -ErrorAction SilentlyContinue) + (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
    if (Test-Path (Join-Path $server 'server_log.txt')) {
        $output += Get-Content (Join-Path $server 'server_log.txt') -Raw
    }
    Write-Host ('--- Full server smoke log (last 5000 chars) ---')
    Write-Host $output.Substring([Math]::Max(0,$output.Length-5000))
    if ($ended) { throw 'Full DRAZVIO server terminated unexpectedly' }
    if ($output -match 'Run time error|File or function is not found|Loading plugin: FileFunctions\s+Failed') {
        throw 'Runtime error / native import failure detected in full DRAZVIO server'
    }
    if ($output -notmatch 'Loaded 3 plugins' -or $output -notmatch 'Loaded 11 filterscripts') {
        throw 'Expected plugins or filterscripts did not load'
    }
    if ($output -notmatch 'Number of vehicle models:') {
        throw 'GameModeInit did not reach server startup completion'
    }
    Write-Host 'PASS: full DRAZVIO Stage 11 starts with 3 plugins and 11 filterscripts.'
}
finally {
    Remove-Item -LiteralPath $base -Force -Recurse -ErrorAction SilentlyContinue
}
