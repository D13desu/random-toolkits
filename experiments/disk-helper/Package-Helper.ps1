[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$output=Join-Path $PSScriptRoot 'out'
$manifest=Get-Content (Join-Path $output 'manifest.json') -Raw | ConvertFrom-Json
if((Get-FileHash (Join-Path $output 'DiskHelper.exe') -Algorithm SHA256).Hash -ne $manifest.Sha256){throw 'Build output checksum mismatch.'}
$stage=Join-Path $output ('package-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory((Join-Path $stage 'out'))
foreach($file in @('Start-DiskHelper.ps1','Helper-Client.ps1','Helper-Ui.ps1','README.md')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $stage $file)}
foreach($file in @('DiskHelper.exe','manifest.json')){Copy-Item -LiteralPath (Join-Path $output $file) -Destination (Join-Path $stage 'out')}
$zip=Join-Path $output ('DiskHelper-'+$manifest.Version+'.zip')
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
$sum=(Get-FileHash $zip -Algorithm SHA256).Hash+'  '+[IO.Path]::GetFileName($zip)
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'),$sum+"`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{Archive=$zip;Bytes=(Get-Item $zip).Length;Sha256=$sum.Split(' ')[0]}
