$ErrorActionPreference='Stop'

$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$linuxRoot=Join-Path $repoRoot 'lin'
$version=(Get-Content -LiteralPath (Join-Path $linuxRoot 'VERSION') -Raw).Trim()
if($version -notmatch '^\d+\.\d+\.\d+$'){throw "Invalid Linux Toolkit version: $version"}

$moduleNames=@('Core','System','Storage','Network','Services','Security','Updates','Containers','Maintenance','Menu')
$parts=New-Object 'Collections.Generic.List[string]'
$parts.Add('#!/usr/bin/env bash')
$parts.Add("# Random Toolkits | Linux Toolkit $version")
$parts.Add('# Generated from lin/modules/*.sh by tests/Sync-LinuxToolkit.ps1.')
$parts.Add('set -o pipefail')
$parts.Add("LIN_TOOLKIT_VERSION='$version'")
foreach($name in $moduleNames){
    $path=Join-Path $linuxRoot "modules/$name.sh"
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing Linux module: $path"}
    $parts.Add('')
    $parts.Add("# BEGIN $($name.ToUpperInvariant())")
    $parts.Add(([IO.File]::ReadAllText($path)).TrimEnd())
    $parts.Add("# END $($name.ToUpperInvariant())")
}
$parts.Add('')
$parts.Add('if [[ -z ${BASH_SOURCE[0]:-} || ${BASH_SOURCE[0]} == "$0" ]]; then lin_main "$@"; fi')
$parts.Add('')
$content=($parts -join "`n")
$utf8NoBom=[Text.UTF8Encoding]::new($false)
$scriptPath=Join-Path $linuxRoot 'Linux-Toolkit.sh'
$endpointPath=Join-Path $linuxRoot 'index.html'
[IO.File]::WriteAllText($scriptPath,$content,$utf8NoBom)
[IO.File]::WriteAllText($endpointPath,$content,$utf8NoBom)
if((Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $endpointPath -Algorithm SHA256).Hash){
    throw 'lin/index.html does not match Linux-Toolkit.sh.'
}
Write-Output "Linux Toolkit $version synchronized successfully."
