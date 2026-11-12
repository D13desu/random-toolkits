$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert-True($Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$categories = @(Get-NetworkCategories)
$items = @($categories | ForEach-Object { Get-NetworkMenuItems $_ })
foreach ($entry in @((Get-NetworkChecks)) + @((Get-AdChecks)) + @((Get-NetworkRepairs))) {
    Assert-True ($entry.Id -in $items.Entry.Id) "Existing action remains reachable: $($entry.Id)"
}
function Get-AdContext { [pscustomobject]@{Computer='TEST';Role='Workgroup';Domain='WORKGROUP'} }
function Get-NetworkAvailability { param($Entry) [pscustomobject]@{Available=$true;Reason=''} }
function Invoke-AdNative { throw 'A cancelled menu action must never run a native command' }
function Get-NetRoute {param($AddressFamily,$DestinationPrefix,$ErrorAction) @([pscustomobject]@{InterfaceIndex=4;RouteMetric=20;InterfaceMetric=25;State='Alive'},[pscustomobject]@{InterfaceIndex=8;RouteMetric=5;InterfaceMetric=5;State='Alive'})}
function Get-NetIPAddress {param($AddressFamily,$InterfaceIndex,$ErrorAction) if($InterfaceIndex -eq 8){[pscustomobject]@{IPAddress='192.0.2.10';SkipAsSource=$false;AddressState='Preferred'}}else{[pscustomobject]@{IPAddress='198.18.0.4';SkipAsSource=$false;AddressState='Preferred'}}}
Assert-True ((Get-PcInternetPrivateIPv4) -eq '192.0.2.10') 'Main summary selects the source address on the lowest-cost IPv4 default route'
$detailFixture=[pscustomobject]@{SchemaVersion='0.28.2';Username='DOMAIN\User';Groups='Users, Operators, Extremely Long Group Name That Must Remain Fully Visible';GroupNames=@('Users','Operators','Extremely Long Group Name That Must Remain Fully Visible');Hostname='PC01';PrivateIp='192.0.2.10';PublicIp='198.51.100.20';Storage='100.0 GiB free / 500.0 GiB (20.0%)';StorageFreePercent='20.0%';DiskDetails=@('C: 100.0 GiB free / 500.0 GiB');Cpu='Fixture CPU';CpuLoad='12%';CpuCores='8';LogicalProcessors='16';Ram='16.0 GiB';RamUsage='4.0 / 16.0 GiB used (25.0%)';OsVersion='Fixture Windows 10.0 (build 12345)';SecuritySummary='Microsoft Defender 4.18.fixture | Real-time: On | Signatures: 1.fixture';UserSid='S-1-5-21-fixture';AuthenticationType='Kerberos';Administrator='False';Manufacturer='Fixture Corp';Model='Fixture PC';Domain='example.test';DomainJoined='True';JoinSummary='AD: example.test';Entra='Joined';Prt='Yes';Runtime='PowerShell 7.6.0 x64';RestartPending='No';NetworkPath=[pscustomobject]@{Adapter='Ethernet';LinkSpeed='1 Gbps';Gateway='192.0.2.1';Dns='192.0.2.53';Vpn='No';Proxy='Off'};Protection=[pscustomobject]@{Firewall='On';BitLocker='On';SecureBoot='On';Tpm='Ready';Vbs='Running'};OsArchitecture='64-bit';LastBoot='2026-11-07 01:00:00';Uptime='2h 00m'}
Assert-True (-not (Test-PcSystemSummaryCache ([pscustomobject]@{SchemaVersion='0.28.1'})) -and (Test-PcSystemSummaryCache $detailFixture)) 'Updated toolkit rejects stale summary schemas and retains current cached data'
$summaryLines=Format-PcSystemSummary $detailFixture
Assert-True ($summaryLines.Count -eq 8 -and ($summaryLines -join '|') -match 'Identity: DOMAIN\\User \| Admin: No \| PowerShell 7\.6\.0 x64' -and ($summaryLines -join '|') -match 'Network: Ethernet \| 1 Gbps' -and ($summaryLines -join '|') -match 'Public: 198\.51\.100\.20' -and ($summaryLines -join '|') -match 'Resources: CPU 12% \| RAM 4\.0 / 16\.0 GiB used' -and ($summaryLines -join '|') -match 'Restart pending: No' -and ($summaryLines -join '|') -match 'Protection: Firewall: On \| BitLocker: On') 'Main-menu summary includes identity, join, network path, resources, restart, security, and protection details'
$dsreg=ConvertFrom-PcDsRegStatus "AzureAdJoined : YES`r`nWorkplaceJoined : NO`r`nAzureAdPrt : YES`r`nDeviceAuthStatus : SUCCESS"
Assert-True ($dsreg.AzureAdJoined -eq 'YES' -and $dsreg.WorkplaceJoined -eq 'NO' -and $dsreg.AzureAdPrt -eq 'YES' -and $dsreg.DeviceAuthStatus -eq 'SUCCESS') 'Microsoft Entra device status parser extracts exact dsregcmd fields'
$workplaceOnly=ConvertTo-PcDeviceJoinHeader (ConvertFrom-PcDsRegStatus "AzureAdJoined : NO`r`nWorkplaceJoined : YES`r`nAzureAdPrt : NO`r`nDeviceAuthStatus : FAILED")
Assert-True ($workplaceOnly.Entra -eq 'No' -and $workplaceOnly.Prt -eq 'No') 'Workplace registration is not reported as Microsoft Entra device membership'
Assert-True ((Format-PcUptime ([timespan]::FromMinutes(9))) -eq '9m' -and (Format-PcUptime ([timespan]::new(2,3,4,0))) -eq '2d 03h 04m') 'Uptime uses compact minute, hour and day formatting'
$liveUptimeFixture=$detailFixture.PSObject.Copy();$liveUptimeFixture | Add-Member LastBootTime ((Get-Date).AddDays(-2).AddHours(-3).AddMinutes(-4))
Assert-True ((Get-PcSummaryUptime $liveUptimeFixture) -eq '2d 03h 04m') 'Cached dashboard data recalculates uptime instead of freezing the launch-time value'
$script:PcSystemSummary=$detailFixture
$script:Output = New-Object 'System.Collections.Generic.List[string]'
function Write-Host { param($Object,$ForegroundColor) $script:Output.Add([string]$Object) }
function Write-Warning { param($Message) $script:Output.Add([string]$Message) }
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:Output.Add($Prompt); $script:Answers.Dequeue() }
foreach ($category in @($categories | Where-Object { $_.Id -in @('overview','connectivity','dns','ad','routing','firewall') })) { $script:Answers.Enqueue($category.Key); $script:Answers.Enqueue('0') }
$script:Answers.Enqueue('0')
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0) 'Every network category returns to the network menu'
foreach ($answer in @('2','0','3','0','4','0','5','0','6','0','7','0','8','0','14','B','15','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0) 'Unified Windows menu navigates legacy, Security, and Update sections and returns'
$rootOutput=$script:Output -join '|'
Assert-True ($rootOutput -match 'Identity: DOMAIN\\User' -and $rootOutput -notmatch 'Groups:' -and $rootOutput -match 'Public: 198\.51\.100\.20' -and $rootOutput -match 'Protection: Firewall: On' -and $rootOutput -match 'Security: Microsoft Defender') 'Windows main menu omits groups while retaining the enriched system and security summary'
Assert-True ($rootOutput.IndexOf('[1] Computer and user details') -lt $rootOutput.IndexOf('[2] Network')) 'Computer and user details is root option 1 and appears first'
$script:Output.Clear()
foreach ($answer in @('1','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0 -and '  Extremely Long Group Name That Must Remain Fully Visible' -in $script:Output -and 'SID: S-1-5-21-fixture' -in $script:Output) 'Computer and user details show complete untruncated identity data'
$returnPrompt='Enter / Esc / Backspace / B: back'
$beforeReturnPrompts=@($script:Output | Where-Object {$_.Trim() -eq $returnPrompt}).Count
$script:DetailKeys=New-Object 'System.Collections.Generic.Queue[object]'
$script:DetailKeys.Enqueue([pscustomobject]@{Key='DownArrow';KeyChar=[char]0})
$script:DetailKeys.Enqueue([pscustomobject]@{Key='Enter';KeyChar=[char]13})
function Test-PcMenuKeyboard {$true}
function Read-PcMenuKey {if(-not $script:DetailKeys.Count){throw 'Unexpected detail key request'};$script:DetailKeys.Dequeue()}
Show-PcSystemDetails $detailFixture
$afterReturnPrompts=@($script:Output | Where-Object {$_.Trim() -eq $returnPrompt}).Count
Assert-True ($script:DetailKeys.Count -eq 0 -and $afterReturnPrompts -eq ($beforeReturnPrompts+1) -and -not @($script:Output | Where-Object {$_ -like 'Selection:*'}).Count) 'Details screen ignores navigation keys without duplicating its return prompt'
function Test-PcMenuKeyboard {$false}
$script:Output.Clear()
foreach ($answer in @('3','2','n','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and 'Apply this change? [y/N]' -in $script:Output) 'DNS repair stays in DNS and preserves yes/no cancellation'
Assert-True (($script:Output -join '|') -match '\[CHANGES SYSTEM\]') 'Change actions retain a concise warning badge'
$script:Output.Clear()
foreach ($answer in @('4','7','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and ($script:Output -join '|') -match 'No AD domain trust exists') 'Unavailable AD repair displays its reason'
Assert-True ('DC hostname [automatic discovery]' -notin $script:Output) 'Unavailable repair is blocked before collecting inputs'
Write-Output "Menu tests passed on PowerShell $($PSVersionTable.PSVersion)."

foreach ($answer in @('2','1','b','b','3','b','4','b','5','b','6','b','7','b','8','1','1','2','b','b','2','b','b','2','1','b','b','b','14','b','15','b','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0) 'B returns from every Windows section and cancels registry input'
foreach ($answer in @('1','b','b')) { $script:Answers.Enqueue($answer) }
Start-NetworkCategory connectivity
Assert-True ($script:Answers.Count -eq 0) 'B cancels target entry directly to its menu without running a check'
$script:Answers.Enqueue('0')
Assert-True ((Read-PcInput 'Event level') -eq '0') 'Numeric zero remains valid data input'
$script:Answers.Enqueue('')
Assert-True ((Read-PcInput 'Default input') -eq '') 'Blank data input preserves defaults'
function Invoke-InteractiveCheck { param($Item) }
foreach ($answer in @('1','2','b')) { $script:Answers.Enqueue($answer) }
Start-NetworkCategory storage
Assert-True ($script:Answers.Count -eq 0) 'Both disk tools return directly to Storage without an extra pause'
foreach ($answer in @('99','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0) 'Cleanup is reachable and returns to the Windows menu without deleting'
function Get-PcHealthDashboard {param([switch]$IncludeNetwork) [pscustomobject]@{CollectedAt=(Get-Date);Rows=@((New-PcHealthFinding INFO 'Fixture' 'Test dashboard' power))}}
foreach ($answer in @('9','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0) 'Health dashboard is reachable and returns to Windows menu'
foreach ($answer in @('10','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu -AllowCallerReturn
Assert-True ($script:Answers.Count -eq 0) 'Startup and scheduled-task menu returns to Windows menu'
