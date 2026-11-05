$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
Assert ((@(Get-DiscoveryTargets '192.168.1.7/30') -join ',') -eq '192.168.1.5,192.168.1.6') 'CIDR normalizes network and excludes network/broadcast'
Assert ((@(Get-DiscoveryTargets '192.168.1.0/31') -join ',') -eq '192.168.1.0,192.168.1.1') '/31 includes both endpoints'
Assert (@(Get-DiscoveryTargets '127.0.0.1/32').Count -eq 1) '/32 accepts a single host'
Assert (@(Get-DiscoveryTargets '192.168.1.254-192.168.2.1').Count -eq 4) 'Ranges cross octet boundaries'
foreach($scope in @('10.0.0.0/8','1.2.3.999','127.1','1.2.3.4-1.2.3.1','224.0.0.1','0.0.0.0','1.2.3.4;whoami')){$failed=$false;try{Get-DiscoveryTargets $scope | Out-Null}catch{$failed=$true};Assert $failed "Reject invalid scope $scope"}
Assert ((@(Get-DiscoveryPorts '80,443,80') -join ',') -eq '80,443') 'Port deduplication'
foreach($ports in @('0','65536','80;whoami',((1..17)-join ','))){$failed=$false;try{Get-DiscoveryPorts $ports | Out-Null}catch{$failed=$true};Assert $failed 'Reject invalid/oversized port list'}
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start()
$closed=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$closed.Start();$closedPort=$closed.LocalEndpoint.Port;$closed.Stop()
try{
 $result=Invoke-NetworkDiscovery -Scope '127.0.0.1' -Ports @($listener.LocalEndpoint.Port,$closedPort) -TimeoutMs 200 -Concurrency 2
 Assert ($result.Completed -eq 1 -and -not $result.Cancelled) 'Loopback scan completes'
 Assert ($result.Rows[0].OpenTCP -eq [string]$listener.LocalEndpoint.Port) 'Actual listening TCP port detected'
 Assert ($result.Rows[0].ClosedTCP -eq [string]$closedPort -or $result.Rows[0].NoResponseTCP -eq [string]$closedPort) 'Non-listening port is closed or unanswered, never reported open'
 Assert $result.Rows[0].Responded 'TCP response counts as host evidence'
}finally{$listener.Stop()}
function Read-DiscoveryCancelKey {'B'}
$cancelled=Invoke-NetworkDiscovery -Scope '127.0.0.1-127.0.0.4' -Ports 1 -Concurrency 1 -TimeoutMs 100
Assert ($cancelled.Cancelled -and $cancelled.Completed -lt $cancelled.Requested) 'B cancels queued work and returns explicitly partial results'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN NETWORK DISCOVERY',2)[1] -split '# END NETWORK DISCOVERY',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Discovery.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded module matches maintained source'
Assert ('discovery' -in (Get-NetworkMenuItems (Get-NetworkCategories | Where-Object Id -eq connectivity)).Entry.Id) 'Discovery reachable under connectivity'
$script:ExportPath=Join-Path $env:TEMP ('discovery-test-'+[guid]::NewGuid().ToString('N')+'.csv')
function Get-DiscoveryOuiDatabase {[pscustomobject]@{Entries=@{};RetrievedUtc='';Status='Test offline'}}
function Invoke-NetworkDiscovery {
 param($Scope,$Ports,$TimeoutMs)
 [pscustomobject]@{Scope=$Scope;Requested=2;Completed=1;Cancelled=$true;Rows=@([pscustomobject]@{Address='127.0.0.1';Responded=$true;Ping='Success';LatencyMs=0;OpenTCP='';ClosedTCP='';NoResponseTCP='1';ErrorTCP=''})}
}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('127.0.0.1','1','100','F','127.0.0.1','Select','Back','R','A','N','P','E',$script:ExportPath,'B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
Start-NetworkDiscovery
$csv=@(Import-Csv -LiteralPath $script:ExportPath)
Assert ($script:Answers.Count -eq 0 -and $csv.Count -eq 1 -and $csv[0].ScanCancelled -eq 'True' -and $csv[0].AddressesRequested -eq '2') 'Filtered navigation, details, rescan and CSV retain partial-scan context'
Remove-Item -LiteralPath $script:ExportPath
