$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Ui.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Elevated=$false;$script:Format='NTFS';$script:Type='Fixed'
function Test-HelperElevated {$script:Elevated}
function Get-HelperVolumeInfo {param($Root) [pscustomobject]@{IsReady=$true;DriveType=$script:Type;DriveFormat=$script:Format}}
Assert ((Get-HelperScanEngine 'C:\') -eq 'native') 'Unelevated NTFS uses native'
$script:Elevated=$true
Assert ((Get-HelperScanEngine 'C:\') -eq 'mft') 'Elevated fixed NTFS root uses MFT'
Assert ((Get-HelperScanEngine 'C:\Users') -eq 'native') 'Folder path uses native'
Assert ((Get-HelperScanEngine '\\server\share\') -eq 'native') 'UNC path never selects MFT'
$script:Format='exFAT'
Assert ((Get-HelperScanEngine 'D:\') -eq 'native') 'Non-NTFS uses native'
$script:Format='NTFS';$script:Type='Network'
Assert ((Get-HelperScanEngine 'Z:\') -eq 'native') 'Mapped network drive never selects MFT'
Assert ((Get-HelperScanEngine 'C:\' native) -eq 'native') 'Explicit native override preserved'
Assert ((Get-HelperScanEngine 'C:\' mft) -eq 'mft') 'Explicit MFT reaches scanner validation without silent fallback'
