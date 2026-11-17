$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$build = Join-Path $root 'build-amx'
$source = Join-Path $root 'server'
$tmp = Join-Path $env:RUNNER_TEMP ('drazvio_package_' + [Guid]::NewGuid().ToString('N'))
$stage = Join-Path $tmp 'DRAZVIO'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    Copy-Item -LiteralPath $source -Destination $stage -Recurse
    foreach ($folder in @('gamemodes','filterscripts')) {
        Get-ChildItem -LiteralPath (Join-Path $stage $folder) -Filter '*.pwn' -File | Remove-Item -Force
    }
    if (Test-Path (Join-Path $stage 'pawno')) {
        Remove-Item -LiteralPath (Join-Path $stage 'pawno') -Force -Recurse
    }
    foreach ($name in @('gamemodes/mod05','filterscripts/gatesys2','filterscripts/reklama')) {
        $file = Join-Path $build (($name -replace '/', '_') + '.amx')
        if (!(Test-Path $file)) { throw "Missing compiled file: $name" }
        Copy-Item -LiteralPath $file -Destination (Join-Path $stage ($name + '.amx')) -Force
    }
    $plugin = Join-Path $build 'FileFunctions.compat.EXPERIMENTAL.dll'
    if (!(Test-Path $plugin)) { throw 'Missing FileFunctions CI artifact' }
    Copy-Item -LiteralPath $plugin -Destination (Join-Path $stage 'plugins/FileFunctions.dll') -Force
    $data = Join-Path $stage 'scriptfiles/data'
    foreach ($template in Get-ChildItem -LiteralPath $data -Filter '*.ini.example' -File) {
        $dest = $template.FullName.Substring(0, $template.FullName.Length - 8)
        if (!(Test-Path $dest)) { Copy-Item -LiteralPath $template.FullName -Destination $dest }
        Remove-Item -LiteralPath $template.FullName -Force
    }
    if (Test-Path (Join-Path $stage 'server.cfg')) { throw 'Private server.cfg found in test package' }
    foreach ($name in @('samp-server.exe','samp-license.txt','server.cfg.example',
        'gamemodes/mod05.amx','plugins/FileFunctions.dll','plugins/sscanf.dll','plugins/streamer.dll')) {
        if (!(Test-Path (Join-Path $stage $name))) { throw "Missing runtime file: $name" }
    }
    $zip = Join-Path $build 'DRAZVIO-SERVER-TEST.zip'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal -Force
    if (!(Test-Path $zip)) { throw 'Could not create test ZIP' }
    Write-Host "Test-only clean server package created: $zip"
}
finally {
    Remove-Item -LiteralPath $tmp -Force -Recurse -ErrorAction SilentlyContinue
}
