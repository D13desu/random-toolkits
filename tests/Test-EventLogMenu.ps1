$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$choices=@(Get-PcEventLogChoices)
$expectedLogs=@(
 'ForwardedEvents','Windows PowerShell','Microsoft-Windows-PowerShell/Operational',
 'Microsoft-Windows-WLAN-AutoConfig/Operational','Microsoft-Windows-Wired-AutoConfig/Operational','Microsoft-Windows-NetworkProfile/Operational',
 'Microsoft-Windows-Hyper-V-VMMS/Admin','Microsoft-Windows-Hyper-V-Worker/Admin','Microsoft-Windows-Hyper-V-VmSwitch/Operational',
 'Microsoft-Windows-Hyper-V-Hypervisor/Admin','Microsoft-Windows-FailoverClustering/Operational',
 'Microsoft-Windows-TaskScheduler/Operational','Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
 'Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-BitLocker-API/Operational'
)
Assert (@($expectedLogs | Where-Object {$_ -notin $choices.Log}).Count -eq 0) 'Event presets include PowerShell, network, Hyper-V and high-value troubleshooting channels'
Assert (@($choices | Where-Object {[string]::IsNullOrWhiteSpace($_.Purpose)}).Count -eq 0) 'Every event preset explains its troubleshooting purpose'
$script:Queries=New-Object 'Collections.Generic.List[object]'
function Get-WinEvent {
 [CmdletBinding()]param($ListLog,$FilterHashtable,$MaxEvents)
 if($ListLog){return [pscustomobject]@{LogName=$ListLog;IsEnabled=($ListLog -ne 'Setup');RecordCount=1}}
 $script:Queries.Add([pscustomobject]@{Filter=$FilterHashtable;Limit=$MaxEvents})
 [pscustomobject]@{TimeCreated=(Get-Date);Id=42;LevelDisplayName='Information';ProviderName='Fixture';LogName=$FilterHashtable.LogName;RecordId=1;MachineName='TEST';Message='Test event'}
}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('1','R','F','B','B','2','B','3','B','4','C','','','','','','','','B','L','*','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
Start-PcEventLogMenu
Assert ($script:Answers.Count -eq 0) 'Common logs, refresh, filter cancellation, custom log, search and Back navigation'
Assert (($script:Queries.Filter.LogName -join ',') -eq 'Application,Application,System,Security,System') 'Presets query their exact logs and disabled log is not queried'
Assert (@($script:Queries | Where-Object {$_.Limit -ne 200 -or $_.Filter.ContainsKey('Level')}).Count -eq 0) 'Quick views include all event levels, including Security audit events'
$script:Answers.Enqueue('B')
function Get-PcEventRecords {param($LogName,$Hours,$Ids,$Levels,$Provider,$Text,$Limit)}
Start-PcEventBrowser -DefaultLog Application -Quick
Assert ($script:Answers.Count -eq 0) 'Empty results retain browser navigation'
$script:Answers.Enqueue('3');$script:Answers.Enqueue('B')
function Get-WinEvent {[CmdletBinding()]param($ListLog,$FilterHashtable,$MaxEvents) throw 'Access denied fixture'}
Start-PcEventLogMenu
Assert ($script:Answers.Count -eq 0) 'Access error returns to the log picker'
