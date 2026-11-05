[CmdletBinding()]
param([string]$HelperDirectory)
$ErrorActionPreference='Stop'
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
if('RandomToolkits.DiskV10.Scanner' -as [type]){throw 'Run engine tests in a fresh PowerShell process.'}
$null=[Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath((Join-Path $HelperDirectory 'DiskHelper.exe')))
& (Join-Path $PSScriptRoot '../../tests/Test-MftScanner.ps1')
if(-not $?){throw 'Shared MFT regression tests failed.'}
