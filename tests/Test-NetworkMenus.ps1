$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
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
$detailFixture=[pscustomobject]@{Username='DOMAIN\User';Groups='Users, Operators, Extremely Long Group Name That Must Remain Fully Visible';GroupNames=@('Users','Operators','Extremely Long Group Name That Must Remain Fully Visible');Hostname='PC01';PrivateIp='192.0.2.10';PublicIp='198.51.100.20';Storage='100.0 GiB free / 500.0 GiB';DiskDetails=@('C: 100.0 GiB free / 500.0 GiB');Cpu='Fixture CPU';CpuCores='8';LogicalProcessors='16';Ram='16.0 GiB';OsVersion='Fixture Windows 10.0 (build 12345)';UserSid='S-1-5-21-fixture';AuthenticationType='Kerberos';Administrator='False';Manufacturer='Fixture Corp';Model='Fixture PC';Domain='example.test';DomainJoined='True';OsArchitecture='64-bit';LastBoot='2026-11-07 01:00:00';Uptime='0.02:00:00'}
$summaryLines=Format-PcSystemSummary $detailFixture
Assert-True ($summaryLines.Count -eq 4 -and ($summaryLines -join '|') -match 'Public IP: 198\.51\.100\.20' -and ($summaryLines -join '|') -match 'RAM: 16\.0 GiB') 'Main-menu system summary includes identity, network, hardware and OS details'
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
foreach ($answer in @('1','0','2','0','3','0','4','0','5','0','6','0','7','0','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0) 'Unified Windows menu navigates all seven sections and returns'
Assert-True (($script:Output -join '|') -match 'User: DOMAIN\\User \| Groups: Users' -and ($script:Output -join '|') -match 'Public IP: 198\.51\.100\.20') 'Windows main menu renders the cached system summary'
$script:Output.Clear()
foreach ($answer in @('14','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0 -and '  Extremely Long Group Name That Must Remain Fully Visible' -in $script:Output -and 'SID: S-1-5-21-fixture' -in $script:Output) 'Computer and user details show complete untruncated identity data'
$script:Output.Clear()
foreach ($answer in @('3','2','n','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and 'Apply this change? [y/N]' -in $script:Output) 'DNS repair stays in DNS and preserves yes/no cancellation'
Assert-True (($script:Output -join '|') -match 'Requires confirmation') 'Change actions are clearly identified'
$script:Output.Clear()
foreach ($answer in @('4','7','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and ($script:Output -join '|') -match 'No AD domain trust exists') 'Unavailable AD repair displays its reason'
Assert-True ('DC hostname [automatic discovery]' -notin $script:Output) 'Unavailable repair is blocked before collecting inputs'
Write-Output "Menu tests passed on PowerShell $($PSVersionTable.PSVersion)."

foreach ($answer in @('1','1','b','b','2','b','3','b','4','b','5','b','6','b','7','1','2','b','b','2','b','b','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
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
foreach ($answer in @('8','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0) 'Cleanup is reachable and returns to the Windows menu without deleting'
function Get-PcHealthDashboard {param([switch]$IncludeNetwork) [pscustomobject]@{CollectedAt=(Get-Date);Rows=@((New-PcHealthFinding INFO 'Fixture' 'Test dashboard' power))}}
foreach ($answer in @('9','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0) 'Health dashboard is reachable and returns to Windows menu'
foreach ($answer in @('10','B','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0) 'Startup and scheduled-task menu returns to Windows menu'
