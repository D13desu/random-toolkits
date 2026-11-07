$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Network-Discovery.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$db=[pscustomobject]@{Entries=@{'001122'='Large';'0011223'='Medium';'001122334'='Small'};RetrievedUtc='2026-01-01T00:00:00Z';Status='Test'}
Assert ((Resolve-DiscoveryOui '00-11-22-33-44-55' $db).Vendor -eq 'Small') 'Longest /36 prefix wins'
Assert ((Resolve-DiscoveryOui '0011.223F.4455' $db).Vendor -eq 'Medium') '/28 prefix and dotted MAC accepted'
Assert ((Resolve-DiscoveryOui '001122FF4455' $db).Vendor -eq 'Large') '/24 fallback'
foreach($mac in @('02:11:22:33:44:55','01:11:22:33:44:55','FF:FF:FF:FF:FF:FF','00:00:00:00:00:00','invalid')){
 Assert (-not (Resolve-DiscoveryOui $mac $db).Vendor) "No vendor inference for $mac"
}
Assert ((Resolve-DiscoveryOui '00:11:22:33:44:55' $null).MacStatus -eq 'Database unavailable') 'Offline without cache is explicit'
$rows=@('192.0.2.1','192.0.2.2','192.0.2.3','192.0.2.4','198.51.100.1') | ForEach-Object {[pscustomobject]@{Address=$_;Responded=$false}}
$neighbors=@(
 [pscustomobject]@{IPAddress='192.0.2.1';LinkLayerAddress='00-11-22-33-44-55';State='Stale';InterfaceIndex=2},
 [pscustomobject]@{IPAddress='192.0.2.2';LinkLayerAddress='00-11-22-33-44-55';State='Reachable';InterfaceIndex=2},
 [pscustomobject]@{IPAddress='192.0.2.2';LinkLayerAddress='00-11-22-FF-44-55';State='Reachable';InterfaceIndex=3},
 [pscustomobject]@{IPAddress='192.0.2.3';LinkLayerAddress='00-11-22-33-44-55';State='Incomplete';InterfaceIndex=2},
 [pscustomobject]@{IPAddress='192.0.2.4';LinkLayerAddress='02-11-22-33-44-55';State='Reachable';InterfaceIndex=2})
Add-DiscoveryMacInfo $rows $db $neighbors
Assert ($rows[0].Vendor -eq 'Small' -and $rows[0].MacNeighborState -eq 'Stale' -and -not $rows[0].Responded) 'Stale neighbor enrichment does not imply a live host'
Assert ($rows[1].MacStatus -eq 'Ambiguous neighbor entries' -and -not $rows[1].MAC) 'Conflicting interfaces are not guessed'
Assert (-not $rows[2].MAC -and -not $rows[4].MAC) 'Incomplete and routed/no-exact-match targets get no MAC'
Assert ($rows[3].MacStatus -like 'Locally administered*' -and -not $rows[3].Vendor) 'Local MAC remains visible without vendor'
$cache=Join-Path $env:TEMP ('oui-test-'+[guid]::NewGuid().ToString('N'))
$script:Downloads=0
function Invoke-WebRequest {
 param($Uri,$OutFile,$TimeoutSec,[switch]$UseBasicParsing,$ErrorAction)
 $script:Downloads++
 $registry='MA-L';$prefix='001122'
 if($Uri -like '*/oui28/*'){$registry='MA-M';$prefix='0011223'}
 if($Uri -like '*/oui36/*'){$registry='MA-S';$prefix='001122334'}
 [IO.File]::WriteAllText($OutFile,"Registry,Assignment,Organization Name,Organization Address`r`n$registry,$prefix,Fixture vendor,Test",[Text.UTF8Encoding]::new($false))
}
$loaded=Get-DiscoveryOuiDatabase $cache
Assert ($loaded.Entries.Count -eq 3 -and $script:Downloads -eq 3) 'All three registries downloaded and validated'
$again=Get-DiscoveryOuiDatabase $cache
Assert ($again.Entries.Count -eq 3 -and $script:Downloads -eq 3) 'Fresh cache avoids downloads'
(Get-Item (Join-Path $cache 'assignments.csv')).LastWriteTimeUtc=[datetime]::UtcNow.AddDays(-40)
(Get-Item (Join-Path $cache 'last-attempt.txt')).LastWriteTimeUtc=[datetime]::UtcNow.AddDays(-2)
function Invoke-WebRequest {param($Uri,$OutFile,$TimeoutSec,[switch]$UseBasicParsing,$ErrorAction) $script:Downloads++;throw 'Simulated offline'}
$stale=Get-DiscoveryOuiDatabase $cache
Assert ($stale.Entries.Count -eq 3 -and $stale.Status -like 'Stale*' -and $script:Downloads -eq 4) 'Failed refresh retains good cached assignments'
$again=Get-DiscoveryOuiDatabase $cache
Assert ($script:Downloads -eq 4) 'Failed downloads are not retried within 24 hours'
