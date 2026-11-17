# Create a deliberately minimal, player-data-free TEST server archive.
# Only files from this allowlist can ever enter the artifact.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = Join-Path $root 'server'
$build = Join-Path $root 'build-amx'
$temp = Join-Path $env:RUNNER_TEMP ('drazvio_safe_package_' + [Guid]::NewGuid().ToString('N'))
$stage = Join-Path $temp 'DRAZVIO'
$filterNames = @('BonusSys','elevator2','Garage','gatesys2','island',
                 'keyscan','MPSys','myobj','reklama','gps','radio3')
$compiledTargets = @{
    'gamemodes/mod05.amx' = 'gamemodes_mod05.amx'
    'filterscripts/gatesys2.amx' = 'filterscripts_gatesys2.amx'
    'filterscripts/reklama.amx' = 'filterscripts_reklama.amx'
}
$staticFiles = @('samp-server.exe','samp-license.txt','server.cfg.example',
                 'plugins/sscanf.dll','plugins/streamer.dll')
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    foreach ($folder in @('gamemodes','filterscripts','plugins',
                          'scriptfiles/CarSpawn','scriptfiles/data')) {
        New-Item -ItemType Directory -Path (Join-Path $stage $folder) -Force | Out-Null
    }

    foreach ($name in $staticFiles) {
        $src = Join-Path $source $name
        if (!(Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing required file: $name" }
        Copy-Item -LiteralPath $src -Destination (Join-Path $stage $name)
    }
    foreach ($name in $filterNames) {
        if ($name -in @('gatesys2','reklama')) { continue }
        $src = Join-Path $source ("filterscripts/" + $name + ".amx")
        if (!(Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing filterscript: $name" }
        Copy-Item -LiteralPath $src -Destination (Join-Path $stage ("filterscripts/" + $name + ".amx"))
    }
    foreach ($entry in $compiledTargets.GetEnumerator()) {
        $src = Join-Path $build $entry.Value
        if (!(Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing compiled AMX: $($entry.Value)" }
        Copy-Item -LiteralPath $src -Destination (Join-Path $stage $entry.Key)
    }
    $dll = Join-Path $build 'FileFunctions.compat.EXPERIMENTAL.dll'
    if (!(Test-Path -LiteralPath $dll -PathType Leaf)) { throw 'FileFunctions CI DLL missing' }
    Copy-Item -LiteralPath $dll -Destination (Join-Path $stage 'plugins/FileFunctions.dll')

    $carFiles = Get-ChildItem -LiteralPath (Join-Path $source 'scriptfiles/CarSpawn') -Filter '*.txt' -File
    if ($carFiles.Count -ne 17) { throw "Expected 17 static CarSpawn lists; got $($carFiles.Count)" }
    foreach ($file in $carFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $stage 'scriptfiles/CarSpawn')
    }

    $templates = Get-ChildItem -LiteralPath (Join-Path $source 'scriptfiles/data') -Filter '*.ini.example' -File
    if ($templates.Count -ne 6) { throw "Expected 6 sanitized initial INIs; got $($templates.Count)" }
    foreach ($file in $templates) {
        # BaseName for "cash.ini.example" is "cash.ini".
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $stage ('scriptfiles/data/' + $file.BaseName))
    }
    $zip = Join-Path $build 'DRAZVIO-SERVER-TEST.zip'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal -Force
    if (!(Test-Path -LiteralPath $zip -PathType Leaf)) { throw 'Archive creation failed' }
    Write-Host "Safe, allowlisted test archive created: $zip"
}
finally {
    Remove-Item -LiteralPath $temp -Force -Recurse -ErrorAction SilentlyContinue
}
