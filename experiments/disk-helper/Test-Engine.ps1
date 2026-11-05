[CmdletBinding()]
param([string]$HelperDirectory,[switch]$DirectRows)
$ErrorActionPreference='Stop'
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
if('RandomToolkits.DiskV10.Scanner' -as [type]){throw 'Run engine tests in a fresh PowerShell process.'}
if($DirectRows){
    $framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
    if(-not (Test-Path (Join-Path $framework 'csc.exe'))){$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319'}
    $dll=Join-Path $HelperDirectory 'DirectProbe.Tests.dll'
    & (Join-Path $framework 'csc.exe') /nologo /target:library /optimize+ ("/out:"+$dll) (Join-Path $HelperDirectory 'Engine.generated.cs') (Join-Path $PSScriptRoot 'ScanProfile.cs') (Join-Path $PSScriptRoot 'MftNames.cs') (Join-Path $PSScriptRoot 'CompactIndex.cs') (Join-Path $PSScriptRoot 'DirectRows.cs') (Join-Path $PSScriptRoot 'DirectoryPaths.cs') (Join-Path $PSScriptRoot 'Test-DirectProbe.cs')
    if($LASTEXITCODE -ne 0){throw 'Direct engine probe compilation failed.'}
    $null=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath($dll))
    $tests=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../tests'))
    $source=Get-Content (Join-Path $tests 'Test-MftScanner.ps1') -Raw
    $source=$source.Replace('[RandomToolkits.DiskV10.MftScanner]::Build(', '[RandomToolkits.DiskV10.DirectProbe]::Build(')
    $source=$source.Replace('$PSScriptRoot',("'"+$tests.Replace("'","''")+"'"))
    & ([scriptblock]::Create($source))
}else {
    $null=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath((Join-Path $HelperDirectory 'DiskHelper.exe')))
    & (Join-Path $PSScriptRoot '../../tests/Test-MftScanner.ps1')
}
if(-not $?){throw 'Shared MFT regression tests failed.'}
