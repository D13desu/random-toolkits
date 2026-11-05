[CmdletBinding()]
param([string]$OutputDirectory,[switch]$BaselineStorage,[switch]$LegacyRows,[switch]$LegacyFolders,[switch]$LegacyPaths)
$ErrorActionPreference='Stop'
if(-not $OutputDirectory){$OutputDirectory=Join-Path $PSScriptRoot 'out'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$source=Get-Content (Join-Path $root 'win/disk/Disk-Usage.ps1') -Raw
$match=[regex]::Match($source,"(?s)Add-Type -ErrorAction Stop -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if(-not $match.Success){throw 'Embedded engine source not found.'}
$engine=$match.Groups[1].Value
$mft=Get-Content (Join-Path $root 'win/disk/MftScanner.cs') -Raw
$embedded=($engine -split '// BEGIN EMBEDDED MFT SCANNER',2)[1] -split '// END EMBEDDED MFT SCANNER',2
if($embedded[0].Replace("`r`n","`n").Trim() -ne $mft.Replace("`r`n","`n").Trim()){throw 'MFT source is not synchronized; run tests/Sync-DiskMft.ps1 first.'}
. (Join-Path $PSScriptRoot 'Transform-Engine.ps1')
$engine=ConvertTo-HelperEngine ($engine.Replace("`r`n","`n")) -CompactNames:(-not $BaselineStorage) -ReleaseRecords:(-not $BaselineStorage)
$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
if(-not (Test-Path (Join-Path $framework 'csc.exe'))){$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319'}
$compiler=Join-Path $framework 'csc.exe'
if(-not (Test-Path $compiler)){throw '.NET Framework C# compiler not found.'}
$output=[IO.Path]::GetFullPath($OutputDirectory);$null=[IO.Directory]::CreateDirectory($output)
$enginePath=Join-Path $output 'Engine.generated.cs'
[IO.File]::WriteAllText($enginePath,$engine,[Text.UTF8Encoding]::new($false))
$exe=Join-Path $output 'DiskHelper.exe'
$sources=@($enginePath,(Join-Path $PSScriptRoot 'Program.cs'),(Join-Path $PSScriptRoot 'CompactIndex.cs'),(Join-Path $PSScriptRoot 'ScanProfile.cs'),(Join-Path $PSScriptRoot 'DirectRows.cs'),(Join-Path $PSScriptRoot 'DirectoryPaths.cs'),(Join-Path $PSScriptRoot 'ScanAccounting.cs'))
if(-not $BaselineStorage){$sources+=Join-Path $PSScriptRoot 'MftNames.cs'}
$defines=if($LegacyRows -or $BaselineStorage){'/define:LEGACY_ROWS'}elseif($LegacyFolders){'/define:DIRECT_ROWS'}elseif($LegacyPaths){'/define:DIRECT_ROWS,COMPACT_FOLDERS'}else{'/define:DIRECT_ROWS,COMPACT_FOLDERS,LAZY_PATHS'}
& $compiler /nologo /target:exe /platform:anycpu /optimize+ /utf8output $defines ("/out:"+$exe) ("/reference:"+(Join-Path $framework 'System.Web.Extensions.dll')) $sources
if($LASTEXITCODE -ne 0){throw 'Helper compilation failed.'}
$manifest=[ordered]@{Version='0.8.1-experiment';Protocol=1;EngineVersion='0.4.4';Storage=$(if($BaselineStorage){'baseline'}elseif($LegacyRows){'inline names, released records'}elseif($LegacyFolders){'direct compact rows, inline names, released records'}elseif($LegacyPaths){'compact folders, direct rows, retained paths'}else{'on-demand paths, compact folders, direct rows'});File='DiskHelper.exe';Sha256=(Get-FileHash $exe -Algorithm SHA256).Hash;EngineSha256=(Get-FileHash $enginePath -Algorithm SHA256).Hash}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding UTF8
[pscustomobject]@{Executable=$exe;Manifest=(Join-Path $output 'manifest.json');Bytes=(Get-Item $exe).Length}
