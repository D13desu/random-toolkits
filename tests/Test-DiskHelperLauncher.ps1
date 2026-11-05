[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PackagePath)
$ErrorActionPreference='Stop'
$PackagePath=[IO.Path]::GetFullPath($PackagePath)
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($value,$message){if(-not $value){throw $message};Write-Output "PASS: $message"}
$storage=Get-NetworkCategories | Where-Object Id -eq 'storage'
$items=@(Get-NetworkMenuItems $storage)
Assert ($items.Count -eq 2 -and $items[0].Entry.Id -eq 'disk' -and $items[1].Entry.Id -eq 'disk-helper') 'Production and experimental explorers are reachable in Storage'
$entry=$items[1].Entry
Assert ($entry.Admin -and $entry.MinPS -eq '5.1' -and $entry.Name -match '0.8.0') 'Experimental requirements and version are explicit'
Assert ((Get-NetworkAvailability $entry -Version '5.0').Reason -match 'Requires PowerShell 5.1') 'Older PowerShell is marked unavailable'
$runtimeFunction=(Get-Item Function:Get-PcDiskHelperRuntimeReason).ScriptBlock
function Get-PcDiskHelperRuntimeReason {'Requires test runtime'}
Assert ((Get-NetworkAvailability $entry).Reason -match 'Requires test runtime') 'Missing framework blocks the action'
Set-Item Function:Get-PcDiskHelperRuntimeReason $runtimeFunction
$pin=Get-PcDiskHelperPackage
Assert ((Get-FileHash -LiteralPath $PackagePath).Hash -eq $pin.Sha256) 'Pinned package hash matches the published test artifact'

# Exercise the actual packaged UI/helper handshake, then exit before scanning.
# Bypass only the admin gate: no scan or elevation is performed by this test.
function Get-NetworkAvailability {param($Entry) [pscustomobject]@{Available=$true;Reason=''}}
$probeState=[pscustomobject]@{Corrupt=$false;Extracts=0;Prompts=0;Work=$null}
function Invoke-WebRequest {param($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec,$ErrorAction)
    $probeState.Work=Split-Path $OutFile -Parent
    Copy-Item -LiteralPath $PackagePath -Destination $OutFile
    if($probeState.Corrupt){[IO.File]::AppendAllText($OutFile,'corrupt')}
}
function Expand-Archive {param($LiteralPath,$DestinationPath,$ErrorAction)
    $probeState.Extracts++
    Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $LiteralPath -DestinationPath $DestinationPath -ErrorAction Stop
}
function Read-Host {param($Prompt) $probeState.Prompts++;'0'}
Start-PcDiskHelper
Assert ($probeState.Prompts -eq 1 -and $probeState.Extracts -eq 1) 'Verified package starts the real helper and exits from drive selection'
Assert (-not (Test-Path -LiteralPath $probeState.Work)) 'Temporary package is removed after helper shutdown'
$probeState.Corrupt=$true;$rejected=$false
try {Start-PcDiskHelper}catch{$rejected=$_.Exception.Message -match 'checksum mismatch'}
Assert ($rejected -and $probeState.Extracts -eq 1 -and $probeState.Prompts -eq 1) 'Corrupt package is rejected before extraction or execution'
Assert (-not (Test-Path -LiteralPath $probeState.Work)) 'Rejected download is cleaned up'
function Get-NetworkAvailability {param($Entry) [pscustomobject]@{Available=$false;Reason='Blocked test requirement'}}
$rejected=$false
try {Start-PcDiskHelper}catch{$rejected=$_.Exception.Message -match 'Blocked test requirement'}
Assert $rejected 'Direct launcher invocation also enforces requirements'
