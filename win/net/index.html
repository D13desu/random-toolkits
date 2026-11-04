# Random Toolkits | Windows Network 0.4.0
# Self-contained: local execution and irm ... | iex use the same source.
[CmdletBinding()]
param(
    [switch]$NoMenu,
    [string]$Check,
    [string]$Target = 'example.com',
    [ValidateRange(1,65535)][int]$Port = 443,
    [string]$DomainController
)

function Test-NetworkTarget {
    param([string]$Value)
    # Accept a hostname or IP address, never a URL, command argument, or expression.
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 253 -or
        $Value -match '[\s/\\]' -or $Value.StartsWith('-') -or
        [Uri]::CheckHostName($Value) -eq [UriHostNameType]::Unknown) {
        throw 'Enter a hostname or IP address only (for example example.com or 192.168.1.1).'
    }
}

function Test-NetworkTcp {
    param([string]$ComputerName, [ValidateRange(1,65535)][int]$RemotePort,
          [ValidateRange(100,30000)][int]$TimeoutMs = 3000)
    Test-NetworkTarget $ComputerName
    $client = New-Object System.Net.Sockets.TcpClient
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $pending = $null
    try {
        $pending = $client.BeginConnect($ComputerName, $RemotePort, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw 'Connection timed out (including name resolution).' }
        $client.EndConnect($pending)
        [pscustomobject]@{Test='TCP'; Target=$ComputerName; Port=$RemotePort; Status='PASS'; Milliseconds=$timer.ElapsedMilliseconds; Detail='TCP handshake succeeded; application/TLS health not tested.'}
    } catch {
        [pscustomobject]@{Test='TCP'; Target=$ComputerName; Port=$RemotePort; Status='WARN'; Milliseconds=$timer.ElapsedMilliseconds; Detail=$_.Exception.Message}
    } finally {
        $client.Close()
        if ($null -ne $pending) { $pending.AsyncWaitHandle.Close() }
        $timer.Stop()
    }
}

function Test-NetworkPing {
    param([string]$ComputerName)
    Test-NetworkTarget $ComputerName
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($ComputerName, 2000)
        $status = 'WARN'
        if ($reply.Status -eq 'Success') { $status = 'PASS' }
        [pscustomobject]@{Test='ICMP'; Target=$ComputerName; Status=$status; Milliseconds=$reply.RoundtripTime; Detail=[string]$reply.Status}
    } catch {
        [pscustomobject]@{Test='ICMP'; Target=$ComputerName; Status='WARN'; Milliseconds=$null; Detail=$_.Exception.Message}
    } finally { $ping.Dispose() }
}

function Get-NetworkOverview {
    foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        $properties = $adapter.GetIPProperties()
        [pscustomobject]@{
            Adapter=$adapter.Name; Description=$adapter.Description; State=[string]$adapter.OperationalStatus
            Type=[string]$adapter.NetworkInterfaceType; MAC=$adapter.GetPhysicalAddress().ToString()
            Addresses=(@($properties.UnicastAddresses | ForEach-Object { $_.Address.ToString() }) -join ', ')
            Gateways=(@($properties.GatewayAddresses | ForEach-Object { $_.Address.ToString() }) -join ', ')
            DNS=(@($properties.DnsAddresses | ForEach-Object { $_.ToString() }) -join ', ')
        }
    }
}

function Test-NetworkConnectivity {
    param([string]$ComputerName)
    $gateways = @([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.OperationalStatus -eq 'Up' } |
        ForEach-Object { $_.GetIPProperties().GatewayAddresses } |
        ForEach-Object { $_.Address.ToString() } |
        Where-Object { $_ -ne '0.0.0.0' -and $_ -ne '::' } | Select-Object -Unique)
    if ($gateways.Count -eq 0) {
        [pscustomobject]@{Test='Gateway'; Target='Local'; Status='WARN'; Detail='No gateway reported on active adapters; VPN or special routing may still work.'}
    }
    foreach ($gateway in $gateways) { Test-NetworkPing $gateway }
    Test-NetworkPing $ComputerName
    Test-NetworkTcp $ComputerName 443
}

function Get-NetworkDns {
    param([string]$ComputerName)
    Test-NetworkTarget $ComputerName
    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
        Resolve-DnsName -Name $ComputerName -ErrorAction Stop |
            Select-Object Name,Type,IPAddress,NameHost,TTL
    } else {
        # System resolver fallback does not expose record types or TTLs.
        [Net.Dns]::GetHostAddresses($ComputerName) | ForEach-Object {
            [pscustomobject]@{Name=$ComputerName; IPAddress=$_.ToString(); Resolver='System resolver fallback'}
        }
    }
}

function Get-NetworkRoutes {
    & route.exe print
    if ($LASTEXITCODE -ne 0) { throw "route.exe failed with exit code $LASTEXITCODE" }
}

function Get-NetworkProxy {
    Write-Host 'WinHTTP proxy (may differ from browser/user proxy):' -ForegroundColor Cyan
    & netsh.exe winhttp show proxy
    if ($LASTEXITCODE -ne 0) { throw "netsh.exe failed with exit code $LASTEXITCODE" }
    $settings = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    [pscustomobject]@{Scope='Current user Internet Settings'; ProxyEnabled=$settings.ProxyEnable; ProxyServer=$settings.ProxyServer; PAC=$settings.AutoConfigURL}
}

function Get-NetworkFirewall {
    Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction
}

function Get-AdContext {
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $role = 'Unknown'
        if ($null -ne $computer.DomainRole) {
            if ($computer.PartOfDomain -and [int]$computer.DomainRole -in @(4,5)) { $role = 'Domain controller' }
            elseif ($computer.PartOfDomain -and [int]$computer.DomainRole -in @(1,3)) { $role = 'Domain member' }
            elseif (-not $computer.PartOfDomain -and [int]$computer.DomainRole -in @(0,2)) { $role = 'Workgroup' }
        }
        [pscustomobject]@{Computer=$computer.Name; Domain=$computer.Domain; Role=$role; Detail='Local Windows domain membership (Entra join is not AD domain membership).'}
    } catch {
        [pscustomobject]@{Computer=$env:COMPUTERNAME; Domain=$null; Role='Unknown'; Detail=$_.Exception.Message}
    }
}

function Invoke-AdNative {
    param([string]$Command, [string[]]$Arguments)
    $output = & $Command @Arguments 2>&1
    $code = $LASTEXITCODE
    $status = 'PASS'
    if ($code -ne 0) { $status = 'WARN' }
    # Preserve localized output. Exit status is not proof of overall AD health.
    [pscustomobject]@{Test=$Command; Arguments=($Arguments -join ' '); Status=$status; ExitCode=$code; Detail=($output -join [Environment]::NewLine)}
}

function Get-AdController {
    param([string]$Requested)
    if ($Requested) {
        Test-NetworkTarget $Requested
        if ([Uri]::CheckHostName($Requested) -ne [UriHostNameType]::Dns) { throw 'Use a DC hostname, not an IP address, for authenticated domain checks.' }
        return $Requested
    }
    Add-Type -AssemblyName System.DirectoryServices -ErrorAction Stop
    $domainObject = $null
    $dcObject = $null
    try {
        $domainObject = [DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
        $dcObject = $domainObject.FindDomainController()
        $dcObject.Name
    } finally {
        if ($dcObject) { $dcObject.Dispose() }
        if ($domainObject) { $domainObject.Dispose() }
    }
}

function Get-AdDiscovery {
    param($Context)
    Test-NetworkTarget $Context.Domain
    Invoke-AdNative 'nltest.exe' @('/dsgetdc:' + $Context.Domain)
    Invoke-AdNative 'nltest.exe' @('/dsgetsite')
}

function Get-AdDns {
    param($Context)
    Test-NetworkTarget $Context.Domain
    foreach ($prefix in @('_ldap._tcp.dc._msdcs.', '_kerberos._tcp.')) {
        $name = $prefix + $Context.Domain
        try {
            $records = @(Resolve-DnsName -Name $name -Type SRV -DnsOnly -ErrorAction Stop | Where-Object { $_.Type -eq 'SRV' })
            if ($records.Count -eq 0) { throw 'No SRV records returned.' }
            foreach ($record in $records) {
                [pscustomobject]@{Test='AD SRV'; Query=$name; Status='PASS'; Target=$record.NameTarget; Port=$record.Port; Priority=$record.Priority; Weight=$record.Weight}
            }
            foreach ($dcName in @($records.NameTarget | Select-Object -Unique)) {
                try {
                    $addresses = @(Resolve-DnsName -Name $dcName -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress })
                    if ($addresses.Count -eq 0) { throw 'No address records returned.' }
                    [pscustomobject]@{Test='DC address'; Target=$dcName; Status='PASS'; Detail=($addresses.IPAddress -join ', ')}
                } catch { [pscustomobject]@{Test='DC address'; Target=$dcName; Status='WARN'; Detail=$_.Exception.Message} }
            }
        } catch { [pscustomobject]@{Test='AD SRV'; Query=$name; Status='WARN'; Detail=$_.Exception.Message} }
    }
}

function Test-AdSecureChannel {
    param([string]$Controller)
    # Recheck role even when called directly; this command is invalid on DCs.
    $context = Get-AdContext
    if ($context.Role -ne 'Domain member') { throw 'Secure-channel testing applies only to domain-member computers; not DCs, workgroups, or unknown roles.' }
    $parameters = @{ErrorAction='Stop'}
    if ($Controller) { $parameters.Server = Get-AdController $Controller }
    $healthy = Test-ComputerSecureChannel @parameters
    $status = 'WARN'
    if ($healthy) { $status = 'PASS' }
    $serverLabel = 'Automatically selected'
    if ($Controller) { $serverLabel = $Controller }
    [pscustomobject]@{Test='Computer secure channel'; Target=$serverLabel; Status=$status; Detail="Secure channel healthy: $healthy. No repair attempted."}
}

function Get-AdTime {
    param([string]$Controller)
    Invoke-AdNative 'w32tm.exe' @('/query','/source')
    Invoke-AdNative 'w32tm.exe' @('/query','/status')
    $dcName = Get-AdController $Controller
    Invoke-AdNative 'w32tm.exe' @('/stripchart',('/computer:' + $dcName),'/samples:3','/dataonly')
}

function Test-AdShares {
    param([string]$Controller)
    $dcName = Get-AdController $Controller
    foreach ($share in @('SYSVOL','NETLOGON')) {
        $path = '\\' + $dcName + '\' + $share
        try {
            $null = Get-Item -LiteralPath $path -ErrorAction Stop
            [pscustomobject]@{Test='Share access'; Target=$path; Status='PASS'; Detail='Share root accessible using current Windows credentials; contents/replication not validated.'}
        } catch {
            [pscustomobject]@{Test='Share access'; Target=$path; Status='WARN'; Detail=$_.Exception.Message}
        }
    }
}

function Get-AdChecks {
    @(
        [pscustomobject]@{Key='1'; Id='ad-context'; Name='Domain membership and machine role'; MinPS='5.0'; Commands=@('Get-CimInstance'); Admin=$false; Roles=@(); Action={param($c,$dc) $c}}
        [pscustomobject]@{Key='2'; Id='ad-discovery'; Name='DC discovery and AD site'; MinPS='5.0'; Commands=@('nltest.exe'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdDiscovery $c}}
        [pscustomobject]@{Key='3'; Id='ad-dns'; Name='AD LDAP / Kerberos SRV and DC addresses'; MinPS='5.0'; Commands=@('Resolve-DnsName'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdDns $c}}
        [pscustomobject]@{Key='4'; Id='ad-secure'; Name='Computer secure channel (no repair)'; MinPS='5.0'; Commands=@('Test-ComputerSecureChannel'); Admin=$false; Roles=@('Domain member'); Action={param($c,$dc) Test-AdSecureChannel $dc}}
        [pscustomobject]@{Key='5'; Id='ad-time'; Name='Time source / status and DC offset'; MinPS='5.0'; Commands=@('w32tm.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdTime $dc}}
        [pscustomobject]@{Key='6'; Id='ad-shares'; Name='SYSVOL and NETLOGON access'; MinPS='5.0'; Commands=@(); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Test-AdShares $dc}}
    )
}

function Get-AdAvailability {
    param($Entry, $Context)
    $base = Get-NetworkAvailability $Entry
    $reasons = @()
    if (-not $base.Available) { $reasons += $base.Reason }
    if ($Entry.Roles.Count -gt 0 -and $Context.Role -notin $Entry.Roles) {
        $reasons += "Requires $($Entry.Roles -join ' or '); detected: $($Context.Role)"
        if ($Context.Role -eq 'Workgroup') { $reasons += 'No AD domain trust exists to test or repair' }
    }
    [pscustomobject]@{Available=($reasons.Count -eq 0); Reason=($reasons -join '; ')}
}

function Invoke-AdCheck {
    param([string]$Id, [string]$Controller)
    $entry = Get-AdChecks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $entry) { throw "Unknown AD check: $Id" }
    $context = Get-AdContext
    $availability = Get-AdAvailability $entry $context
    if (-not $availability.Available) { throw $availability.Reason }
    & $entry.Action $context $Controller
}

function Start-AdMenu { Start-NetworkCategory -Id 'ad' }

function Get-NetworkRepairs {
    @(
        [pscustomobject]@{Key='1'; Id='flush-dns'; Name='Flush local DNS cache'; MinPS='5.0'; Commands=@('ipconfig.exe'); Admin=$true; Roles=@(); Impact='Clears cached DNS answers on this PC. Subsequent lookups query DNS again.'}
        [pscustomobject]@{Key='2'; Id='renew-dhcp'; Name='Renew IPv4 DHCP lease (select adapter)'; MinPS='5.0'; Commands=@('Get-CimInstance','Invoke-CimMethod'); Admin=$true; Roles=@(); Impact='Renews IPv4 DHCP on ONE adapter. IP/routes may change and remote access may disconnect. No release or static-IP change.'}
        [pscustomobject]@{Key='3'; Id='resync-time'; Name='Resynchronize local clock'; MinPS='5.0'; Commands=@('w32tm.exe'); Admin=$true; Roles=@(); Impact='Requests local clock synchronization using existing time configuration. May change system time; does not change time servers.'}
        [pscustomobject]@{Key='4'; Id='repair-trust'; Name='Repair AD computer secure channel'; MinPS='5.0'; Commands=@('Test-ComputerSecureChannel'); Admin=$true; Roles=@('Domain member'); Impact='Rebuilds this member PC/server trust channel with AD. Requires authorized domain credentials and DC connectivity. Does not join a workgroup PC to a domain.'}
    )
}

function Get-NetworkDhcpAdapters {
    Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE AND DHCPEnabled = TRUE' -ErrorAction Stop |
        Select-Object InterfaceIndex,Description,IPAddress
}

function Invoke-NetworkRepair {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)][string]$Id,
        [string]$Controller,
        [int]$InterfaceIndex = -1
    )
    $entry = Get-NetworkRepairs | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $entry) { throw "Unknown repair: $Id" }
    $context = Get-AdContext
    $availability = Get-AdAvailability $entry $context
    if (-not $availability.Available) { throw $availability.Reason }
    $targetLabel = $env:COMPUTERNAME
    $adapter = $null
    if ($Id -eq 'renew-dhcp') {
        if ($InterfaceIndex -lt 0) { throw 'Select a DHCP-enabled adapter by its InterfaceIndex.' }
        $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex = $InterfaceIndex" -ErrorAction Stop)
        if ($adapters.Count -ne 1 -or -not $adapters[0].DHCPEnabled -or -not $adapters[0].IPEnabled) {
            throw 'Selected adapter is unavailable, static, or not IP-enabled. No change made.'
        }
        $adapter = $adapters[0]
        $targetLabel += " / adapter $InterfaceIndex ($($adapter.Description))"
    }
    if ($Id -eq 'repair-trust') {
        # Resolve and retain the same controller for precheck, repair, and verification.
        $Controller = Get-AdController $Controller
        $targetLabel += " / domain $($context.Domain) / DC $Controller"
    }
    Write-Host "Action: $($entry.Name)" -ForegroundColor Yellow
    Write-Host "Target: $targetLabel"
    Write-Host $entry.Impact -ForegroundColor Yellow
    if (-not $PSCmdlet.ShouldProcess($targetLabel, $entry.Name)) { return }
    $confirmation = Read-Host 'Apply this change? [y/N]'
    if ([string]::IsNullOrWhiteSpace($confirmation) -or $confirmation.Trim() -notmatch '^(y|yes)$') {
        [pscustomobject]@{Action=$Id; Status='CANCELLED'; Detail='No changes made.'}
        return
    }
    # Recheck requirements after confirmation, including privilege and current machine role.
    $availability = Get-AdAvailability $entry (Get-AdContext)
    if (-not $availability.Available) { throw $availability.Reason }
    switch ($Id) {
        'flush-dns' {
            Invoke-AdNative 'ipconfig.exe' @('/flushdns')
        }
        'resync-time' {
            Invoke-AdNative 'w32tm.exe' @('/resync')
        }
        'renew-dhcp' {
            $current = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex = $InterfaceIndex" -ErrorAction Stop)
            if ($current.Count -ne 1 -or -not $current[0].DHCPEnabled -or -not $current[0].IPEnabled -or $current[0].SettingID -ne $adapter.SettingID) {
                throw 'Adapter configuration changed; select it again. No change made.'
            }
            $result = Invoke-CimMethod -InputObject $current[0] -MethodName RenewDHCPLease -ErrorAction Stop
            $status = 'WARN'
            $detail = 'DHCP renewal failed. Check adapter connectivity and DHCP service availability.'
            if ($result.ReturnValue -eq 0) { $status = 'PASS'; $detail = 'DHCP renewal completed. Re-run adapter overview to inspect addresses.' }
            elseif ($result.ReturnValue -eq 1) { $status = 'WARN'; $detail = 'Renewal reports success with reboot required. No automatic reboot performed.' }
            [pscustomobject]@{Action=$Id; Target=$targetLabel; Status=$status; ReturnCode=$result.ReturnValue; Detail=$detail}
        }
        'repair-trust' {
            $before = Test-AdSecureChannel $Controller
            if ($before.Status -eq 'PASS') {
                [pscustomobject]@{Action=$Id; Status='SKIPPED'; Detail='Secure channel is already healthy. No repair needed.'}
                return
            }
            $credential = Get-Credential -Message "Domain account authorized to repair $($context.Computer) in $($context.Domain)"
            if ($null -eq $credential) { throw 'Credential prompt cancelled. No repair attempted.' }
            try {
                if ((Get-AdContext).Role -ne 'Domain member') { throw 'Computer role changed. Repair blocked.' }
                $repaired = Test-ComputerSecureChannel -Repair -Server $Controller -Credential $credential -ErrorAction Stop
                if (-not $repaired) { throw 'Secure-channel repair reported failure. No automatic retry or domain rejoin attempted.' }
            } finally { $credential = $null }
            # Return the actual post-repair result rather than assuming repair means success.
            Test-AdSecureChannel $Controller
        }
    }
}

function Invoke-InteractiveRepair {
    param($Entry)
    $availability = Get-AdAvailability $Entry (Get-AdContext)
    if (-not $availability.Available) { throw $availability.Reason }
    $repairParameters = @{Id=$Entry.Id; Confirm=$false}
    if ($Entry.Id -eq 'repair-trust') {
        $answer = Read-Host 'DC hostname [automatic discovery]'
        if ($answer) { $repairParameters.Controller = $answer.Trim() }
    }
    if ($Entry.Id -eq 'renew-dhcp') {
        $adapters = @(Get-NetworkDhcpAdapters)
        if ($adapters.Count -eq 0) { throw 'No active DHCP-enabled IPv4 adapters found.' }
        $adapters | Format-Table -AutoSize | Out-Host
        $index = -1
        if (-not [int]::TryParse((Read-Host 'InterfaceIndex to renew'), [ref]$index) -or $index -notin $adapters.InterfaceIndex) { throw 'Choose an InterfaceIndex from the list.' }
        $repairParameters.InterfaceIndex = $index
    }
    Invoke-NetworkRepair @repairParameters
}
function Get-NetworkChecks {
    # Add entries here. Requirements are evaluated before displaying AND running a check.
    @(
        [pscustomobject]@{Key='1'; Id='overview'; Name='Adapter / IP / DNS overview'; MinPS='5.0'; Commands=@(); Admin=$false; Action={param($t,$p) Get-NetworkOverview}}
        [pscustomobject]@{Key='2'; Id='connectivity'; Name='Gateway + target ping / TCP 443'; MinPS='5.0'; Commands=@(); Admin=$false; Action={param($t,$p) Test-NetworkConnectivity $t}}
        [pscustomobject]@{Key='3'; Id='dns'; Name='DNS lookup (system resolver fallback)'; MinPS='5.0'; Commands=@(); Admin=$false; Action={param($t,$p) Get-NetworkDns $t}}
        [pscustomobject]@{Key='4'; Id='tcp'; Name='TCP port check'; MinPS='5.0'; Commands=@(); Admin=$false; Action={param($t,$p) Test-NetworkTcp $t $p}}
        [pscustomobject]@{Key='5'; Id='routes'; Name='IPv4 / IPv6 routing table'; MinPS='5.0'; Commands=@('route.exe'); Admin=$false; Action={param($t,$p) Get-NetworkRoutes}}
        [pscustomobject]@{Key='6'; Id='proxy'; Name='WinHTTP and current-user proxy'; MinPS='5.0'; Commands=@('netsh.exe'); Admin=$false; Action={param($t,$p) Get-NetworkProxy}}
        [pscustomobject]@{Key='7'; Id='firewall'; Name='Firewall profile status'; MinPS='5.0'; Commands=@('Get-NetFirewallProfile'); Admin=$false; Action={param($t,$p) Get-NetworkFirewall}}
        [pscustomobject]@{Key='8'; Id='quick'; Name='Quick check: overview, connectivity, DNS'; MinPS='5.0'; Commands=@(); Admin=$false; Action={param($t,$p)
            foreach ($id in @('overview','connectivity','dns')) {
                try { Invoke-NetworkCheck $id $t $p } catch { [pscustomobject]@{Test=$id; Status='WARN'; Detail=$_.Exception.Message} }
            }
        }}
    )
}

function Get-NetworkAvailability {
    param($Entry, [version]$Version = $PSVersionTable.PSVersion)
    $reasons = @()
    if ($Version -lt [version]$Entry.MinPS) { $reasons += "Requires PowerShell $($Entry.MinPS)+" }
    foreach ($command in $Entry.Commands) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { $reasons += "Missing $command" }
    }
    if ($Entry.Admin) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { $reasons += 'Requires administrator' }
    }
    [pscustomobject]@{Available=($reasons.Count -eq 0); Reason=($reasons -join '; ')}
}

function Invoke-NetworkCheck {
    param([string]$Id, [string]$ComputerName = 'example.com', [int]$RemotePort = 443)
    $entry = Get-NetworkChecks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $entry) { throw "Unknown check: $Id" }
    $availability = Get-NetworkAvailability $entry
    if (-not $availability.Available) { throw $availability.Reason }
    & $entry.Action $ComputerName $RemotePort
}

function Get-NetworkCategories {
    @(
        [pscustomobject]@{Key='1'; Id='overview'; Name='Overview and quick diagnosis'; Checks=@('overview','quick'); AdChecks=@(); Repairs=@()}
        [pscustomobject]@{Key='2'; Id='connectivity'; Name='Connectivity and adapters'; Checks=@('connectivity','tcp','overview'); AdChecks=@(); Repairs=@('renew-dhcp')}
        [pscustomobject]@{Key='3'; Id='dns'; Name='DNS'; Checks=@('dns'); AdChecks=@(); Repairs=@('flush-dns')}
        [pscustomobject]@{Key='4'; Id='ad'; Name='Active Directory and time'; Checks=@(); AdChecks=@('ad-context','ad-discovery','ad-dns','ad-secure','ad-time','ad-shares'); Repairs=@('repair-trust','resync-time')}
        [pscustomobject]@{Key='5'; Id='routing'; Name='Routing and proxy'; Checks=@('routes','proxy'); AdChecks=@(); Repairs=@()}
        [pscustomobject]@{Key='6'; Id='firewall'; Name='Firewall'; Checks=@('firewall'); AdChecks=@(); Repairs=@()}
    )
}

function Get-NetworkMenuItems {
    param($Category)
    $number = 1
    foreach ($kind in @('Check','AD','Repair')) {
        $ids = @()
        $registry = @()
        switch ($kind) {
            'Check' { $ids=$Category.Checks; $registry=@(Get-NetworkChecks) }
            'AD' { $ids=$Category.AdChecks; $registry=@(Get-AdChecks) }
            'Repair' { $ids=$Category.Repairs; $registry=@(Get-NetworkRepairs) }
        }
        foreach ($id in $ids) {
            $entry = $registry | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if (-not $entry) { throw "Menu references unknown action: $id" }
            [pscustomobject]@{Key=[string]$number; Kind=$kind; Entry=$entry}
            $number++
        }
    }
}

function Invoke-InteractiveCheck {
    param($Item)
    $entry = $Item.Entry
    if ($Item.Kind -eq 'Repair') { Invoke-InteractiveRepair $entry; return }
    if ($Item.Kind -eq 'AD') {
        $dcName = $null
        if ($entry.Id -in @('ad-secure','ad-time','ad-shares')) {
            $answer = Read-Host 'DC hostname [automatic discovery]'
            if ($answer) { $dcName = $answer.Trim() }
            if ($dcName) { $null = Get-AdController $dcName }
        }
        Invoke-AdCheck $entry.Id $dcName
        return
    }
    $probeTarget = 'example.com'
    $probePort = 443
    if ($entry.Id -in @('connectivity','dns','tcp','quick')) {
        $answer = Read-Host 'Target hostname or IP [example.com]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) { $probeTarget = $answer.Trim() }
        Test-NetworkTarget $probeTarget
    }
    if ($entry.Id -eq 'tcp') {
        $answer = Read-Host 'TCP port [443]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            if (-not [int]::TryParse($answer, [ref]$probePort) -or $probePort -lt 1 -or $probePort -gt 65535) { throw 'Port must be between 1 and 65535.' }
        }
    }
    Invoke-NetworkCheck $entry.Id $probeTarget $probePort
}

function Get-NetworkItemAvailability {
    param($Item,$Context)
    if ($Item.Kind -eq 'Check') { Get-NetworkAvailability $Item.Entry }
    else { Get-AdAvailability $Item.Entry $Context }
}

function Start-NetworkCategory {
    param([string]$Id)
    $category = Get-NetworkCategories | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $category) { throw "Unknown category: $Id" }
    while ($true) {
        $context = Get-AdContext
        Write-Host "`n WINDOWS NETWORK > $($category.Name.ToUpperInvariant())" -ForegroundColor Cyan
        if ($Id -eq 'ad') {
            Write-Host " $($context.Computer) | $($context.Role) | $($context.Domain)"
            if ($context.Role -eq 'Unknown') { Write-Warning $context.Detail }
        }
        $items = @(Get-NetworkMenuItems $category)
        $section = ''
        foreach ($item in $items) {
            $heading = 'CHECKS'
            $color = 'White'
            if ($item.Kind -eq 'Repair') { $heading = 'REPAIRS - require confirmation'; $color = 'Yellow' }
            if ($section -ne $heading) { Write-Host "`n $heading" -ForegroundColor $color; $section=$heading }
            $entry = $item.Entry
            $availability = Get-NetworkItemAvailability $item $context
            $label = "PS $($entry.MinPS)+"
            if ($entry.Admin) { $label += '; Admin' }
            if ($item.Kind -eq 'Repair') { $label += '; CHANGES SYSTEM' }
            if (-not $availability.Available) { $label += '; UNAVAILABLE'; $color='DarkGray' }
            Write-Host " [$($item.Key)] $($entry.Name) [$label]" -ForegroundColor $color
            if (-not $availability.Available) { Write-Host "     $($availability.Reason)" -ForegroundColor DarkGray }
        }
        Write-Host "`n [0] Back"
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        $item = $items | Where-Object { $_.Key -eq $answer.Trim() } | Select-Object -First 1
        if (-not $item) { Write-Warning 'Unknown selection'; continue }
        try {
            $availability = Get-NetworkItemAvailability $item (Get-AdContext)
            if (-not $availability.Available) { throw $availability.Reason }
            Invoke-InteractiveCheck $item | Format-List | Out-Host
        } catch { Write-Warning $_.Exception.Message }
        $null = Read-Host 'Press Enter to return'
    }
}

function Start-NetworkMenu {
    while ($true) {
        Write-Host "`n============================================" -ForegroundColor Cyan
        Write-Host ' RANDOM TOOLKITS | WINDOWS NETWORK 0.4.0' -ForegroundColor Cyan
        Write-Host " PowerShell $($PSVersionTable.PSVersion) | DIAGNOSE AND REPAIR"
        Write-Host '============================================' -ForegroundColor Cyan
        foreach ($category in Get-NetworkCategories) { Write-Host " [$($category.Key)] $($category.Name)" }
        Write-Host "`n [0] Exit"
        Write-Host 'Checks and repairs are grouped by topic. Repairs ask before making changes.' -ForegroundColor DarkGray
        $selection = Read-Host 'Select'
        if ($null -eq $selection -or $selection.Trim() -eq '0') { return }
        # Retain the former AD shortcut for existing users.
        if ($selection.Trim() -eq 'A') { Start-AdMenu; continue }
        $category = Get-NetworkCategories | Where-Object { $_.Key -eq $selection.Trim() } | Select-Object -First 1
        if (-not $category) { Write-Warning 'Unknown selection'; continue }
        Start-NetworkCategory $category.Id
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'Windows PowerShell 5.0+ is required (5.1 recommended).' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This toolkit requires Windows.' }
if ($Check -like 'ad-*') { Invoke-AdCheck $Check $DomainController }
elseif ($Check) { Invoke-NetworkCheck $Check $Target $Port }
elseif (-not $NoMenu) { Start-NetworkMenu }
