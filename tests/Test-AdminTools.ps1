$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert-True($Value,$Message) { if (-not $Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$script:Mode='ok'
function Get-WinEvent {
    [CmdletBinding()] param($FilterHashtable,$MaxEvents)
    $script:Filter=$FilterHashtable; $script:Limit=$MaxEvents
    if ($script:Mode -eq 'empty') { Write-Error 'No records' -ErrorId NoMatchingEventsFound -ErrorAction Stop }
    if ($script:Mode -eq 'denied') { throw 'Access denied by test' }
    [pscustomobject]@{TimeCreated=(Get-Date);Id=42;LevelDisplayName='Error';ProviderName='Test';LogName='System';RecordId=1;MachineName='TEST';Message='literal [example] message'}
    [pscustomobject]@{TimeCreated=(Get-Date);Id=43;LevelDisplayName='Warning';ProviderName='Test';LogName='System';RecordId=2;MachineName='TEST';Message='Other message'}
}
$rows=@(Get-PcEventRecords -LogName System -Hours 4 -Ids 42,43 -Levels 0,2 -Provider 'Test*' -Text '[example]' -Limit 50)
Assert-True ($rows.Count -eq 1 -and $rows[0].RecordId -eq 1) 'Message filtering is literal and preserves full details'
Assert-True ($script:Filter.Level -contains 0 -and $script:Filter.Id.Count -eq 2 -and $script:Filter.ProviderName -eq 'Test*' -and $script:Limit -eq 50) 'Server-side filter includes IDs, levels including 0, provider and cap'
Assert-True ($script:Filter.StartTime -gt (Get-Date).AddHours(-4.1)) 'Lookback is passed to event service'
$script:Mode='empty'
Assert-True (@(Get-PcEventRecords).Count -eq 0) 'No matches produces an empty result'
$script:Mode='denied'
$blocked=$false; try { Get-PcEventRecords } catch { $blocked=$_.Exception.Message -match 'Access denied' }
Assert-True $blocked 'Access errors are not misreported as no matches'
foreach ($bad in @('1,abc','-1','65536')) {
    $blocked=$false; try { ConvertTo-PcEventNumbers $bad 65535 } catch { $blocked=$true }
    Assert-True $blocked "Reject invalid event IDs: $bad"
}
$script:Mode='ok'
$script:Answers=New-Object 'System.Collections.Generic.Queue[string]'
foreach ($answer in @('','','','','','','','1','N','P','0')) { $script:Answers.Enqueue($answer) }
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:Answers.Dequeue() }
Start-PcEventBrowser
Assert-True ($script:Answers.Count -eq 0) 'Event browser filter prompts, detail, paging and exit work'

function Get-Printer { [CmdletBinding()] param() [pscustomobject]@{Name='OK'}; [pscustomobject]@{Name='Denied'} }
function Get-PrintJob { [CmdletBinding()] param($PrinterName) if ($PrinterName -eq 'Denied') { throw 'Queue access denied' }; [pscustomobject]@{ID=7;DocumentName='Test';UserName='test';JobStatus='Paused';SubmittedTime=(Get-Date);Size=10;TotalPages=1} }
$jobs=@(Get-PcPrintJobs)
Assert-True ($jobs.Count -eq 2 -and $jobs[0].Id -eq 7 -and $jobs[1].Detail -match 'denied') 'Printer queue errors preserve other queue results'
function Get-AdContext { [pscustomobject]@{Role='Workgroup';Computer='TEST'} }
function Get-NetworkAvailability { param($Entry) [pscustomobject]@{Available=$true;Reason=''} }
$script:Answer='n'
function Read-Host { param($Prompt) $script:Answer }
$script:Calls=New-Object 'System.Collections.Generic.List[string]'
function Invoke-AdNative { param($Command,$Arguments) $script:Calls.Add($Command+' '+($Arguments -join ' ')); [pscustomobject]@{ExitCode=0;Status='PASS'} }
$script:ServiceState='Running'
function Get-Service {
    [CmdletBinding()] param($Name)
    $service=[pscustomobject]@{Status=$script:ServiceState}
    $service | Add-Member ScriptMethod WaitForStatus { param($status,$timeout) if ($script:ServiceState -ne 'Running') { throw 'Service failed to start' } }
    $service
}
function Restart-Service { [CmdletBinding()] param($Name) $script:Calls.Add("Restart $Name"); $script:ServiceState='Running' }
function Start-Service { [CmdletBinding()] param($Name) $script:Calls.Add("Start $Name"); $script:ServiceState='Running' }
foreach ($id in @('restart-spooler','gp-refresh-user','gp-refresh-computer')) {
    $null=Invoke-NetworkRepair $id -Confirm:$false
    Assert-True ($script:Calls.Count -eq 0) "Cancellation blocks $id"
}
$script:Answer='yes'
$null=Invoke-NetworkRepair restart-spooler -Confirm:$false
$script:ServiceState='Stopped'
$null=Invoke-NetworkRepair restart-spooler -Confirm:$false
$null=Invoke-NetworkRepair gp-refresh-user -Confirm:$false
$null=Invoke-NetworkRepair gp-refresh-computer -Confirm:$false
Assert-True (($script:Calls -join '|') -eq 'Restart Spooler|Start Spooler|gpupdate.exe /target:user /force /wait:0|gpupdate.exe /target:computer /force /wait:0') 'Repairs target only spooler and selected policy scope, without reboot/logoff or queue deletion'
Write-Output "Admin-tool tests passed on PowerShell $($PSVersionTable.PSVersion); mutations mocked."
