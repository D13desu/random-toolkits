$ErrorActionPreference='Stop'
$output=Join-Path $PSScriptRoot 'out/compact-test'
$null=& (Join-Path $PSScriptRoot 'Build-Helper.ps1') -OutputDirectory $output
$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
if(-not (Test-Path (Join-Path $framework 'csc.exe'))){$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319'}
$exe=Join-Path $output 'CompactIndex.Tests.exe'
& (Join-Path $framework 'csc.exe') /nologo /target:exe /optimize+ ("/out:"+$exe) (Join-Path $output 'Engine.generated.cs') (Join-Path $PSScriptRoot 'ScanProfile.cs') (Join-Path $PSScriptRoot 'MftNames.cs') (Join-Path $PSScriptRoot 'CompactIndex.cs') (Join-Path $PSScriptRoot 'DirectRows.cs') (Join-Path $PSScriptRoot 'Test-CompactIndex.cs')
if($LASTEXITCODE -ne 0){throw 'Compact-index tests did not compile.'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Compact-index tests failed.'}
