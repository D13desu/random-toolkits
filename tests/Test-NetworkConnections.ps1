$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
Assert ((Format-PcSocketEndpoint '::1' 443) -eq '[::1]:443') 'IPv6 endpoints are unambiguous'
Assert ((Format-PcSocketEndpoint '127.0.0.1' 80) -eq '127.0.0.1:80') 'IPv4 endpoints retain numeric ports'
$script:UdpFails=$false;$script:Queries=0
function Get-NetTCPConnection {
 [CmdletBinding()]param()
 $script:Queries++
 foreach($state in @('Listen','Established','TimeWait')){[pscustomobject]@{LocalAddress='127.0.0.1';LocalPort=443;RemoteAddress='0.0.0.0';RemotePort=0;State=$state;OwningProcess=$(if($state -eq 'TimeWait'){0}else{42});CreationTime=[datetime]'2026-01-01'}}
 [pscustomobject]@{LocalAddress='::';LocalPort=80;RemoteAddress='::';RemotePort=0;State='Listen';OwningProcess=43;CreationTime=[datetime]'2026-01-01'}
}
function Get-NetUDPEndpoint {
 [CmdletBinding()]param()
 if($script:UdpFails){throw 'Fixture UDP access failure'}
 # Duplicate bound sockets must not break shared menu identity.
 foreach($i in 1..2){[pscustomobject]@{LocalAddress='::';LocalPort=5353;OwningProcess=99;CreationTime=[datetime]'2026-01-01'}}
}
function Get-CimInstance {
 param($ClassName,$Property,$OperationTimeoutSec,$ErrorAction)
 [pscustomobject]@{ProcessId=42;Name='fixture.exe';ExecutablePath='C:\fixture.exe';CreationDate=[datetime]'2025-01-01'}
 [pscustomobject]@{ProcessId=43;Name='reused.exe';ExecutablePath='C:\reused.exe';CreationDate=[datetime]'2026-02-01'}
}
$snapshot=Get-PcNetworkConnections
Assert ($snapshot.Rows.Count -eq 6 -and $snapshot.Issues.Count -eq 0) 'TCP and UDP collected once into snapshot'
Assert (@($snapshot.Rows.Id | Select-Object -Unique).Count -eq 6) 'Duplicate socket tuples retain unique row IDs'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 42 | Select-Object -First 1).ExecutablePath -eq 'C:\fixture.exe') 'PID maps to process path'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 43).ProcessName -eq 'PID reused / exited') 'Reused PID is not attributed to a newer process'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 0).ProcessName -eq 'Unattributed') 'PID zero is not labelled as an owning process'
Assert (@($snapshot.Rows | Where-Object {$_.Protocol -eq 'UDP' -and ($_.State -ne 'Bound' -or $_.RemoteEndpoint -ne '*')}).Count -eq 0) 'UDP does not invent TCP state or remote peer'
$colored=New-PcNetworkConnectionMenuItem ($snapshot.Rows | Where-Object ProcessId -EQ 42 | Select-Object -First 1)
Assert (($colored.LabelParts | Where-Object {$_.Text -eq '443'}).Color -eq 'Yellow') 'Connection ports use the port colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq 'fixture.exe'}).Color -eq 'Cyan') 'Process binary uses the binary colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq 'C:\fixture.exe'}).Color -eq 'Gray') 'Executable path uses the path colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq '42'}).Color -eq 'Magenta') 'PID uses the process identifier colour'
$script:UdpFails=$true;$partial=Get-PcNetworkConnections
Assert ($partial.Rows.Count -eq 4 -and $partial.Issues.Count -eq 1) 'UDP failure preserves TCP rows and reports incomplete collection'
$script:UdpFails=$false
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('L','Select','Back','E','Select','Back','T','F','5353','Select','Back','F','','A','T','R','C','Back','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
function Test-PcMenuKeyboard {$false}
$before=$script:Queries
Start-PcNetworkConnections
Assert ($script:Answers.Count -eq 0 -and $script:Queries -eq ($before+2)) 'Protocol/state filters, details, notes and refresh navigate without implicit rescans'
Assert ('connections' -in (Get-NetworkMenuItems (Get-NetworkCategories | Where-Object Id -EQ connectivity)).Entry.Id) 'Connections reachable in Connectivity menu'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN NETWORK CONNECTIONS',2)[1] -split '# END NETWORK CONNECTIONS',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Connections.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded connections module matches source'
