$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Sysinternals-Launcher.ps1')
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message};Write-Output "PASS: $Message"}

$catalog=@(Get-PcSysinternalsLiveCatalog)
Assert ($catalog.Count -eq 10) 'Curated Sysinternals Live catalog has ten GUI tools'
Assert (@($catalog.Id|Select-Object -Unique).Count -eq $catalog.Count) 'Tool identifiers are unique'
Assert (-not ($catalog.Id -contains 'sysmon') -and -not ($catalog.Id -contains 'sdelete')) 'Service-installing and destructive tools are not one-click launchers'

$savedArchitecture=$env:PROCESSOR_ARCHITECTURE
$savedWow=$env:PROCESSOR_ARCHITEW6432
try{
 $env:PROCESSOR_ARCHITEW6432='';$env:PROCESSOR_ARCHITECTURE='AMD64'
 $x64=Get-PcSysinternalsLivePath procexp
 Assert ($x64.Path -eq '\\live.sysinternals.com\tools\procexp64.exe') 'x64 shortcut uses the official tools share and x64 binary'
 $env:PROCESSOR_ARCHITECTURE='ARM64'
 $arm=Get-PcSysinternalsLivePath procmon
 Assert ($arm.Path -eq '\\live.sysinternals.com\tools\ARM64\Procmon64a.exe') 'ARM64 shortcut uses the official ARM64 share folder'
 $env:PROCESSOR_ARCHITECTURE='x86'
 $x86=Get-PcSysinternalsLivePath autoruns
 Assert ($x86.Path -eq '\\live.sysinternals.com\tools\Autoruns.exe') 'x86 shortcut uses the x86 executable'
} finally {$env:PROCESSOR_ARCHITECTURE=$savedArchitecture;$env:PROCESSOR_ARCHITEW6432=$savedWow}

$script:Started=$null
function Start-Process {param($FilePath,$ArgumentList,$ErrorAction);$script:Started=$FilePath}
$env:PROCESSOR_ARCHITEW6432='';$env:PROCESSOR_ARCHITECTURE='AMD64'
Start-PcSysinternalsLiveTool tcpview
Assert ($script:Started -eq '\\live.sysinternals.com\tools\tcpview64.exe') 'Tool launcher passes the Microsoft UNC path directly to Start-Process'
$env:PROCESSOR_ARCHITECTURE=$savedArchitecture;$env:PROCESSOR_ARCHITEW6432=$savedWow

$toolkit=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Sysinternals-Launcher.ps1') -Raw
$embedded=($toolkit -split '# BEGIN SYSINTERNALS LAUNCHER',2)[1] -split '# END SYSINTERNALS LAUNCHER',2
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded Sysinternals launcher matches maintained source'
Assert ($toolkit -match "New-PcMenuItem '13' 'Microsoft Sysinternals Live'") 'Windows main menu exposes the Sysinternals Live section'
Assert ($toolkit -match "'13'\s*\{\s*Start-PcSysinternalsMenu\s*\}") 'Windows main menu dispatches to the Sysinternals Live section'
