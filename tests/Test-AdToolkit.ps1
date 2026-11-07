$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

# All domain operations below are mocked; no production AD is contacted.
function Get-CimInstance { param($ClassName,$ErrorAction) $script:FakeComputer }
foreach ($case in @(
    @{Joined=$false; Code=0; Expected='Workgroup'},
    @{Joined=$false; Code=2; Expected='Workgroup'},
    @{Joined=$true; Code=1; Expected='Domain member'},
    @{Joined=$true; Code=3; Expected='Domain member'},
    @{Joined=$true; Code=4; Expected='Domain controller'},
    @{Joined=$true; Code=5; Expected='Domain controller'},
    @{Joined=$true; Code=$null; Expected='Unknown'}
)) {
    $script:FakeComputer = [pscustomobject]@{Name='TEST'; Domain='example.test'; PartOfDomain=$case.Joined; DomainRole=$case.Code}
    Assert-True ((Get-AdContext).Role -eq $case.Expected) "Role detection: $($case.Expected) / $($case.Code)"
}
function Get-CimInstance { throw 'Access denied by test' }
Assert-True ((Get-AdContext).Role -eq 'Unknown') 'Access denied cannot be mistaken for workgroup/member'
function Get-CimInstance { param($ClassName,$ErrorAction) $script:FakeComputer }
$script:FakeComputer = [pscustomobject]@{Name='TEST'; Domain='example.test'; PartOfDomain=$true; DomainRole=1}

$secureEntry = Get-AdChecks | Where-Object Id -eq 'ad-secure'
$missing = [pscustomobject]@{MinPS='5.0'; Commands=@('Missing-AdTestCommand'); Admin=$false; Roles=@()}
Assert-True (-not (Get-AdAvailability $missing (Get-AdContext)).Available) 'AD menu marks missing dependencies unavailable'
foreach ($role in @('Workgroup','Domain controller','Unknown')) {
    Assert-True (-not (Get-AdAvailability $secureEntry ([pscustomobject]@{Role=$role})).Available) "Secure channel blocked for $role"
}
$script:SecureCalls = 0
function Test-ComputerSecureChannel {
    [CmdletBinding()] param([string]$Server, [switch]$Repair)
    if ($Repair) { throw 'Repair must never be invoked' }
    $script:SecureCalls++
    if ($script:SecureDenied) { throw 'Access denied by test' }
    $script:SecureHealthy
}
$script:SecureHealthy = $true
$script:SecureDenied = $false
Assert-True ((Invoke-AdCheck ad-secure 'dc.example.test').Status -eq 'PASS') 'Member secure-channel success'
$script:SecureHealthy = $false
Assert-True ((Invoke-AdCheck ad-secure).Status -eq 'WARN') 'Broken member channel produces warning without repair'
$script:SecureDenied = $true
$denied = $false
try { Invoke-AdCheck ad-secure } catch { $denied = $_.Exception.Message -match 'Access denied' }
Assert-True $denied 'Access denied remains an error, not a broken-trust result'
$script:FakeComputer.DomainRole = 5
$blocked = $false
try { Invoke-AdCheck ad-secure } catch { $blocked = $true }
Assert-True ($blocked -and $script:SecureCalls -eq 3) 'DC invocation blocked before secure-channel command'
$blocked = $false
try { Test-AdSecureChannel } catch { $blocked = $true }
Assert-True ($blocked -and $script:SecureCalls -eq 3) 'Direct helper also protects domain controllers'

foreach ($bad in @('https://dc.example.test','-bad','127.0.0.1','dc;whoami')) {
    $blocked = $false
    try { Get-AdController $bad } catch { $blocked = $true }
    Assert-True $blocked "Reject invalid DC hostname: $bad"
}

$script:NativeCalls = New-Object System.Collections.Generic.List[string]
function nltest.exe { $script:NativeCalls.Add('nltest ' + ($args -join ' ')); $script:LASTEXITCODE=0; 'Localized discovery output' }
function w32tm.exe { $script:NativeCalls.Add('w32tm ' + ($args -join ' ')); $script:LASTEXITCODE=0; 'Localized time output' }
$null = Get-AdDiscovery ([pscustomobject]@{Domain='example.test'})
$null = Get-AdTime 'dc.example.test'
Assert-True (($script:NativeCalls -join '|') -eq 'nltest /dsgetdc:example.test|nltest /dsgetsite|w32tm /query /source|w32tm /query /status|w32tm /stripchart /computer:dc.example.test /samples:3 /dataonly') 'Native diagnostic calls use only approved read-only arguments'
function nltest.exe { $script:LASTEXITCODE=5; 'Acceso denegado' }
$result = Invoke-AdNative 'nltest.exe' @('/dsgetsite')
Assert-True ($result.Status -eq 'WARN' -and $result.ExitCode -eq 5 -and $result.Detail -eq 'Acceso denegado') 'Native exit code and localized errors preserved'

function Resolve-DnsName {
    param($Name,$Type,[switch]$DnsOnly,$ErrorAction)
    if ($Name -like '_kerberos*') { throw 'DNS lookup failed by test' }
    if ($Type -eq 'SRV') { [pscustomobject]@{Type='SRV';NameTarget='dc.example.test';Port=389;Priority=0;Weight=100} }
    else { [pscustomobject]@{IPAddress='192.0.2.10'} }
}
$results = @(Get-AdDns ([pscustomobject]@{Domain='example.test'}))
Assert-True (@($results | Where-Object Status -eq 'PASS').Count -eq 2 -and @($results | Where-Object Status -eq 'WARN').Count -eq 1) 'Partial AD DNS failure preserves successful records'
function Get-Item {
    param($LiteralPath,$ErrorAction)
    if ($LiteralPath -like '*NETLOGON') { throw 'Access denied by test' }
    [pscustomobject]@{FullName=$LiteralPath}
}
$results = @(Test-AdShares 'dc.example.test')
Assert-True ($results.Count -eq 2 -and $results[0].Status -eq 'PASS' -and $results[1].Status -eq 'WARN') 'Shares checked independently with access errors preserved'

function whoami.exe { $script:LASTEXITCODE=0; 'Identity fixture' }
function klist.exe { $script:LASTEXITCODE=0; 'Kerberos fixture: ' + ($args -join ' ') }
$results = @(Get-AdIdentity)
Assert-True ($results.Count -eq 3 -and @($results | Where-Object Status -eq 'PASS').Count -eq 3) 'Identity, Kerberos tickets and sessions are read-only native checks'

function Test-NetworkTcp {
    param($ComputerName,$RemotePort,$TimeoutMs)
    $status=if($RemotePort -eq 636){'WARN'}else{'PASS'}
    [pscustomobject]@{Target=$ComputerName;Port=$RemotePort;Status=$status;Milliseconds=5;Detail='Port fixture'}
}
$results = @(Test-AdDcPorts 'dc.example.test')
Assert-True ($results.Count -eq 10 -and @($results | Where-Object {$_.Service -eq 'LDAPS' -and $_.Status -eq 'WARN'}).Count -eq 1) 'DC port matrix reports each AD service independently'

function Invoke-AdLdapRootDseRequest {
    [pscustomobject]@{Entries=@([pscustomobject]@{Attributes=@{
        dnsHostName=@('dc.example.test')
        defaultNamingContext=@('DC=example,DC=test')
        supportedLDAPVersion=@('3')
    }})}
}
$result = Get-AdRootDse 'dc.example.test'
Assert-True ($result.Status -eq 'PASS' -and $result.defaultNamingContext -eq 'DC=example,DC=test' -and $result.supportedLDAPVersion -eq '3') 'LDAP RootDSE exposes naming context and server capabilities'

$ids=@((Get-AdChecks).Id)
Assert-True (@('ad-identity','ad-ports','ad-rootdse' | Where-Object {$_ -notin $ids}).Count -eq 0) 'New AD checks are registered'

$script:DcHealthCalls=New-Object System.Collections.Generic.List[string]
function netdom.exe { $script:DcHealthCalls.Add('netdom ' + ($args -join ' '));$script:LASTEXITCODE=0;'FSMO fixture' }
function repadmin.exe { $script:DcHealthCalls.Add('repadmin ' + ($args -join ' '));$script:LASTEXITCODE=0;'Replication fixture' }
function dcdiag.exe { $script:DcHealthCalls.Add('dcdiag ' + ($args -join ' '));$script:LASTEXITCODE=0;'DCDiag fixture' }
$null=Get-AdFsmoRoles ([pscustomobject]@{Domain='example.test'})
$null=Get-AdReplicationHealth 'dc.example.test'
$dcdiagResults=@(Get-AdDcDiagnostics 'dc.example.test')
Assert-True ($script:DcHealthCalls[0] -eq 'netdom query /domain:example.test FSMO') 'FSMO discovery uses read-only netdom query'
Assert-True (($script:DcHealthCalls -join '|') -match 'repadmin /replsummary dc.example.test /bysrc /bydest /sort:delta\|repadmin /showrepl dc.example.test /all\|repadmin /queue dc.example.test') 'Replication health uses status-only repadmin commands'
Assert-True ($dcdiagResults.Count -eq 7 -and -not (($script:DcHealthCalls -join ' ') -match '/fix|/syncall|/replicate')) 'DCDiag runs selected read-only tests without repair or replication triggers'

function Get-WinEvent {
    param($ListLog,$ComputerName,$FilterHashtable,$MaxEvents,$ErrorAction)
    if ($ListLog) { return [pscustomobject]@{LogName=$ListLog} }
    if ($FilterHashtable.LogName -eq 'DNS Server') { return }
    [pscustomobject]@{TimeCreated=[datetime]'2026-01-01';ProviderName='Fixture';Id=42;LevelDisplayName='Warning';Message='Fixture event message'}
}
$eventResults=@(Get-AdEventSummary 'dc.example.test')
Assert-True ($eventResults.Count -eq 4 -and @($eventResults | Where-Object Status -eq 'PASS').Count -eq 1 -and @($eventResults | Where-Object Status -eq 'WARN').Count -eq 3) 'DC event summary keeps logs independent and reports empty windows cleanly'

$ids=@((Get-AdChecks).Id)
Assert-True (@('ad-fsmo','ad-replication','ad-dcdiag','ad-events' | Where-Object {$_ -notin $ids}).Count -eq 0) 'DC Health checks are registered'

function Get-ADUser {
    param($Identity,$Properties,$ErrorAction)
    [pscustomobject]@{SamAccountName=$Identity;UserPrincipalName="$Identity@example.test";Enabled=$true;LockedOut=$false;PasswordExpired=$false;PasswordNeverExpires=$false;PasswordLastSet=[datetime]'2026-01-01';LastBadPasswordAttempt=$null;BadPwdCount=0;LastLogonDate=[datetime]'2026-01-02';AccountExpirationDate=$null;DistinguishedName="CN=$Identity,DC=example,DC=test"}
}
function Get-ADComputer {
    param($Identity,$Properties,$ErrorAction)
    [pscustomobject]@{Name=$Identity;DNSHostName="$Identity.example.test";Enabled=$true;OperatingSystem='Windows';OperatingSystemVersion='10.0';LastLogonDate=[datetime]'2026-01-02';PasswordLastSet=[datetime]'2026-01-01';TrustedForDelegation=$false;TrustedToAuthForDelegation=$false;ServicePrincipalName=@("HOST/$Identity.example.test");DistinguishedName="CN=$Identity,DC=example,DC=test"}
}
$userResult=Invoke-AdCheck ad-user $null 'alice'
$computerResult=Invoke-AdCheck ad-computer $null 'PC01'
Assert-True ($userResult.SamAccountName -eq 'alice' -and $userResult.Enabled -and -not $userResult.LockedOut) 'Targeted user lookup returns diagnostic properties without mutation'
Assert-True ($computerResult.Name -eq 'PC01' -and $computerResult.ServicePrincipalNames -eq 'HOST/PC01.example.test') 'Targeted computer lookup returns OS, delegation, and SPN properties'
$blocked=$false;try{Get-AdUserDiagnostic "bad`nidentity"}catch{$blocked=$true}
Assert-True $blocked 'Targeted object lookup rejects control characters'

function nltest.exe { $script:LASTEXITCODE=0;'Site-A' }
function Get-ADReplicationSubnet { param($Filter,$Properties,$ErrorAction) [pscustomobject]@{Name='192.0.2.0/24';Site='CN=Site-A,CN=Sites,CN=Configuration,DC=example,DC=test'} }
function Get-NetIPAddress { param($AddressFamily,$ErrorAction) [pscustomobject]@{IPAddress='192.0.2.10';InterfaceAlias='Ethernet'};[pscustomobject]@{IPAddress='198.51.100.20';InterfaceAlias='VPN'} }
$siteResults=@(Get-AdSiteSubnetDiagnostic)
Assert-True ($siteResults.Count -eq 2 -and @($siteResults | Where-Object Status -eq 'PASS').Count -eq 1 -and @($siteResults | Where-Object {$_.Detail -match 'No matching'}).Count -eq 1) 'Site diagnostic uses longest subnet match and preserves unmapped adapters'

$script:SpnCalls=New-Object System.Collections.Generic.List[string]
function setspn.exe { $script:SpnCalls.Add($args -join ' ');$script:LASTEXITCODE=0;'SPN fixture' }
$null=Find-AdSpn 'HTTP/server.example.test';$null=Find-AdDuplicateSpn
Assert-True (($script:SpnCalls -join '|') -eq '-Q HTTP/server.example.test|-F -X') 'SPN tools expose exact query and forest-wide duplicate-scan modes only'
$blocked=$false;try{Find-AdSpn 'HTTP/*'}catch{$blocked=$true}
Assert-True $blocked 'Exact SPN lookup rejects wildcards'

function Get-DnsClientServerAddress { param($AddressFamily,$ErrorAction) [pscustomobject]@{InterfaceAlias='Ethernet';ServerAddresses=@('10.0.0.53','8.8.8.8')} }
function Resolve-DnsName { param($Server,$Name,$Type,[switch]$DnsOnly,$ErrorAction) [pscustomobject]@{Type='SRV';NameTarget='dc.example.test'} }
$dnsResults=@(Get-AdDnsClientQuality ([pscustomobject]@{Domain='example.test'}))
Assert-True ($dnsResults.Count -eq 2 -and @($dnsResults | Where-Object Status -eq 'PASS').Count -eq 1 -and @($dnsResults | Where-Object {$_.Status -eq 'WARN' -and $_.Server -eq '8.8.8.8'}).Count -eq 1) 'AD DNS quality tests every resolver and flags publicly routable configuration for review'

$ids=@((Get-AdChecks).Id)
Assert-True (@('ad-site-subnet','ad-user','ad-computer','ad-spn','ad-spn-duplicates','ad-dns-quality' | Where-Object {$_ -notin $ids}).Count -eq 0) 'AD object and Kerberos checks are registered'

# Submenu navigation and recovery after a failed action.
$script:FakeComputer.DomainRole = 1
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'
foreach ($answer in @('4','dc.example.test','','0')) { $script:Answers.Enqueue($answer) }
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw 'Unexpected prompt' }; $script:Answers.Dequeue() }
Start-AdMenu
Assert-True ($script:Answers.Count -eq 0) 'AD menu recovers after access denied and returns on 0'
Write-Host "All AD checks passed on PowerShell $($PSVersionTable.PSVersion)."
