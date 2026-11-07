$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
function Invoke-NetworkRepair {throw 'Dashboard must not invoke repairs'}
function Get-CimInstance {
 param($ClassName,$Filter,$OperationTimeoutSec,$ErrorAction)
 switch($ClassName){
  'Win32_LogicalDisk'{[pscustomobject]@{DeviceID='C:';Size=100GB;FreeSpace=5GB};[pscustomobject]@{DeviceID='D:';Size=100GB;FreeSpace=50GB}}
  'Win32_Service'{[pscustomobject]@{Name='TriggerFixture';State='Stopped';ExitCode=0}}
  default{throw "Unexpected CIM query: $ClassName"}
 }
}
function Get-PhysicalDisk {[pscustomobject]@{FriendlyName='Fixture disk';HealthStatus='Healthy';OperationalStatus='OK'}}
function Test-Path {param($LiteralPath,$ErrorAction) return $LiteralPath -like '*RebootPending'}
function Get-PcEventRecords {param($LogName,$Hours,$Ids,$Provider,$Limit) if($LogName -eq 'Application'){[pscustomobject]@{Time='Fixture time';Message='Fixture crash'}}}
function Get-PcPowerOverview {[pscustomobject]@{Device='Laptop';ActivePlan='Balanced';Assessment='Fixture plan'}}
function Get-PcNicPower {[pscustomobject]@{Adapter='NIC';Status='Up';AllowComputerToTurnOffDevice='Enabled';SelectiveSuspend='Unsupported';DeviceSleepOnDisconnect='Disabled';Detail='Fixture'}}
function Get-NetworkOverview {[pscustomobject]@{Adapter='NIC';Description='Fixture Ethernet';State='Up';Type='Ethernet';Addresses='192.0.2.2';Gateways='192.0.2.1';DNS='192.0.2.1'};[pscustomobject]@{Adapter='Filter';Description='Fixture filter';State='Up';Type='Ethernet';Addresses='';Gateways='';DNS=''};[pscustomobject]@{Adapter='vEthernet (Fixture)';Description='Hyper-V Virtual Ethernet Adapter';State='Up';Type='Ethernet';Addresses='172.20.0.1';Gateways='';DNS=''};[pscustomobject]@{Adapter='Quantum Ethernet';Description='Fixture physical adapter';State='Up';Type='Unknown';Addresses='192.0.2.3';Gateways='';DNS=''}}
$script:Role='Workgroup';$script:TrustCalls=0
function Get-AdContext {[pscustomobject]@{Computer='TEST';Role=$script:Role;Domain='localhost';Detail='Fixture role'}}
function Test-AdSecureChannel {$script:TrustCalls++;[pscustomobject]@{Status='WARN';Detail='Fixture trust result'}}
function Test-NetworkPing {param($ComputerName) [pscustomobject]@{Status='PASS';Detail='Fixture reply'}}
$snapshot=Get-PcHealthDashboard
Assert (($snapshot.Rows | Where-Object Title -eq 'C: free space').Status -eq 'WARN') 'Low-space finding is actionable'
Assert (($snapshot.Rows | Where-Object Title -eq 'D: free space').Status -eq 'PASS') 'Adequate space passes its measured threshold'
Assert (($snapshot.Rows | Where-Object Title -eq 'Power plan: Balanced').Status -eq 'INFO') 'Balanced is informational, not a false fault'
Assert (($snapshot.Rows | Where-Object Title -like '*automatic services not running').Status -eq 'REVIEW') 'Stopped automatic service with zero exit code is review only'
Assert (($snapshot.Rows | Where-Object Title -like 'Application crash events*').Status -eq 'REVIEW') 'Historical crash does not claim an unresolved current failure'
Assert ($snapshot.Rows[0].Status -eq 'WARN' -and $script:TrustCalls -eq 0) 'Findings prioritized and local collection performs no trust test'
Assert (($snapshot.Rows | Where-Object Title -like '*active interfaces without IP addresses').Status -eq 'INFO') 'Unaddressed filter interfaces are grouped without false fault alerts'
Assert (($snapshot.Rows | Where-Object Title -eq 'NIC sleep: NIC').Status -eq 'INFO') 'Supported NIC power saving is context, not a health warning'
Assert (($snapshot.Rows | Where-Object Title -eq 'Network: vEthernet (Fixture)').Status -eq 'INFO') 'Virtual adapters without gateways remain informational'
Assert (($snapshot.Rows | Where-Object Title -eq 'Network: Quantum Ethernet').Status -eq 'REVIEW') 'Unknown or coincidentally named physical adapters are not assumed virtual'
function Get-PhysicalDisk {throw 'Fixture storage provider unavailable'}
$failed=Get-PcHealthDashboard
Assert (($failed.Rows | Where-Object Title -eq 'Storage health').Status -eq 'UNAVAILABLE' -and $failed.Rows.Count -gt 5) 'One unavailable provider does not abort remaining checks'
$trust=Get-PcHealthProbes -IncludeNetwork | Where-Object Name -eq 'AD secure channel'
foreach($role in @('Workgroup','Domain controller')){$script:Role=$role;$null=& $trust.Run}
Assert ($script:TrustCalls -eq 0) 'No member trust test on workgroups or DCs'
$script:Role='Domain member';$result=& $trust.Run
Assert ($script:TrustCalls -eq 1 -and $result.Status -eq 'WARN') 'Explicit live member trust probe surfaces its result without repair'
$dns=Get-PcHealthProbes -IncludeNetwork | Where-Object Name -eq 'DNS resolution'
Assert ((& $dns.Run).Status -eq 'PASS') 'Live system-resolver probe succeeds against localhost without external DNS'
$script:Role='Unknown'
Assert ((& $trust.Run).Status -eq 'UNAVAILABLE' -and $script:TrustCalls -eq 1) 'Unknown domain role is unavailable, never a trusted/pass result'
$script:Routes=New-Object 'Collections.Generic.List[string]'
function Start-NetworkCategory {param($Id) $script:Routes.Add($Id)}
function Start-PcEventBrowser {param($DefaultLog,[switch]$Quick) $script:Routes.Add('log:'+$DefaultLog)}
Open-PcHealthTarget 'log:Application'
Assert ($script:Routes[0] -eq 'log:Application') 'Event findings open the matching log'
function Get-PcHealthDashboard {param([switch]$IncludeNetwork) [pscustomobject]@{CollectedAt=(Get-Date);Rows=@((New-PcHealthFinding INFO 'First' 'Details' storage),(New-PcHealthFinding REVIEW 'Second' 'Details' power))}}
$healthColorItem=New-PcHealthMenuItem (New-PcHealthFinding REVIEW 'Colour fixture' 'Details' power) fixture
Assert (($healthColorItem.LabelParts | Where-Object Text -EQ REVIEW).Color -eq 'Yellow') 'Health review status uses warning colour'
Assert ($healthColorItem.SearchText -eq 'Details' -and -not $healthColorItem.Detail) 'Dashboard keeps details searchable without rendering them inline'
function Test-PcMenuKeyboard {$false}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('Down','Select','1','R','A','C','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
Start-PcHealthDashboard
Assert ($script:Answers.Count -eq 0 -and $script:Routes[-1] -eq 'power') 'Selection, linked tools, refresh, explicit live checks and Back work'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN HEALTH DASHBOARD',2)[1] -split '# END HEALTH DASHBOARD',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/Health-Dashboard.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded dashboard matches maintained module'

function Get-PcHealthDashboard {param([switch]$IncludeNetwork) [pscustomobject]@{CollectedAt=(Get-Date);Rows=@((New-PcHealthFinding INFO 'Same disk model' 'Disk 0' storage),(New-PcHealthFinding INFO 'Same disk model' 'Disk 1' storage))}}
$script:Answers.Enqueue('B')
Start-PcHealthDashboard
Assert ($script:Answers.Count -eq 0) 'Identical hardware display names remain distinct browser rows'
