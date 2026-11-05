# Random Toolkits | Windows Toolkit 0.6.5
# Self-contained: local execution and irm ... | iex use the same source.
[CmdletBinding()]
param(
    [switch]$NoMenu,
    [string]$Check,
    [string]$Target = 'example.com',
    [ValidateRange(1,65535)][int]$Port = 443,
    [string]$DomainController
)

function Get-PcRegistryTweak {
    param([ValidateSet('outlook','rdp')][string]$Id)
    if ($Id -eq 'outlook') {
        [pscustomobject]@{Path='HKCU:\Software\Microsoft\Office\16.0\Outlook\PST';RegPath='HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\PST';Names=@('MaxLargeFileSize','WarnLargeFileSize');Admin=$false}
    } else {
        [pscustomobject]@{Path='HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';RegPath='HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';Names=@('RedirectionWarningDialogVersion');Admin=$true}
    }
}

function Get-PcRegistryValues {
    param($Tweak)
    $key = Get-Item -LiteralPath $Tweak.Path -ErrorAction SilentlyContinue -ErrorVariable registryError
    if ($registryError -and $registryError[0].CategoryInfo.Category -ne 'ObjectNotFound') { throw $registryError[0] }
    foreach ($name in $Tweak.Names) {
        $exists = $null -ne $key -and $key.GetValueNames() -contains $name
        if ($exists -and $key.GetValueKind($name) -ne 'DWord') { throw "$name is not REG_DWORD; inspect it manually before changing." }
        [pscustomobject]@{Name=$name;Exists=$exists;Value=$(if ($exists) { $key.GetValue($name) } else { $null })}
    }
}

function Invoke-PcRegistryTweak {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([ValidateSet('outlook','rdp')][string]$Id,
        [ValidateRange(1,1000)][int]$SizeGB=100, [switch]$Reset)
    $tweak = Get-PcRegistryTweak $Id
    $availability = Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$tweak.Admin})
    if (-not $availability.Available) { throw $availability.Reason }
    if ($Id -eq 'outlook') {
        Write-Host "Classic Outlook Office 16.0, current account: $([Environment]::UserName). Close Outlook first."
        Write-Host 'Local Unicode PST/OST files only; does not increase Exchange/M365 mailbox quotas or configure new Outlook.'
        Write-Host 'Above 50 GB can reduce performance. WarnLargeFileSize is a data threshold, not a warning popup.'
        if (Get-Process -Name OUTLOOK -ErrorAction SilentlyContinue) { throw 'Close classic Outlook before applying or resetting limits.' }
        $policy = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\PST'
        $policyValues = @(Get-PcRegistryValues ([pscustomobject]@{Path=$policy;Names=$tweak.Names}))
        if (@($policyValues | Where-Object Exists).Count) { throw 'Outlook size policy is configured. Ask its administrator to change it; preferences may be overridden.' }
        $values = @(($SizeGB * 1024), ([int][math]::Floor($SizeGB * 1024 * 0.95)))
    } else {
        Write-Host 'Machine-wide RDP file redirection warning: restore the older dialog for trusted connections only.'
        Write-Host 'Reduces the newer per-resource consent protection. Does not disable NLA or certificate checks.'
        Write-Host 'Temporary compatibility setting; a future Windows update may remove it. Prefer trusted, signed RDP files.'
        $values = @(1)
    }
    $before = @(Get-PcRegistryValues $tweak)
    Write-Host $tweak.Path
    $before | Format-Table Name,Exists,Value -AutoSize | Out-Host
    if ($Reset) { Write-Host 'Remove these overrides and use application/Windows defaults. Existing large Outlook files may then exceed the default limit.' }
    else {
        for ($i=0; $i -lt $tweak.Names.Count; $i++) { Write-Host "$($tweak.Names[$i]) = $($values[$i]) (REG_DWORD, decimal)" }
    }
    if (-not $PSCmdlet.ShouldProcess($tweak.Path,'Change registry values and save undo file')) { return }
    if ((Read-Host 'Apply this change? [y/N]') -notmatch '^(?i:y|yes)$') { Write-Host 'Cancelled.'; return }
    $backupDir = Join-Path $env:LOCALAPPDATA 'Random-Toolkits\registry-backups'
    $null = New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop
    $backup = Join-Path $backupDir ("{0}-{1}.reg" -f $Id,[guid]::NewGuid().ToString('N'))
    $lines = @('Windows Registry Editor Version 5.00','',('['+$tweak.RegPath+']'))
    foreach ($row in $before) {
        if ($row.Exists) { $lines += ('"{0}"=dword:{1:x8}' -f $row.Name,[int]$row.Value) }
        else { $lines += ('"{0}"=-' -f $row.Name) }
    }
    $lines + '' | Set-Content -LiteralPath $backup -Encoding Unicode -ErrorAction Stop
    Write-Host "Undo file: $backup (import with regedit using this same account; RDP requires administrator)."
    try {
        if (-not $Reset) { $null = New-Item -Path $tweak.Path -Force -ErrorAction Stop }
        for ($i=0; $i -lt $tweak.Names.Count; $i++) {
            if ($Reset) {
                if ($before[$i].Exists) { Remove-ItemProperty -LiteralPath $tweak.Path -Name $tweak.Names[$i] -ErrorAction Stop }
            } else { $null = New-ItemProperty -LiteralPath $tweak.Path -Name $tweak.Names[$i] -Value $values[$i] -PropertyType DWord -Force -ErrorAction Stop }
        }
        $after = @(Get-PcRegistryValues $tweak)
        for ($i=0; $i -lt $after.Count; $i++) {
            if (($Reset -and $after[$i].Exists) -or (-not $Reset -and (-not $after[$i].Exists -or $after[$i].Value -ne $values[$i]))) { throw 'Registry read-back did not match the requested change.' }
        }
        Write-Host 'Registry values verified. Reopen Outlook / start a new RDP connection to use the setting.'
    } catch { throw "Change failed or was partially applied: $($_.Exception.Message) Restore previous values with $backup" }
}

function Start-PcRegistryMenu {
    while ($true) {
        Write-Host "`nREGISTRY TWEAKS | PowerShell 5.0+"
        Write-Host ' [1] Inspect Outlook and RDP values'
        Write-Host ' [2] Set classic Outlook PST/OST size (current account) - CHANGES SYSTEM'
        Write-Host ' [3] Reset Outlook size overrides - CHANGES SYSTEM'
        Write-Host ' [4] Restore older RDP warning (administrator) - CHANGES SYSTEM'
        Write-Host ' [5] Reset RDP warning override (administrator) - CHANGES SYSTEM'
        Write-Host ' [0] Back'
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        try {
            switch ($answer.Trim()) {
                '1' { foreach ($id in @('outlook','rdp')) { $tweak=Get-PcRegistryTweak $id; Write-Host $tweak.Path; Get-PcRegistryValues $tweak | Format-Table -AutoSize | Out-Host } }
                '2' { $size=Read-Host 'Maximum GB (1-1000; Enter for 100)'; if ([string]::IsNullOrWhiteSpace($size)) { $size='100' }; if ($size -notmatch '^\d+$') { throw 'Enter a whole number of GB.' }; Invoke-PcRegistryTweak outlook -SizeGB ([int]$size) }
                '3' { Invoke-PcRegistryTweak outlook -Reset }
                '4' { Invoke-PcRegistryTweak rdp }
                '5' { Invoke-PcRegistryTweak rdp -Reset }
                default { Write-Warning 'Choose a listed option.' }
            }
        } catch { Write-Warning $_.Exception.Message }
    }
}

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

function Get-PcPrinters {
    if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
        Get-Printer -ErrorAction Stop | Select-Object Name,Type,PrinterStatus,DriverName,PortName,Shared
    } else {
        Get-CimInstance Win32_Printer -ErrorAction Stop | Select-Object Name,Default,WorkOffline,PrinterStatus,DriverName,PortName,Shared
    }
}

function Get-PcPrintJobs {
    foreach ($printer in @(Get-Printer -ErrorAction Stop)) {
        try {
            $jobs=@(Get-PrintJob -PrinterName $printer.Name -ErrorAction Stop)
            if ($jobs.Count -eq 0) { [pscustomobject]@{Printer=$printer.Name;Detail='Queue empty'} }
            foreach ($job in $jobs) { [pscustomobject]@{Printer=$printer.Name;Id=$job.ID;Document=$job.DocumentName;User=$job.UserName;Status=$job.JobStatus;Submitted=$job.SubmittedTime;Size=$job.Size;TotalPages=$job.TotalPages} }
        } catch { [pscustomobject]@{Printer=$printer.Name;Detail=$_.Exception.Message} }
    }
}

function Get-PcEventRecords {
    [CmdletBinding()]
    param(
        [string]$LogName='System',
        [ValidateRange(1,8760)][int]$Hours=24,
        [int[]]$Ids=@(),
        [int[]]$Levels=@(),
        [string]$Provider,
        [string]$Text,
        [ValidateRange(1,1000)][int]$Limit=200
    )
    if ([string]::IsNullOrWhiteSpace($LogName) -or $LogName -match '[*?]') { throw 'Enter one exact log name (no wildcards).' }
    if (@($Ids | Where-Object { $_ -lt 0 -or $_ -gt 65535 }).Count) { throw 'Event IDs must be between 0 and 65535.' }
    if (@($Levels | Where-Object { $_ -lt 0 -or $_ -gt 5 }).Count) { throw 'Levels must be between 0 and 5.' }
    $filter=@{LogName=$LogName;StartTime=(Get-Date).AddHours(-$Hours)}
    if ($Ids.Count) { $filter.Id=$Ids }
    if ($Levels.Count) { $filter.Level=$Levels }
    if ($Provider) { $filter.ProviderName=$Provider }
    try { $records=@(Get-WinEvent -FilterHashtable $filter -MaxEvents $Limit -ErrorAction Stop) }
    catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { return }
        throw
    }
    foreach ($record in $records) {
        try { $message=[string]$record.Message } catch { $message='[Message unavailable: '+$_.Exception.Message+']' }
        if ($Text -and $message.IndexOf($Text,[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        [pscustomobject]@{Time=$record.TimeCreated;Id=$record.Id;Level=$record.LevelDisplayName;Provider=$record.ProviderName;Log=$record.LogName;RecordId=$record.RecordId;Machine=$record.MachineName;Message=$message}
    }
}

function ConvertTo-PcEventNumbers {
    param([string]$Value,[int]$Maximum)
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    foreach ($part in $Value.Split(',')) {
        $number=0
        if (-not [int]::TryParse($part.Trim(),[ref]$number) -or $number -lt 0 -or $number -gt $Maximum) { throw "Enter comma-separated integers between 0 and $Maximum." }
        $number
    }
}

function Start-PcEventBrowser {
    param([string]$DefaultLog='System')
    $log=Read-Host "Log name [$DefaultLog]"
    if ([string]::IsNullOrWhiteSpace($log)) { $log=$DefaultLog } else { $log=$log.Trim() }
    $hours=24; $answer=Read-Host 'Look back hours [24; max 8760]'
    if ($answer -and (-not [int]::TryParse($answer,[ref]$hours) -or $hours -lt 1 -or $hours -gt 8760)) { throw 'Hours must be 1-8760.' }
    $ids=@(ConvertTo-PcEventNumbers (Read-Host 'Event IDs, comma-separated [all]') 65535)
    $levels=@(ConvertTo-PcEventNumbers (Read-Host 'Levels: 0=log always,1=critical,2=error,3=warning,4=information,5=verbose [all]') 5)
    $provider=Read-Host 'Provider name or wildcard [all]'
    $text=Read-Host 'Message contains text [any]'
    $limit=200; $answer=Read-Host 'Maximum recent candidates [200; max 1000]'
    if ($answer -and (-not [int]::TryParse($answer,[ref]$limit) -or $limit -lt 1 -or $limit -gt 1000)) { throw 'Limit must be 1-1000.' }
    Write-Host 'Newest first. Message text filtering applies only to the capped candidate set; older matches may be omitted.' -ForegroundColor Yellow
    $events=@(Get-PcEventRecords -LogName $log -Hours $hours -Ids $ids -Levels $levels -Provider $provider -Text $text -Limit $limit)
    if ($events.Count -eq 0) { Write-Host 'No matching events in the queried window/candidate set.'; return }
    $page=0
    :events while ($true) {
        $pages=[math]::Ceiling($events.Count/20.0)
        Write-Host "`n EVENTS | $log | $($events.Count) results | page $($page+1)/$pages" -ForegroundColor Cyan
        for ($i=$page*20; $i -lt [math]::Min($events.Count,($page+1)*20); $i++) {
            $event=$events[$i]
            Write-Host (' [{0}] {1} | {2} | ID {3} | {4}' -f ($i+1),$event.Time,$event.Level,$event.Id,$event.Provider)
        }
        $answer=Read-Host 'Number: full message | N/P: pages | 0: back'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        switch ($answer.Trim().ToUpperInvariant()) {
            'N' { $page=[math]::Min($pages-1,$page+1); continue events }
            'P' { $page=[math]::Max(0,$page-1); continue events }
        }
        $number=0
        if ([int]::TryParse($answer,[ref]$number) -and $number -gt 0 -and $number -le $events.Count) { $events[$number-1] | Format-List | Out-Host }
        else { Write-Warning 'Choose an event number, N, P or 0.' }
    }
}

function Get-PcEventLogs {
    $pattern=Read-Host 'Log name pattern [*]'
    if ([string]::IsNullOrWhiteSpace($pattern)) { $pattern='*' }
    # Preserve warnings for inaccessible logs; disabled logs are shown but never enabled automatically.
    Get-WinEvent -ListLog $pattern -ErrorAction Continue | Sort-Object LogName | Select-Object LogName,IsEnabled,RecordCount,LogMode,MaximumSizeInBytes
}

function Get-PcPowerPlans {
    $lines = & powercfg.exe /list 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($lines -join ' ') }
    foreach ($line in $lines) {
        if ([string]$line -match '(?i)([0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})\s+\((.*)\)') {
            [pscustomobject]@{Guid=$Matches[1];Name=$Matches[2];Active=([string]$line -match '\*\s*$')}
        }
    }
}

function Get-PcPowerOverview {
    $enclosures = @(Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop)
    $batteries = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
    $portable = @($enclosures.ChassisTypes | Where-Object { $_ -in @(8,9,10,11,14,30,31,32) }).Count -gt 0
    $device = 'Desktop / other (reported chassis)'
    if ($portable) { $device = 'Laptop / portable (reported chassis)' }
    elseif ($batteries.Count -gt 0) { $device = 'Battery detected; chassis not identified as portable' }
    $plans = @(Get-PcPowerPlans)
    $active = $plans | Where-Object Active | Select-Object -First 1
    $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $assessment = 'Active plan is not the standard High performance plan. Custom plans may be equivalent; power mode overlays are separate.'
    if ($active.Guid -eq $high) { $assessment = 'Standard High performance plan is active.' }
    elseif ($portable) { $assessment = 'Laptop is not using standard High performance. Consider it on AC for performance troubleshooting; Balanced can be appropriate for battery/heat.' }
    if ($high -notin $plans.Guid) { $assessment += ' High performance is not exposed on this device; no plan is created or forced.' }
    [pscustomobject]@{Device=$device;ChassisCodes=($enclosures.ChassisTypes -join ', ');BatteryCount=$batteries.Count;ActivePlan=$active.Name;PlanGuid=$active.Guid;Assessment=$assessment}
    foreach ($battery in $batteries) {
        [pscustomobject]@{Battery=$battery.Name;ChargePercent=$battery.EstimatedChargeRemaining;BatteryStatusCode=$battery.BatteryStatus;Detail='Battery/chassis values are firmware-reported; battery presence alone does not prove a laptop.'}
    }
    $plans
}

function Get-PcNicPower {
    foreach ($adapter in @(Get-NetAdapter -Physical -ErrorAction Stop)) {
        try {
            $pm = Get-NetAdapterPowerManagement -Name ([WildcardPattern]::Escape($adapter.Name)) -ErrorAction Stop
            [pscustomobject]@{Adapter=$adapter.Name;InterfaceIndex=$adapter.InterfaceIndex;Status=$adapter.Status;AllowComputerToTurnOffDevice=[string]$pm.AllowComputerToTurnOffDevice;SelectiveSuspend=[string]$pm.SelectiveSuspend;DeviceSleepOnDisconnect=[string]$pm.DeviceSleepOnDisconnect;Detail='Unsupported/blank settings are driver limitations. Disabling NIC sleep does not prevent the PC itself from sleeping.'}
        } catch { [pscustomobject]@{Adapter=$adapter.Name;InterfaceIndex=$adapter.InterfaceIndex;Status='UNAVAILABLE';Detail=$_.Exception.Message} }
    }
}

function Get-PcQualityChecks {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    [pscustomobject]@{Check='Uptime';Value=((Get-Date)-$os.LastBootUpTime).ToString();Detail='Long uptime can help explain pending maintenance; it is not itself a fault.'}
    foreach ($disk in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop)) {
        if ($disk.Size -gt 0) {
            $percent = [math]::Round(100*$disk.FreeSpace/$disk.Size,1)
            $status='PASS'; if ($percent -lt 10) { $status='WARN' }
            [pscustomobject]@{Check='Free disk space';Drive=$disk.DeviceID;FreeGiB=[math]::Round($disk.FreeSpace/1GB,2);FreePercent=$percent;Status=$status;Detail='Warning threshold: less than 10% free; use Disk usage to inspect.'}
        }
    }
    foreach ($registryPath in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) {
        [pscustomobject]@{Check='Reboot indicator';Path=$registryPath;Present=(Test-Path -LiteralPath $registryPath -ErrorAction Stop);Detail='Checks common Windows servicing markers only; absence does not prove no restart is needed.'}
    }
}

function Start-PcDiskExplorer {
    $revision='c6469659c9d7cea9e1f12c96f34999a232a1ae98'
    $expected='AD00B99861E3176308A5A8175033D4DABDBFB8753F74F3A8588E80F15BB05BBB'
    $download=Join-Path ([IO.Path]::GetTempPath()) ('toolkit-disk-'+[guid]::NewGuid().ToString('N')+'.ps1')
    try {
        Write-Host 'Downloading verified Disk Usage 0.4.4 from D13desu/random-toolkits...'
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/D13desu/random-toolkits/$revision/win/disk/Disk-Usage.ps1" -OutFile $download -TimeoutSec 60 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $expected) { throw 'Disk explorer checksum mismatch. Script not executed.' }
        & $download
    } finally { if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force } }
}

function Get-PcDiskHelperRuntimeReason {
    $framework=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue
    if (-not $framework -or [int]$framework.Release -lt 378675) { return 'Requires .NET Framework 4.5.1+ (full Windows runtime)' }
}

function Get-PcDiskHelperPackage {
    [pscustomobject]@{
        Version='0.6.0-experiment'
        Uri='https://github.com/D13desu/random-toolkits/releases/download/disk-helper-experiment-v0.6.0/DiskHelper-0.6.0-experiment.zip'
        Sha256='E09D7D139E59CB7F2B50E58AA621C28E64E81435B00FB7F04F0119943B7390B5'
    }
}

function Start-PcDiskHelper {
    $entry=Get-NetworkChecks | Where-Object Id -eq 'disk-helper' | Select-Object -First 1
    $availability=Get-NetworkAvailability $entry
    if (-not $availability.Available) { throw $availability.Reason }
    $package=Get-PcDiskHelperPackage
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    $work=[IO.Path]::GetFullPath((Join-Path $temp ('toolkit-helper-'+[guid]::NewGuid().ToString('N'))))
    $null=[IO.Directory]::CreateDirectory($work)
    try {
        $archive=Join-Path $work 'helper.zip'
        Write-Host "Downloading verified experimental Disk Helper $($package.Version)..."
        Invoke-WebRequest -UseBasicParsing -Uri $package.Uri -OutFile $archive -TimeoutSec 60 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $package.Sha256) { throw 'Disk helper package checksum mismatch. Nothing extracted or executed.' }
        $unpacked=Join-Path $work 'package'
        Expand-Archive -LiteralPath $archive -DestinationPath $unpacked -ErrorAction Stop
        $runner=Join-Path $unpacked 'Start-DiskHelper.ps1'
        $manifest=Get-Content -LiteralPath (Join-Path $unpacked 'out/manifest.json') -Raw | ConvertFrom-Json
        if ($manifest.Version -ne $package.Version -or -not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'Unexpected disk helper package layout or version.' }
        # The packaged client also verifies the executable hash and version handshake.
        & $runner -HelperDirectory (Join-Path $unpacked 'out') -Engine mft
    } finally {
        # Delete only this invocation's GUID directory beneath the resolved TEMP root.
        $resolved=[IO.Path]::GetFullPath($work)
        if ($resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^toolkit-helper-[0-9a-f]{32}$') {
            if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
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
        [pscustomobject]@{Key='7';Id='restart-spooler';Name='Restart / start local Print Spooler';MinPS='5.0';Commands=@('Get-Service','Restart-Service','Start-Service');Admin=$true;Roles=@();Impact='Restarts the local spooler (or starts it if stopped). Interrupts printing and may affect connected clients on a print server. Does not delete spool files or intentionally cancel jobs.'}
        [pscustomobject]@{Key='8';Id='gp-refresh-user';Name='Refresh current-user Group Policy';MinPS='5.0';Commands=@('gpupdate.exe');Admin=$false;Roles=@();Impact='Requests reapplication of current-user policy. Policy can change settings and run configured extensions/scripts. Uses the current Windows account, which may differ in an elevated session. No automatic reboot/logoff requested.'}
        [pscustomobject]@{Key='9';Id='gp-refresh-computer';Name='Refresh computer Group Policy';MinPS='5.0';Commands=@('gpupdate.exe');Admin=$true;Roles=@();Impact='Requests reapplication of computer policy. Policy can change machine settings and run configured extensions/scripts. No automatic reboot/logoff requested.'}
        [pscustomobject]@{Key='5'; Id='set-power-plan'; Name='Select an available power plan'; MinPS='5.0'; Commands=@('powercfg.exe'); Admin=$true; Roles=@(); Impact='Changes the active plan for this PC, including its AC/battery sleep and performance settings. High performance may increase battery drain, heat and fan noise. Note the previous plan to switch back.'}
        [pscustomobject]@{Key='6'; Id='nic-awake'; Name='Disable supported NIC sleep settings'; MinPS='5.0'; Commands=@('Get-NetAdapter','Get-NetAdapterPowerManagement','Set-NetAdapterPowerManagement'); Admin=$true; Roles=@(); Impact='Disables supported sleep settings on ONE physical NIC. May increase power use. No automatic NIC restart; a later adapter restart or reboot may be needed. Wake-on-LAN settings are preserved.'}
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
        [int]$InterfaceIndex = -1,
        [string]$PlanGuid
    )
    $entry = Get-NetworkRepairs | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $entry) { throw "Unknown repair: $Id" }
    $context = Get-AdContext
    $availability = Get-AdAvailability $entry $context
    if (-not $availability.Available) { throw $availability.Reason }
    $targetLabel = $env:COMPUTERNAME
    $adapter = $null
    $powerManagement = $null
    if ($Id -eq 'set-power-plan') {
        $plans = @(Get-PcPowerPlans)
        $selected = $plans | Where-Object { $_.Guid -eq $PlanGuid } | Select-Object -First 1
        if (-not $selected) { throw 'Select a plan listed by powercfg. This tool does not create unsupported plans.' }
        $previous = $plans | Where-Object Active | Select-Object -First 1
        $targetLabel += " / $($previous.Name) [$($previous.Guid)] -> $($selected.Name) [$($selected.Guid)]"
    }
    if ($Id -eq 'nic-awake') {
        $adapter = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex })
        if ($adapter.Count -ne 1) { throw 'Select exactly one physical adapter by InterfaceIndex.' }
        $adapter=$adapter[0]
        $powerManagement = Get-NetAdapterPowerManagement -Name ([WildcardPattern]::Escape($adapter.Name)) -ErrorAction Stop
        $supported = @('AllowComputerToTurnOffDevice','SelectiveSuspend','DeviceSleepOnDisconnect' | Where-Object { [string]$powerManagement.$_ -in @('Enabled','Disabled') })
        if ($supported.Count -eq 0) { throw 'This NIC driver exposes no supported sleep settings. No change made.' }
        $targetLabel += " / $($adapter.Name) [$InterfaceIndex] / " + (($supported | ForEach-Object { "$_=$($powerManagement.$_)" }) -join ', ')
    }
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
        'restart-spooler' {
            $service=Get-Service -Name Spooler -ErrorAction Stop
            if ($service.Status -eq 'Stopped') { Start-Service -Name Spooler -ErrorAction Stop }
            else { Restart-Service -Name Spooler -ErrorAction Stop }
            $service=Get-Service -Name Spooler -ErrorAction Stop
            $service.WaitForStatus('Running',[timespan]::FromSeconds(15))
            [pscustomobject]@{Action=$Id;Status='PASS';Detail='Local Print Spooler is running. Recheck queues; this does not prove end-to-end printing works.'}
        }
        { $_ -in @('gp-refresh-user','gp-refresh-computer') } {
            $scope='user'; if ($Id -eq 'gp-refresh-computer') { $scope='computer' }
            Invoke-AdNative 'gpupdate.exe' @("/target:$scope",'/force','/wait:0')
            Write-Host 'Policy refresh requested asynchronously. Completion is not verified; check gpresult and GroupPolicy events. Some settings require a later logoff/reboot.' -ForegroundColor Yellow
        }
        'set-power-plan' {
            $result = Invoke-AdNative 'powercfg.exe' @('/setactive',$selected.Guid)
            $result
            if ($result.ExitCode -eq 0) {
                $now = @(Get-PcPowerPlans | Where-Object Active)
                if ($selected.Guid -notin $now.Guid) { throw 'Windows did not report the requested plan as active. Policy or hardware may override it.' }
                $now
            }
        }
        'nic-awake' {
            $currentAdapter = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex })
            if ($currentAdapter.Count -ne 1 -or $currentAdapter[0].InterfaceGuid -ne $adapter.InterfaceGuid) { throw 'Adapter changed; select it again.' }
            $powerManagement = Get-NetAdapterPowerManagement -Name ([WildcardPattern]::Escape($currentAdapter[0].Name)) -ErrorAction Stop
            $settings = @{InputObject=$powerManagement;NoRestart=$true;ErrorAction='Stop'}
            if ('AllowComputerToTurnOffDevice' -in $supported) { $powerManagement.AllowComputerToTurnOffDevice='Disabled' }
            foreach ($feature in @('SelectiveSuspend','DeviceSleepOnDisconnect')) {
                if ($feature -in $supported) { $settings[$feature]='Disabled' }
            }
            Set-NetAdapterPowerManagement @settings | Out-Null
            $after = Get-NetAdapterPowerManagement -Name ([WildcardPattern]::Escape($currentAdapter[0].Name)) -ErrorAction Stop
            foreach ($feature in $supported) {
                $status='WARN'; if ([string]$after.$feature -eq 'Disabled') { $status='PASS' }
                [pscustomobject]@{Adapter=$adapter.Name;Setting=$feature;Value=[string]$after.$feature;Status=$status;Detail='Configuration read-back only. No NIC restart performed; reboot/restart may be needed to apply. Check driver if setting did not persist.'}
            }
        }
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
    if ($Entry.Id -eq 'set-power-plan') {
        $plans=@(Get-PcPowerPlans)
        for ($i=0; $i -lt $plans.Count; $i++) { Write-Host " [$($i+1)] $($plans[$i].Name) | Active: $($plans[$i].Active) | $($plans[$i].Guid)" }
        $number=0
        if (-not [int]::TryParse((Read-Host 'Plan number'),[ref]$number) -or $number -lt 1 -or $number -gt $plans.Count) { throw 'Choose a listed plan.' }
        $repairParameters.PlanGuid=$plans[$number-1].Guid
    }
    if ($Entry.Id -eq 'nic-awake') {
        $nics=@(Get-NetAdapter -Physical -ErrorAction Stop)
        $nics | Select-Object InterfaceIndex,Name,Status,InterfaceDescription | Format-Table -AutoSize | Out-Host
        $index=-1
        if (-not [int]::TryParse((Read-Host 'NIC InterfaceIndex'),[ref]$index) -or $index -notin $nics.InterfaceIndex) { throw 'Choose a listed physical NIC.' }
        $repairParameters.InterfaceIndex=$index
    }
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
        [pscustomobject]@{Key='printers';Id='printers';Name='Installed printers and status';MinPS='5.0';Commands=@('Get-CimInstance');Admin=$false;Action={param($t,$p) Get-PcPrinters}}
        [pscustomobject]@{Key='print-jobs';Id='print-jobs';Name='Print queues and jobs';MinPS='5.0';Commands=@('Get-Printer','Get-PrintJob');Admin=$false;Action={param($t,$p) Get-PcPrintJobs}}
        [pscustomobject]@{Key='print-ports';Id='print-ports';Name='Printer ports and drivers';MinPS='5.0';Commands=@('Get-PrinterPort','Get-PrinterDriver');Admin=$false;Action={param($t,$p) Get-PrinterPort -ErrorAction Stop | Select-Object Name,Description,PrinterHostAddress,PortNumber; Get-PrinterDriver -ErrorAction Stop | Select-Object Name,Manufacturer,PrinterEnvironment,MajorVersion}}
        [pscustomobject]@{Key='spooler';Id='spooler';Name='Print Spooler service';MinPS='5.0';Commands=@('Get-Service');Admin=$false;Action={param($t,$p) Get-Service Spooler -ErrorAction Stop | Select-Object Name,Status,StartType}}
        [pscustomobject]@{Key='print-events';Id='print-events';Name='Printing event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;Action={param($t,$p) Start-PcEventBrowser 'Microsoft-Windows-PrintService/Admin'}}
        [pscustomobject]@{Key='gp-user';Id='gp-user';Name='Applied user policy (current account)';MinPS='5.0';Commands=@('gpresult.exe');Admin=$false;Action={param($t,$p) Invoke-AdNative 'gpresult.exe' @('/scope','user','/r')}}
        [pscustomobject]@{Key='gp-computer';Id='gp-computer';Name='Applied computer policy';MinPS='5.0';Commands=@('gpresult.exe');Admin=$true;Action={param($t,$p) Invoke-AdNative 'gpresult.exe' @('/scope','computer','/r')}}
        [pscustomobject]@{Key='gp-events';Id='gp-events';Name='Group Policy event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;Action={param($t,$p) Start-PcEventBrowser 'Microsoft-Windows-GroupPolicy/Operational'}}
        [pscustomobject]@{Key='event-logs';Id='event-logs';Name='List available logs (name filter)';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;Action={param($t,$p) Get-PcEventLogs}}
        [pscustomobject]@{Key='event-browser';Id='event-browser';Name='Browse/filter events and full messages';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;Action={param($t,$p) Start-PcEventBrowser}}
        [pscustomobject]@{Key='power';Id='power';Name='Laptop / battery / active power plan';MinPS='5.0';Commands=@('Get-CimInstance','powercfg.exe');Admin=$false;Action={param($t,$p) Get-PcPowerOverview}}
        [pscustomobject]@{Key='nic-power';Id='nic-power';Name='NIC sleep and power-saving settings';MinPS='5.0';Commands=@('Get-NetAdapter','Get-NetAdapterPowerManagement');Admin=$false;Action={param($t,$p) Get-PcNicPower}}
        [pscustomobject]@{Key='sleep';Id='sleep';Name='Sleep states and AC/battery timeouts';MinPS='5.0';Commands=@('powercfg.exe');Admin=$false;Action={param($t,$p) Invoke-AdNative 'powercfg.exe' @('/a'); Invoke-AdNative 'powercfg.exe' @('/query','SCHEME_CURRENT','SUB_SLEEP'); Invoke-AdNative 'powercfg.exe' @('/query','SCHEME_CURRENT','SUB_VIDEO')}}
        [pscustomobject]@{Key='wake';Id='wake';Name='Sleep blockers and last wake reason';MinPS='5.0';Commands=@('powercfg.exe');Admin=$true;Action={param($t,$p) Invoke-AdNative 'powercfg.exe' @('/requests'); Invoke-AdNative 'powercfg.exe' @('/lastwake')}}
        [pscustomobject]@{Key='quality';Id='quality';Name='Uptime, disk headroom and reboot indicators';MinPS='5.0';Commands=@('Get-CimInstance');Admin=$false;Action={param($t,$p) Get-PcQualityChecks}}
        [pscustomobject]@{Key='disk';Id='disk';Name='Open disk usage explorer (verified download)';MinPS='5.0';Commands=@();Admin=$false;Action={param($t,$p) Start-PcDiskExplorer}}
        [pscustomobject]@{Key='disk-helper';Id='disk-helper';Name='Experimental MFT disk explorer 0.6.0 (C# helper)';MinPS='5.1';Commands=@('Expand-Archive','Get-FileHash');Admin=$true;Action={param($t,$p) Start-PcDiskHelper}}
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
    if ($Entry.Id -eq 'disk-helper') { $runtimeReason=Get-PcDiskHelperRuntimeReason; if ($runtimeReason) { $reasons += $runtimeReason } }
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
        [pscustomobject]@{Key='7'; Id='power'; Name='Power and device health'; Checks=@('power','nic-power','sleep','wake','quality'); AdChecks=@(); Repairs=@('set-power-plan','nic-awake')}
        [pscustomobject]@{Key='8'; Id='storage'; Name='Disk usage explorers'; Checks=@('disk','disk-helper'); AdChecks=@(); Repairs=@()}
        [pscustomobject]@{Key='9';Id='printing';Name='Printing';Checks=@('printers','print-jobs','print-ports','spooler','print-events');AdChecks=@();Repairs=@('restart-spooler')}
        [pscustomobject]@{Key='10';Id='policy';Name='Group Policy';Checks=@('gp-user','gp-computer','gp-events');AdChecks=@('ad-context');Repairs=@('gp-refresh-user','gp-refresh-computer')}
        [pscustomobject]@{Key='11';Id='events';Name='Event Logs';Checks=@('event-logs','event-browser');AdChecks=@();Repairs=@()}
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
        Write-Host "`n WINDOWS TOOLKIT > $($category.Name.ToUpperInvariant())" -ForegroundColor Cyan
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
        Write-Host ' WINDOWS TOOLKIT > NETWORK' -ForegroundColor Cyan
        Write-Host " PowerShell $($PSVersionTable.PSVersion) | DIAGNOSE AND REPAIR"
        Write-Host '============================================' -ForegroundColor Cyan
        foreach ($category in @(Get-NetworkCategories | Where-Object { $_.Id -in @('overview','connectivity','dns','ad','routing','firewall') })) { Write-Host " [$($category.Key)] $($category.Name)" }
        Write-Host "`n [0] Back"
        Write-Host 'Checks and repairs are grouped by topic. Repairs ask before making changes.' -ForegroundColor DarkGray
        $selection = Read-Host 'Select'
        if ($null -eq $selection -or $selection.Trim() -eq '0') { return }
        # Retain the former AD shortcut for existing users.
        if ($selection.Trim() -eq 'A') { Start-AdMenu; continue }
        $category = Get-NetworkCategories | Where-Object { $_.Key -eq $selection.Trim() -and $_.Id -in @('overview','connectivity','dns','ad','routing','firewall') } | Select-Object -First 1
        if (-not $category) { Write-Warning 'Unknown selection'; continue }
        Start-NetworkCategory $category.Id
    }
}

function Start-WindowsMenu {
    while ($true) {
        Write-Host "`n============================================" -ForegroundColor Cyan
        Write-Host ' RANDOM TOOLKITS | WINDOWS 0.6.5' -ForegroundColor Cyan
        Write-Host " PowerShell $($PSVersionTable.PSVersion) | DIAGNOSE AND REPAIR"
        Write-Host '============================================' -ForegroundColor Cyan
        Write-Host ' [1] Network - connectivity, DNS, AD, routing, firewall'
        Write-Host ' [2] Power and device health - battery, plans, NIC sleep'
        Write-Host ' [3] Storage - drives and folder sizes'
        Write-Host ' [4] Printing - printers, queues, spooler and events'
        Write-Host ' [5] Group Policy - results, refresh and events'
        Write-Host ' [6] Event Logs - filtered CLI viewer'
        Write-Host ' [7] Registry tweaks - Outlook file limits and RDP warning'
        Write-Host "`n [0] Exit"
        Write-Host 'Repair options ask before making changes. M365 remains a separate toolkit.' -ForegroundColor DarkGray
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        switch ($answer.Trim()) {
            '1' { Start-NetworkMenu }
            '2' { Start-NetworkCategory 'power' }
            '3' { Start-NetworkCategory 'storage' }
            '4' { Start-NetworkCategory 'printing' }
            '5' { Start-NetworkCategory 'policy' }
            '6' { Start-NetworkCategory 'events' }
            '7' { Start-PcRegistryMenu }
            default { Write-Warning 'Choose a listed section.' }
        }
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'Windows PowerShell 5.0+ is required (5.1 recommended).' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This toolkit requires Windows.' }
if ($Check -like 'ad-*') { Invoke-AdCheck $Check $DomainController }
elseif ($Check) { Invoke-NetworkCheck $Check $Target $Port }
elseif (-not $NoMenu) { Start-WindowsMenu }
