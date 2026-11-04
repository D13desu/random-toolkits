$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
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

# Submenu navigation and recovery after a failed action.
$script:FakeComputer.DomainRole = 1
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'
foreach ($answer in @('4','dc.example.test','','0')) { $script:Answers.Enqueue($answer) }
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw 'Unexpected prompt' }; $script:Answers.Dequeue() }
Start-AdMenu
Assert-True ($script:Answers.Count -eq 0) 'AD menu recovers after access denied and returns on 0'
Write-Host "All AD checks passed on PowerShell $($PSVersionTable.PSVersion)."
