$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$exe=Join-Path $env:WINDIR 'System32\cmd.exe'
Assert ((Test-PcLaunchPath ('"'+$exe+'" /c echo test') -CommandLine).Status -eq 'FOUND') 'Quoted command resolves without execution'
Assert ((Test-PcLaunchPath 'C:\Program Files\Example\tool.exe /arg' -CommandLine).Status -eq 'UNVERIFIED') 'Ambiguous unquoted path is not guessed'
Assert ((Test-PcLaunchPath '%USERPROFILE%\tool.exe').Status -eq 'UNVERIFIED') 'Run-as dependent environment is not expanded as current user'
Assert ((Test-PcLaunchPath '\\server\share\tool.exe').Status -eq 'UNVERIFIED') 'Network paths are not probed'
Assert ((Test-PcLaunchPath 'powershell.exe').Status -eq 'UNVERIFIED') 'Relative PATH resolution is not assumed'
Assert ((Test-PcLaunchPath (Join-Path $env:TEMP ([guid]::NewGuid().ToString('N')+'.exe'))).Status -eq 'MISSING') 'Definite local missing path is flagged'
foreach($code in @(267008,267009,267010,267011,267012,267013,267016,267045)){Assert ((Get-PcTaskResult $code (Get-Date)).Status -eq 'INFO') "Scheduler status $code is not a failure"}
Assert ((Get-PcTaskResult 0 (Get-Date)).Status -eq 'OK') 'Zero last result is successful'
Assert ((Get-PcTaskResult 0 ([datetime]'1999-11-30')).Status -eq 'INFO') 'Never-run timestamp is not success'
Assert ((Get-PcTaskResult ([long]2147750675) (Get-Date)).Status -eq 'REVIEW') 'Unsigned HRESULT does not overflow Int32'
Assert ((Get-PcTaskResult (-1073741510) (Get-Date)).Hex -eq '0xC000013A') 'Signed results normalize to unsigned hexadecimal'
function Get-CimInstance {param($ClassName,$OperationTimeoutSec,$ErrorAction) [pscustomobject]@{Name='Startup fixture';Command=('"'+$exe+'" /c test');Location='Fixture';User='TEST'}}
Assert ((@(Get-PcStartupEntries))[0].State -eq 'Enabled state not determined') 'Startup inventory does not claim enabled state'
function Get-ScheduledTask {
 [CmdletBinding()]param()
 foreach($name in @('OK','Denied','COM')){[pscustomobject]@{TaskName=$name;TaskPath='\Fixture\';State='Ready';Principal=[pscustomobject]@{UserId='TEST'};Actions=@([pscustomobject]@{Execute=$(if($name -eq 'COM'){''}else{$exe});Arguments='';WorkingDirectory='';ClassId='Fixture'});Triggers=@()}}
}
function Get-ScheduledTaskInfo {
 [CmdletBinding()]param([Parameter(ValueFromPipeline=$true)]$InputObject)
 process{if($InputObject.TaskName -eq 'Denied'){throw 'Fixture access denied'};[pscustomobject]@{LastTaskResult=0;LastRunTime=(Get-Date);NextRunTime=(Get-Date).AddHours(1);NumberOfMissedRuns=0}}
}
$rows=@(Get-PcScheduledTaskEntries)
Assert ($rows.Count -eq 3 -and ($rows | Where-Object Name -eq Denied).Status -eq 'UNAVAILABLE') 'Per-task access failure preserves other tasks'
Assert (($rows | Where-Object Name -eq COM).Paths -match 'UNVERIFIED') 'COM actions are not labelled missing executables'
$taskColorItem=New-PcStartupTaskMenuItem ($rows | Where-Object Name -eq OK) Task
Assert (($taskColorItem.LabelParts | Where-Object Text -EQ OK).Color -eq 'Green') 'Successful task status uses healthy colour'
Assert (($taskColorItem.LabelParts | Where-Object Text -EQ OK).Color -contains 'Cyan') 'Task name uses identifier colour'
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('Down','Select','','F','Fixture','C','R','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt $Prompt"};$script:Answers.Dequeue()}
function Test-PcMenuKeyboard {$false}
Start-PcStartupTaskBrowser Task
Assert ($script:Answers.Count -eq 0) 'Task navigation, details, name filter, review filter and refresh work'
$source=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN STARTUP TASKS',2)[1] -split '# END STARTUP TASKS',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Startup-Tasks.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded module matches source'
