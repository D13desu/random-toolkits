# Random Toolkits | Windows Toolkit 0.28.0

# Self-contained: local execution and irm ... | iex use the same source.
[CmdletBinding()]
param(
    [switch]$NoMenu,
    [string]$Check,
    [string]$Target = 'example.com',
    [ValidateRange(1,65535)][int]$Port = 443,
    [string]$DomainController
)
$script:PcToolkitVersion='0.28.0'

function Read-PcInput {
    param([string]$Prompt)
    $answer=Read-Host ($Prompt+' [B: back]')
    if ($null -ne $answer -and $answer.Trim() -eq 'B') { throw [OperationCanceledException]::new('Back to menu.') }
    return $answer
}

# BEGIN REGISTRY TWEAKS
function Get-PcRegistryTweak {
    param([ValidateSet('outlook','rdp','rdpclientudp','rdpservertransport')][string]$Id)
    switch ($Id) {
        'outlook' { [pscustomobject]@{Path='HKCU:\Software\Microsoft\Office\16.0\Outlook\PST';RegPath='HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\PST';Names=@('MaxLargeFileSize','WarnLargeFileSize');Admin=$false} }
        'rdp' { [pscustomobject]@{Path='HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';RegPath='HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';Names=@('RedirectionWarningDialogVersion');Admin=$true} }
        'rdpclientudp' { [pscustomobject]@{Path='HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';RegPath='HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services\Client';Names=@('fClientDisableUDP');Admin=$true} }
        'rdpservertransport' { [pscustomobject]@{Path='HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services';RegPath='HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services';Names=@('SelectTransport');Admin=$true} }
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
    param([ValidateSet('outlook','rdp','rdpclientudp','rdpservertransport')][string]$Id,
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
        switch ($Id) {
            'rdp' {
                Write-Host 'Machine-wide RDP file redirection warning: restore the older dialog for trusted connections only.'
                Write-Host 'Reduces the newer per-resource consent protection. Does not disable NLA or certificate checks.'
                Write-Host 'Temporary compatibility setting; a future Windows update may remove it. Prefer trusted, signed RDP files.'
                $values = @(1)
            }
            'rdpclientudp' {
                Write-Host 'Machine-wide RDP client transport: force outbound Remote Desktop connections to use TCP only.'
                Write-Host 'Use for UDP-related compatibility or stability troubleshooting; TCP-only can reduce RDP performance.'
                Write-Host 'This affects connections initiated by this device, not inbound connections to it.'
                $values = @(1)
            }
            'rdpservertransport' {
                Write-Host 'Machine-wide RDP Session Host transport: force inbound Remote Desktop connections to use TCP only.'
                Write-Host 'Use for UDP-related compatibility or stability troubleshooting; TCP-only can reduce RDP performance.'
                Write-Host 'This affects the server side of new RDP connections, not outbound connections from this device.'
                $values = @(1)
            }
        }
    }
    $before = @(Get-PcRegistryValues $tweak)
    Write-Host $tweak.Path
    $before | Format-Table Name,Exists,Value -AutoSize | Out-Host
    if ($Reset) {
        Write-Host 'Remove these overrides and use defaults.'
        if ($Id -eq 'outlook') { Write-Host 'Existing large Outlook files may then exceed the default limit.' }
    }
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
        if ($Id -eq 'outlook') { Write-Host 'Registry values verified. Reopen Outlook to use the setting.' }
        else { Write-Host 'Registry values verified. Start a new RDP connection to use the setting.' }
    } catch { throw "Change failed or was partially applied: $($_.Exception.Message) Restore previous values with $backup" }
}

function Start-PcRegistryCategory {
    param([ValidateSet('outlook','rdp','rdpclientudp','rdpservertransport')][string]$Id)
    $state=@{}
    while ($true) {
        $tweak=Get-PcRegistryTweak $Id
        $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$tweak.Admin})
        $reason=if(-not $availability.Available){$availability.Reason}else{''}
        switch($Id){
            'outlook' {
                $title='Windows > Registry > End-user devices > Outlook'
                $menu=@(New-PcMenuItem '1' 'Inspect current size overrides' 'Check';New-PcMenuItem '2' 'Set PST/OST size limit' 'Change' 'Current account; classic Outlook' $reason;New-PcMenuItem '3' 'Reset size overrides' 'Change' 'Restore defaults' $reason)
            }
            'rdp' {
                $title='Windows > Registry > End-user devices > RDP client > Warning dialog'
                $menu=@(New-PcMenuItem '1' 'Inspect warning override' 'Check';New-PcMenuItem '2' 'Restore older RDP warning dialog' 'Change' 'Machine-wide; administrator' $reason;New-PcMenuItem '3' 'Reset RDP warning override' 'Change' 'Windows default; administrator' $reason)
            }
            'rdpclientudp' {
                $title='Windows > Registry > End-user devices > RDP client > Transport'
                $menu=@(New-PcMenuItem '1' 'Inspect client transport override' 'Check';New-PcMenuItem '2' 'Force outbound RDP to use TCP only' 'Change' 'Machine-wide; administrator' $reason;New-PcMenuItem '3' 'Reset client transport override' 'Change' 'Automatic UDP/TCP; administrator' $reason)
            }
            'rdpservertransport' {
                $title='Windows > Registry > Servers > RDP Session Host > Transport'
                $menu=@(New-PcMenuItem '1' 'Inspect Session Host transport override' 'Check';New-PcMenuItem '2' 'Force inbound RDP to use TCP only' 'Change' 'Machine-wide; administrator' $reason;New-PcMenuItem '3' 'Reset Session Host transport override' 'Change' 'Automatic UDP/TCP; administrator' $reason)
            }
        }
        $answer=Read-PcCategoryMenu $title $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        Clear-PcMenuScreen
        try {
            switch ($answer.Trim()) {
                '1' { $tweak=Get-PcRegistryTweak $Id; Write-Host $tweak.Path; Get-PcRegistryValues $tweak | Format-Table -AutoSize | Out-Host }
                '2' {
                    if ($Id -eq 'outlook') {
                        $size=Read-PcInput 'Maximum GB (1-1000; Enter for 100)'
                        if ([string]::IsNullOrWhiteSpace($size)) { $size='100' }
                        if ($size -notmatch '^\d+$') { throw 'Enter a whole number of GB.' }
                        Invoke-PcRegistryTweak outlook -SizeGB ([int]$size)
                    } else { Invoke-PcRegistryTweak $Id }
                }
                '3' { Invoke-PcRegistryTweak $Id -Reset }
                default { Write-Warning 'Choose a listed option.' }
            }
        } catch [OperationCanceledException] { continue } catch { Write-Warning $_.Exception.Message }
        Wait-PcMenuReturn
    }
}

function Start-PcRegistryRdpClientMenu {
    $state=@{}
    while ($true) {
        $menu=@(New-PcMenuItem '1' 'Transport protocol' 'Menu' 'Outbound RDP; TCP-only troubleshooting';New-PcMenuItem '2' 'Redirection warning dialog' 'Menu' 'RDP file consent compatibility')
        $answer=Read-PcCategoryMenu 'Windows > Registry > End-user devices > Remote Desktop client' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryCategory rdpclientudp }
            '2' { Start-PcRegistryCategory rdp }
            default { Write-Warning 'Choose a listed option.' }
        }
    }
}

function Start-PcRegistryEndUserMenu {
    $state=@{}
    while ($true) {
        $menu=@(New-PcMenuItem '1' 'Outlook' 'Menu' 'PST/OST file size limits';New-PcMenuItem '2' 'Remote Desktop client' 'Menu' 'Transport and warning behavior')
        $answer=Read-PcCategoryMenu 'Windows > Registry > End-user devices' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryCategory outlook }
            '2' { Start-PcRegistryRdpClientMenu }
            default { Write-Warning 'Choose a listed option.' }
        }
    }
}

function Start-PcRegistryServerMenu {
    $state=@{}
    while ($true) {
        $menu=@(New-PcMenuItem '1' 'Remote Desktop Session Host' 'Menu' 'Inbound RDP transport')
        $answer=Read-PcCategoryMenu 'Windows > Registry > Servers' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryCategory rdpservertransport }
            default { Write-Warning 'Choose a listed option.' }
        }
    }
}

function Start-PcRegistryMenu {
    $state=@{}
    while ($true) {
        $menu=@(New-PcMenuItem '1' 'End-user devices' 'Menu' 'Outlook and Remote Desktop client';New-PcMenuItem '2' 'Servers' 'Menu' 'Remote Desktop Session Host')
        $answer=Read-PcCategoryMenu 'Windows > Registry tweaks' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryEndUserMenu }
            '2' { Start-PcRegistryServerMenu }
            default { Write-Warning 'Choose a listed option.' }
        }
    }
}
# END REGISTRY TWEAKS

# BEGIN SYSINTERNALS LAUNCHER
# Shortcuts to Microsoft's Sysinternals Live WebDAV share. No binaries are downloaded or redistributed.
$script:PcSysinternalsLiveRoot='\\live.sysinternals.com\tools'

function Get-PcSysinternalsArchitecture {
    $architecture=[string]$env:PROCESSOR_ARCHITEW6432
    if(-not $architecture){$architecture=[string]$env:PROCESSOR_ARCHITECTURE}
    if($architecture -match 'ARM64'){return 'arm64'}
    if($architecture -match 'AMD64'){return 'x64'}
    return 'x86'
}

function Get-PcSysinternalsLiveCatalog {
    @(
        [pscustomobject]@{Key='1';Id='procexp';Name='Process Explorer';Detail='Processes, handles, DLLs and system activity';x86='procexp.exe';x64='procexp64.exe';arm64='procexp64a.exe'}
        [pscustomobject]@{Key='2';Id='procmon';Name='Process Monitor';Detail='Live file, Registry, process and network events';x86='Procmon.exe';x64='Procmon64.exe';arm64='Procmon64a.exe'}
        [pscustomobject]@{Key='3';Id='autoruns';Name='Autoruns';Detail='Logon, service, driver and extension persistence';x86='Autoruns.exe';x64='Autoruns64.exe';arm64='Autoruns64a.exe'}
        [pscustomobject]@{Key='4';Id='tcpview';Name='TCPView';Detail='Live TCP and UDP endpoints with owning processes';x86='tcpview.exe';x64='tcpview64.exe';arm64='tcpview64a.exe'}
        [pscustomobject]@{Key='5';Id='rammap';Name='RAMMap';Detail='Physical-memory usage and cache inspection';x86='RAMMap.exe';x64='RAMMap64.exe';arm64='RAMMap64a.exe'}
        [pscustomobject]@{Key='6';Id='winobj';Name='WinObj';Detail='Windows Object Manager namespace viewer';x86='Winobj.exe';x64='Winobj64.exe';arm64='Winobj64a.exe'}
        [pscustomobject]@{Key='7';Id='vmmap';Name='VMMap';Detail='Detailed virtual and physical process memory map';x86='vmmap.exe';x64='vmmap64.exe';arm64='vmmap64a.exe'}
        [pscustomobject]@{Key='8';Id='dbgview';Name='DebugView';Detail='Capture local and kernel debug output';x86='Dbgview.exe';x64='Dbgview64.exe';arm64='Dbgview64a.exe'}
        [pscustomobject]@{Key='9';Id='zoomit';Name='ZoomIt';Detail='Screen zoom, annotation and presentation timer';x86='ZoomIt.exe';x64='ZoomIt64.exe';arm64='ZoomIt64a.exe'}
        [pscustomobject]@{Key='10';Id='disk2vhd';Name='Disk2vhd';Detail='Create VHD images of selected physical volumes';x86='disk2vhd.exe';x64='disk2vhd64.exe';arm64='disk2vhd64a.exe'}
    )
}

function Get-PcSysinternalsLivePath([string]$Id) {
    $tool=Get-PcSysinternalsLiveCatalog | Where-Object Id -EQ $Id | Select-Object -First 1
    if(-not $tool){throw "Unknown Sysinternals tool: $Id"}
    $architecture=Get-PcSysinternalsArchitecture
    $file=[string]$tool.$architecture
    if([string]::IsNullOrWhiteSpace($file)){throw "$($tool.Name) has no $architecture Sysinternals Live shortcut."}
    $directory=if($architecture -eq 'arm64'){$script:PcSysinternalsLiveRoot+'\ARM64'}else{$script:PcSysinternalsLiveRoot}
    [pscustomobject]@{Tool=$tool;Path=($directory+'\'+$file);Architecture=$architecture}
}

function Start-PcSysinternalsLiveTool([string]$Id) {
    $resolved=Get-PcSysinternalsLivePath $Id
    Write-Host "Opening $($resolved.Tool.Name) from Microsoft's Sysinternals Live share..." -ForegroundColor Cyan
    Write-Host $resolved.Path -ForegroundColor DarkGray
    Start-Process -FilePath $resolved.Path -ErrorAction Stop
    Write-Host 'The executable remains hosted by Microsoft. Its EULA and elevation prompts are not bypassed.' -ForegroundColor Green
}

function Show-PcSysinternalsLiveNotes {
    Clear-PcMenuScreen
    Write-Host "`nMicrosoft Sysinternals Live" -ForegroundColor Cyan
    Write-Host 'Share: \\live.sysinternals.com\tools'
    Write-Host 'Browser: https://live.sysinternals.com/'
    Write-Host 'Documentation: https://learn.microsoft.com/sysinternals/'
    Write-Host 'Each shortcut runs the current Microsoft-hosted executable over the network; nothing is installed or cached by this toolkit.'
    Write-Host 'A working internet connection and Windows WebDAV access are required. Corporate policy, proxy settings, or the WebClient service can block the share.' -ForegroundColor Yellow
    Write-Host 'Tools may request elevation and EULA acceptance. Captured diagnostics can contain sensitive system information.' -ForegroundColor Yellow
    $null=Read-Host 'Press Enter to return'
}

function Start-PcSysinternalsMenu {
    $state=@{}
    while($true){
        $menu=@(Get-PcSysinternalsLiveCatalog | ForEach-Object {New-PcMenuItem $_.Key $_.Name 'Open' $_.Detail})
        $menu+=New-PcMenuItem 'F' 'Open the Sysinternals Live tools share' 'Open' '\\live.sysinternals.com\tools'
        $menu+=New-PcMenuItem 'L' 'Network-share, EULA and safety notes' 'Check'
        $answer=Read-PcCategoryMenu 'Windows > Microsoft Sysinternals Live' $menu $state 'Microsoft-hosted network shortcuts; no toolkit download or local cache.'
        if($null -eq $answer -or $answer -in @('0','B')){return}
        try{
            $tool=Get-PcSysinternalsLiveCatalog | Where-Object Key -EQ $answer | Select-Object -First 1
            if($tool){Start-PcSysinternalsLiveTool $tool.Id;continue}
            switch($answer){
                'F'{Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$script:PcSysinternalsLiveRoot+'"') -ErrorAction Stop}
                'L'{Show-PcSysinternalsLiveNotes}
            }
        }catch{
            Write-Host "Sysinternals Live shortcut failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host 'Try https://live.sysinternals.com/ in a browser, or check whether WebDAV/Sysinternals Live is allowed by your network policy.' -ForegroundColor Yellow
            $null=Read-Host 'Press Enter to return'
        }
    }
}
# END SYSINTERNALS LAUNCHER

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
        $xml='';$xmlError=''
        try{$xml=$record.ToXml()}catch{$xmlError=$_.Exception.Message}
        [pscustomobject]@{Time=$record.TimeCreated;Id=$record.Id;Level=$record.LevelDisplayName;Provider=$record.ProviderName;Log=$record.LogName;RecordId=$record.RecordId;Machine=$record.MachineName;Message=$message;Xml=$xml;XmlError=$xmlError}
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

function Format-PcEventPreview {
    param([string]$Message,[ValidateRange(20,200)][int]$Width=100,[ValidateRange(1,3)][int]$Lines=3)
    $text=($Message -replace '[\x00-\x1F\x7F]',' ' -replace '\s+',' ').Trim()
    if(-not $text){return '[No rendered message; open event for XML.]'}
    for($line=0;$line -lt $Lines -and $text.Length;$line++){
        if($text.Length -le $Width){$text;break}
        $take=$Width
        if([char]::IsHighSurrogate($text[$take-1])){$take--}
        $space=$text.LastIndexOf(' ',$take-1,$take)
        if($space -gt 0){$take=$space}
        if($line -eq ($Lines-1)){$text.Substring(0,$take).TrimEnd()+' ...';break}
        $text.Substring(0,$take).TrimEnd();$text=$text.Substring($take).TrimStart()
    }
}
function Test-PcEventKeyboard {
    try{return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected}catch{return $false}
}
function ConvertFrom-PcEventKey($Key) {
    switch([string]$Key.Key){
        'UpArrow'{return '@UP'} 'DownArrow'{return '@DOWN'}
        'Enter'{return '@ENTER'} 'RightArrow'{return '@ENTER'}
        'LeftArrow'{return 'B'} 'Backspace'{return 'B'} 'Escape'{return 'B'}
        'PageUp'{return 'P'} 'PageDown'{return 'N'}
        'Home'{return '@HOME'} 'End'{return '@END'}
    }
    return ([string]$Key.KeyChar).ToUpperInvariant()
}
function Read-PcEventChoice([bool]$Keyboard,[string]$Prompt='Select') {
    if(-not $Keyboard){return Read-Host $Prompt}
    $digits=''
    while($true){
        $key=[Console]::ReadKey($true)
        if($key.Key -eq 'Backspace' -and $digits.Length){$digits=$digits.Substring(0,$digits.Length-1);continue}
        $command=ConvertFrom-PcEventKey $key
        if($command -match '^\d$'){$digits+=$command;continue}
        if($command -eq '@ENTER' -and $digits.Length){return $digits}
        if($command -in @('@UP','@DOWN','@ENTER','@HOME','@END','B','N','P','R','F','X','M','C','L')){return $command}
    }
}
function Show-PcEventDetails($EventRecord) {
    $keyboard=Test-PcMenuKeyboard
    if($keyboard){Clear-Host}
    $EventRecord | Select-Object Time,Id,Level,Provider,Log,RecordId,Machine | Format-List | Out-Host
    Write-Host $EventRecord.Message
    while($true){
        Write-Host 'X: raw XML | M: full message | Enter / Esc / Backspace: back'
        $answer=Read-PcMenuInput $keyboard
        switch(([string]$answer).Trim().ToUpperInvariant()){
            ''{return} 'B'{return} '0'{return} 'SELECT'{return} 'BACK'{return}
            'M'{Write-Host $EventRecord.Message}
            'X'{if($EventRecord.Xml){Write-Host $EventRecord.Xml}else{Write-Warning ('XML unavailable: '+$EventRecord.XmlError)}}
        }
    }
}
function New-PcEventMenuItem($Event) {
    $preview=@(Format-PcEventPreview -Message $Event.Message -Width 100)
    $levelColor=switch -Regex ([string]$Event.Level){'Critical|Error'{'Red'}'Warning'{'Yellow'}'Information'{'Gray'}'Verbose'{'DarkGray'}default{'Gray'}}
    [pscustomobject]@{
        Id=($Event.Log+'|'+$Event.RecordId)
        Label=("{0} | {1} | ID {2} | {3}" -f $Event.Time,$Event.Level,$Event.Id,$Event.Provider)
        Detail=($preview -join ' ');SelectedDetail=$preview;SearchText=$Event.Message;Data=$Event
        LabelParts=@(
            [pscustomobject]@{Text=([string]$Event.Time);Color='DarkGray'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Event.Level);Color=$levelColor}
            [pscustomobject]@{Text=' | ID ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Event.Id);Color='Magenta'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Event.Provider);Color='Cyan'}
        )
    }
}
function Start-PcEventBrowser {
    param([string]$DefaultLog='System',[switch]$Quick,[switch]$FixedLog,[string]$InitialProvider='',[string]$InitialText='')
    $log=$DefaultLog;$hours=24;$ids=@();$levels=@();$provider=$InitialProvider;$text=$InitialText;$limit=200
    if(-not $Quick){
    if(-not $FixedLog){$log=Read-PcInput "Log name [$DefaultLog]"}
    if ([string]::IsNullOrWhiteSpace($log)) { $log=$DefaultLog } else { $log=$log.Trim() }
    $hours=24; $answer=Read-PcInput 'Look back hours [24; max 8760]'
    if ($answer -and (-not [int]::TryParse($answer,[ref]$hours) -or $hours -lt 1 -or $hours -gt 8760)) { throw 'Hours must be 1-8760.' }
    $ids=@(ConvertTo-PcEventNumbers (Read-PcInput 'Event IDs, comma-separated [all]') 65535)
    $levels=@(ConvertTo-PcEventNumbers (Read-PcInput 'Levels: 0=log always,1=critical,2=error,3=warning,4=information,5=verbose [all]') 5)
    $provider=Read-PcInput 'Provider name or wildcard [all]'
    $text=Read-PcInput 'Message contains text [any]'
    $limit=200; $answer=Read-PcInput 'Maximum recent candidates [200; max 1000]'
    if ($answer -and (-not [int]::TryParse($answer,[ref]$limit) -or $limit -lt 1 -or $limit -gt 1000)) { throw 'Limit must be 1-1000.' }
    }
    Write-Host 'Newest first. Message text filtering applies only to the capped candidate set; older matches may be omitted.' -ForegroundColor Yellow
    $events=@(Get-PcEventRecords -LogName $log -Hours $hours -Ids $ids -Levels $levels -Provider $provider -Text $text -Limit $limit)
    $state=@{}
    while($true){
        $menu=@(foreach($event in $events){New-PcEventMenuItem $event})
        $choice=Show-PcMenu -Title ('Windows > Events > '+$log) -Items $menu -State $state -Filterable -Refreshable -ExpandedPreview -PageSize 20 -Description ("Last {0}h | Candidate cap: {1}. Text filter searches cached candidates; older matches may be omitted." -f $hours,$limit) -Commands @{C='Advanced query (time, IDs, levels, provider)'}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$events=@(Get-PcEventRecords -LogName $log -Hours $hours -Ids $ids -Levels $levels -Provider $provider -Text $text -Limit $limit)}
            'Command'{try{Start-PcEventBrowser -DefaultLog $log -FixedLog}catch [OperationCanceledException]{}}
            'Select'{Show-PcEventDetails $choice.Item.Data}
        }
    }
}

function Get-PcEventLogChoices {
    @(
        [pscustomobject]@{Name='Application';Log='Application';Purpose='Application crashes and service-specific errors';Directories=@('client','server')}
        [pscustomobject]@{Name='System';Log='System';Purpose='Drivers, hardware, services, storage and core networking';Directories=@('client','server')}
        [pscustomobject]@{Name='Security (may require elevated access)';Log='Security';Purpose='Sign-in, audit and policy events';Directories=@('server','security')}
        [pscustomobject]@{Name='Setup';Log='Setup';Purpose='Windows setup, roles and servicing';Directories=@('client','server')}
        [pscustomobject]@{Name='Forwarded events (collector subscriptions)';Log='ForwardedEvents';Purpose='Events received by Windows Event Collector';Directories=@('server')}
        [pscustomobject]@{Name='Windows PowerShell (legacy)';Log='Windows PowerShell';Purpose='Windows PowerShell engine and provider events';Directories=@('automation')}
        [pscustomobject]@{Name='PowerShell engine operational';Log='Microsoft-Windows-PowerShell/Operational';Purpose='PowerShell engine, remoting and script execution';Directories=@('automation')}
        [pscustomobject]@{Name='WLAN AutoConfig operational';Log='Microsoft-Windows-WLAN-AutoConfig/Operational';Purpose='Wi-Fi association, roaming and authentication failures';Directories=@('client')}
        [pscustomobject]@{Name='Wired AutoConfig operational';Log='Microsoft-Windows-Wired-AutoConfig/Operational';Purpose='Wired 802.1X authentication and profile failures';Directories=@('client')}
        [pscustomobject]@{Name='Network connection profiles';Log='Microsoft-Windows-NetworkProfile/Operational';Purpose='Network identification and profile changes';Directories=@('client')}
        [pscustomobject]@{Name='Hyper-V VM management service';Log='Microsoft-Windows-Hyper-V-VMMS/Admin';Purpose='VM configuration, start, migration and management failures';Directories=@('server')}
        [pscustomobject]@{Name='Hyper-V VM worker';Log='Microsoft-Windows-Hyper-V-Worker/Admin';Purpose='Guest runtime, device and VM start failures';Directories=@('server')}
        [pscustomobject]@{Name='Hyper-V virtual switch';Log='Microsoft-Windows-Hyper-V-VmSwitch/Operational';Purpose='Virtual switch, port, VLAN and VM network failures';Directories=@('server')}
        [pscustomobject]@{Name='Hyper-V hypervisor';Log='Microsoft-Windows-Hyper-V-Hypervisor/Admin';Purpose='Hypervisor startup and platform failures';Directories=@('server')}
        [pscustomobject]@{Name='Hyper-V failover clustering';Log='Microsoft-Windows-FailoverClustering/Operational';Purpose='Cluster membership, failover and live-migration context';Directories=@('server')}
        [pscustomobject]@{Name='Microsoft Defender';Log='Microsoft-Windows-Windows Defender/Operational';Purpose='Protection, scan, detection and remediation events';Directories=@('client','security')}
        [pscustomobject]@{Name='Windows Update';Log='Microsoft-Windows-WindowsUpdateClient/Operational';Purpose='Update discovery, download and installation failures';Directories=@('client','server')}
        [pscustomobject]@{Name='Group Policy';Log='Microsoft-Windows-GroupPolicy/Operational';Purpose='Policy discovery, processing and extension failures';Directories=@('client','server')}
        [pscustomobject]@{Name='Printing';Log='Microsoft-Windows-PrintService/Admin';Purpose='Print service, driver and job failures';Directories=@('client','server')}
        [pscustomobject]@{Name='Task Scheduler operational';Log='Microsoft-Windows-TaskScheduler/Operational';Purpose='Task triggers, launches, actions and result codes';Directories=@('automation')}
        [pscustomobject]@{Name='Remote Desktop sessions';Log='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational';Purpose='RDP session creation, disconnect and reconnect events';Directories=@('client','server')}
        [pscustomobject]@{Name='Code Integrity operational';Log='Microsoft-Windows-CodeIntegrity/Operational';Purpose='Blocked or invalid drivers and executable images';Directories=@('client','security')}
        [pscustomobject]@{Name='BitLocker API operational';Log='Microsoft-Windows-BitLocker-API/Operational';Purpose='Encryption, TPM, protector and recovery failures';Directories=@('client','security')}
    )
}
function Get-PcEventLogDirectories {
    @(
        [pscustomobject]@{Key='1';Id='client';Name='End-user devices';Purpose='Workstation applications, networking, updates, printing and device protection'}
        [pscustomobject]@{Key='2';Id='server';Name='Servers and infrastructure';Purpose='Windows Server, Event Collector, Hyper-V and failover clustering'}
        [pscustomobject]@{Key='3';Id='automation';Name='Automation and scripting';Purpose='PowerShell engines and scheduled tasks'}
        [pscustomobject]@{Key='4';Id='security';Name='Security and access';Purpose='Audit, Defender, Code Integrity and BitLocker'}
    )
}
function Start-PcEventLogDirectory($Directory) {
    $state=@{}
    while($true){
        $choices=@(Get-PcEventLogChoices | Where-Object {$_.Directories -contains $Directory.Id})
        $menu=@(for($i=0;$i -lt $choices.Count;$i++){New-PcMenuItem ([string]($i+1)) $choices[$i].Name 'Browse' $choices[$i].Purpose})
        $answer=Read-PcCategoryMenu ('Windows > Event Logs > '+$Directory.Name) $menu $state $Directory.Purpose
        if($answer -eq 'B'){return}
        try{
            $log=$choices[([int]$answer)-1].Log
            $info=Get-WinEvent -ListLog $log -ErrorAction Stop
            if(-not $info.IsEnabled){Write-Warning "$log is disabled. No logging settings were changed.";Wait-PcMenuReturn;continue}
            Start-PcEventBrowser -DefaultLog $log -Quick
        }catch [OperationCanceledException]{continue}
        catch{Write-Warning ("Unable to read this log: {0}. Some logs need elevated access or are not installed on this PC." -f $_.Exception.Message);Wait-PcMenuReturn}
    }
}
function Start-PcEventLogMenu {
    $state=@{}
    while($true){
        $directories=@(Get-PcEventLogDirectories)
        $menu=@(foreach($directory in $directories){New-PcMenuItem $directory.Key $directory.Name 'Menu' $directory.Purpose})
        $menu+=New-PcMenuItem 'C' 'Custom log / advanced filters' 'Browse'
        $menu+=New-PcMenuItem 'L' 'List/search available logs' 'Check'
        $answer=Read-PcCategoryMenu 'Windows > Event Logs' $menu $state 'Choose a troubleshooting directory. Presets show the latest 200 candidates from the last 24 hours.'
        if($answer -eq 'B'){return}
        try{
            if($answer -eq 'C'){Start-PcEventBrowser;continue}
            if($answer -eq 'L'){Get-PcEventLogs | Format-Table -AutoSize | Out-Host;Wait-PcMenuReturn;continue}
            $directory=$directories | Where-Object Key -EQ $answer | Select-Object -First 1
            if($directory){Start-PcEventLogDirectory $directory}
        }catch [OperationCanceledException]{continue}
        catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn}
    }
}

function Get-PcEventLogs {
    $pattern=Read-PcInput 'Log name pattern [*]'
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
    $revision='eb3227bcdb8d6d8b91e8fc8b72aa6cc2d62e1b76'
    $expected='2528D695914F46FF8D0B60510DC8C5CC47FAE5EC844658957815DE0EB0CD7507'
    $download=Join-Path ([IO.Path]::GetTempPath()) ('toolkit-disk-'+[guid]::NewGuid().ToString('N')+'.ps1')
    try {
        Write-Host 'Downloading verified Disk Usage 0.4.6 from D13desu/random-toolkits...'
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
        Version='1.3.1'
        Uri='https://github.com/D13desu/random-toolkits/releases/download/disk-helper-v1.3.1/DiskHelper-1.3.1.zip'
        Sha256='B8827F9A3FA43B37F0F9D82C95BB15FC097EB7107CEE01F91B24F8F6EC1BE565'
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
        Write-Host "Downloading verified Disk Usage $($package.Version)..."
        Invoke-WebRequest -UseBasicParsing -Uri $package.Uri -OutFile $archive -TimeoutSec 60 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $package.Sha256) { throw 'Disk helper package checksum mismatch. Nothing extracted or executed.' }
        $unpacked=Join-Path $work 'package'
        Expand-Archive -LiteralPath $archive -DestinationPath $unpacked -ErrorAction Stop
        $runner=Join-Path $unpacked 'Start-DiskHelper.ps1'
        $manifest=Get-Content -LiteralPath (Join-Path $unpacked 'out/manifest.json') -Raw | ConvertFrom-Json
        if ($manifest.Version -ne $package.Version -or -not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'Unexpected disk helper package layout or version.' }
        # The packaged client also verifies the executable hash and version handshake.
        & $runner -HelperDirectory (Join-Path $unpacked 'out') -Engine auto
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

function Get-AdIdentity {
    Invoke-AdNative 'whoami.exe' @('/all')
    Invoke-AdNative 'klist.exe' @()
    Invoke-AdNative 'klist.exe' @('sessions')
}

function Test-AdDcPorts {
    param([string]$Controller)
    $dcName = Get-AdController $Controller
    $services = @(
        [pscustomobject]@{Name='DNS';Port=53;Detail='TCP only; UDP DNS is not tested.'}
        [pscustomobject]@{Name='Kerberos';Port=88;Detail='Kerberos authentication.'}
        [pscustomobject]@{Name='RPC endpoint mapper';Port=135;Detail='RPC endpoint discovery; dynamic RPC ports are not tested.'}
        [pscustomobject]@{Name='LDAP';Port=389;Detail='LDAP TCP reachability; bind and directory health are not tested.'}
        [pscustomobject]@{Name='SMB';Port=445;Detail='SMB transport used by SYSVOL and NETLOGON.'}
        [pscustomobject]@{Name='Kerberos password';Port=464;Detail='Kerberos password change service.'}
        [pscustomobject]@{Name='LDAPS';Port=636;Detail='TLS handshake and certificate validity are not tested.'}
        [pscustomobject]@{Name='Global Catalog';Port=3268;Detail='Global Catalog LDAP.'}
        [pscustomobject]@{Name='Global Catalog TLS';Port=3269;Detail='TLS handshake and certificate validity are not tested.'}
        [pscustomobject]@{Name='AD Web Services';Port=9389;Detail='Used by the ActiveDirectory PowerShell module.'}
    )
    foreach ($service in $services) {
        $result = Test-NetworkTcp $dcName $service.Port 2000
        $detail = $result.Detail
        if ($result.Status -eq 'PASS') { $detail = $service.Detail }
        [pscustomobject]@{
            Test='AD DC port'
            Target=$result.Target
            Service=$service.Name
            Port=$service.Port
            Status=$result.Status
            Milliseconds=$result.Milliseconds
            Detail=$detail
        }
    }
}

function Invoke-AdLdapRootDseRequest {
    param([string]$Controller, [string[]]$Attributes)
    Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction Stop
    $connection = [System.DirectoryServices.Protocols.LdapConnection]::new($Controller)
    try {
        $connection.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $connection.Timeout = [timespan]::FromSeconds(10)
        $connection.SessionOptions.ProtocolVersion = 3
        $request = [System.DirectoryServices.Protocols.SearchRequest]::new(
            '',
            '(objectClass=*)',
            [System.DirectoryServices.Protocols.SearchScope]::Base,
            $Attributes
        )
        $connection.SendRequest($request)
    } finally {
        $connection.Dispose()
    }
}

function ConvertFrom-AdRootDseResponse {
    param($Response, [string]$Controller, [string[]]$Attributes)
    if ($Response.Entries.Count -ne 1) { throw "RootDSE returned $($Response.Entries.Count) entries; expected one." }
    $attributeSet = $Response.Entries[0].Attributes
    $row = [ordered]@{Test='LDAP RootDSE';Target=$Controller;Status='PASS'}
    foreach ($attribute in $Attributes) {
        $raw = $null
        if ($attributeSet -is [Collections.IDictionary]) {
            if ($attributeSet.Contains($attribute)) { $raw = $attributeSet[$attribute] }
        } elseif ($attributeSet.Contains($attribute)) {
            $raw = $attributeSet[$attribute].GetValues([string])
        }
        $row[$attribute] = @($raw) -join '; '
    }
    [pscustomobject]$row
}

function Get-AdRootDse {
    param([string]$Controller)
    $dcName = Get-AdController $Controller
    $attributes = @(
        'dnsHostName','defaultNamingContext','rootDomainNamingContext','configurationNamingContext',
        'schemaNamingContext','domainControllerFunctionality','domainFunctionality','forestFunctionality',
        'isGlobalCatalogReady','isSynchronized','supportedLDAPVersion','supportedSASLMechanisms'
    )
    try {
        $response = Invoke-AdLdapRootDseRequest $dcName $attributes
        ConvertFrom-AdRootDseResponse $response $dcName $attributes
    } catch {
        [pscustomobject]@{Test='LDAP RootDSE';Target=$dcName;Status='WARN';Detail=$_.Exception.Message}
    }
}

function Get-AdFsmoRoles {
    param($Context)
    Test-NetworkTarget $Context.Domain
    Invoke-AdNative 'netdom.exe' @('query',('/domain:' + $Context.Domain),'FSMO')
}

function Get-AdReplicationHealth {
    param([string]$Controller)
    $dcName = Get-AdController $Controller
    Invoke-AdNative 'repadmin.exe' @('/replsummary',$dcName,'/bysrc','/bydest','/sort:delta')
    Invoke-AdNative 'repadmin.exe' @('/showrepl',$dcName,'/all')
    Invoke-AdNative 'repadmin.exe' @('/queue',$dcName)
}

function Get-AdDcDiagnostics {
    param([string]$Controller)
    $dcName = Get-AdController $Controller
    foreach ($test in @('Advertising','Services','NetLogons','SysVolCheck','DFSREvent','Replications','DNS')) {
        Invoke-AdNative 'dcdiag.exe' @(('/s:' + $dcName),('/test:' + $test))
    }
}

function Get-AdEventSummary {
    param([string]$Controller, [ValidateRange(1,168)][int]$Hours = 24)
    $dcName = Get-AdController $Controller
    $start = (Get-Date).AddHours(-$Hours)
    $sources = @(
        [pscustomobject]@{Name='Directory Service';Log='Directory Service';Providers=@()}
        [pscustomobject]@{Name='DNS Server';Log='DNS Server';Providers=@()}
        [pscustomobject]@{Name='DFS Replication';Log='DFS Replication';Providers=@()}
        [pscustomobject]@{Name='Netlogon and KDC';Log='System';Providers=@('NETLOGON','Microsoft-Windows-Kerberos-Key-Distribution-Center')}
    )
    foreach ($source in $sources) {
        try {
            $null = Get-WinEvent -ListLog $source.Log -ComputerName $dcName -ErrorAction Stop
            $filter = @{LogName=$source.Log;StartTime=$start;Level=@(1,2,3)}
            if ($source.Providers.Count) { $filter.ProviderName = $source.Providers }
            $events = @(Get-WinEvent -ComputerName $dcName -FilterHashtable $filter -MaxEvents 25 -ErrorAction SilentlyContinue)
            if (-not $events.Count) {
                [pscustomobject]@{Test='AD event summary';Target=$dcName;Source=$source.Name;Status='PASS';Detail="No critical, error, or warning events returned in the last $Hours hours."}
                continue
            }
            foreach ($event in $events) {
                $message = ([string]$event.Message -replace '\s+',' ').Trim()
                if ($message.Length -gt 500) { $message = $message.Substring(0,497) + '...' }
                [pscustomobject]@{Test='AD event summary';Target=$dcName;Source=$source.Name;Status='WARN';Time=$event.TimeCreated;Provider=$event.ProviderName;Id=$event.Id;Level=$event.LevelDisplayName;Detail=$message}
            }
        } catch {
            [pscustomobject]@{Test='AD event summary';Target=$dcName;Source=$source.Name;Status='WARN';Detail=$_.Exception.Message}
        }
    }
}

function Test-AdObjectIdentity {
    param([string]$Identity)
    if ([string]::IsNullOrWhiteSpace($Identity) -or $Identity.Length -gt 512 -or $Identity -match '[\x00-\x1F\x7F]') {
        throw 'Enter one user or computer identity (SAM name, distinguished name, GUID, or SID).'
    }
}

function Get-AdUserDiagnostic {
    param([string]$Identity)
    Test-AdObjectIdentity $Identity
    $properties=@('Enabled','LockedOut','PasswordExpired','PasswordLastSet','PasswordNeverExpires','LastBadPasswordAttempt','BadPwdCount','LastLogonDate','UserPrincipalName','AccountExpirationDate')
    $user=Get-ADUser -Identity $Identity -Properties $properties -ErrorAction Stop
    [pscustomobject]@{
        Test='AD user';SamAccountName=$user.SamAccountName;UserPrincipalName=$user.UserPrincipalName;Enabled=$user.Enabled;LockedOut=$user.LockedOut
        PasswordExpired=$user.PasswordExpired;PasswordNeverExpires=$user.PasswordNeverExpires;PasswordLastSet=$user.PasswordLastSet
        LastBadPasswordAttempt=$user.LastBadPasswordAttempt;BadPasswordCount=$user.BadPwdCount;LastLogonEstimate=$user.LastLogonDate
        AccountExpiration=$user.AccountExpirationDate;DistinguishedName=$user.DistinguishedName
        Detail='LastLogonDate is replicated and approximate; this check does not reset passwords, unlock accounts, or change directory data.'
    }
}

function Get-AdComputerDiagnostic {
    param([string]$Identity)
    Test-AdObjectIdentity $Identity
    $properties=@('Enabled','OperatingSystem','OperatingSystemVersion','LastLogonDate','DNSHostName','TrustedForDelegation','TrustedToAuthForDelegation','ServicePrincipalName','PasswordLastSet')
    $computer=Get-ADComputer -Identity $Identity -Properties $properties -ErrorAction Stop
    [pscustomobject]@{
        Test='AD computer';Name=$computer.Name;DNSHostName=$computer.DNSHostName;Enabled=$computer.Enabled;OperatingSystem=$computer.OperatingSystem
        OperatingSystemVersion=$computer.OperatingSystemVersion;LastLogonEstimate=$computer.LastLogonDate;PasswordLastSet=$computer.PasswordLastSet
        TrustedForDelegation=$computer.TrustedForDelegation;TrustedToAuthForDelegation=$computer.TrustedToAuthForDelegation
        ServicePrincipalNames=@($computer.ServicePrincipalName) -join '; ';DistinguishedName=$computer.DistinguishedName
        Detail='LastLogonDate is replicated and approximate; delegation flags and SPNs are reported without changing the computer object.'
    }
}

function Test-AdSpnValue {
    param([string]$Spn)
    if ([string]::IsNullOrWhiteSpace($Spn) -or $Spn.Length -gt 512 -or $Spn.StartsWith('-') -or
        $Spn -match '[\s\x00-\x1F\x7F*?]' -or $Spn -notmatch '^[^/]+/.+$') {
        throw 'Enter one exact SPN without wildcards (for example HTTP/server.example.com).'
    }
}

function Find-AdSpn {
    param([string]$Spn)
    Test-AdSpnValue $Spn
    Invoke-AdNative 'setspn.exe' @('-Q',$Spn)
}

function Find-AdDuplicateSpn {
    Invoke-AdNative 'setspn.exe' @('-F','-X')
}

function Find-AdSubnetMapping {
    param([string]$Address,[object[]]$Subnets)
    $number=ConvertTo-DiscoveryNumber $Address
    $candidates=@()
    foreach($subnet in $Subnets){
        if([string]$subnet.Name -notmatch '^(\d{1,3}(?:\.\d{1,3}){3})/(\d|[12]\d|3[0-2])$'){continue}
        $prefix=[int]$Matches[2]
        $base=ConvertTo-DiscoveryNumber $Matches[1]
        [uint64]$size=[math]::Pow(2,32-$prefix)
        if([uint64]([math]::Floor($number/[double]$size)*$size) -eq $base){$candidates+=[pscustomobject]@{Subnet=$subnet;Prefix=$prefix}}
    }
    $candidates | Sort-Object Prefix -Descending | Select-Object -First 1
}

function Get-AdSiteSubnetDiagnostic {
    $siteResult=Invoke-AdNative 'nltest.exe' @('/dsgetsite')
    $currentSite='Unavailable'
    if($siteResult.ExitCode -eq 0){$currentSite=@($siteResult.Detail -split '[\r\n]+' | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})[0].Trim()}
    $subnets=@(Get-ADReplicationSubnet -Filter * -Properties Site -ErrorAction Stop)
    $addresses=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {$_.IPAddress -notmatch '^(127\.|169\.254\.|0\.0\.0\.0$)'})
    if(-not $addresses.Count){return [pscustomobject]@{Test='AD site/subnet';Status='WARN';CurrentSite=$currentSite;Detail='No usable local IPv4 addresses were found.'}}
    foreach($address in $addresses){
        $mapping=Find-AdSubnetMapping $address.IPAddress $subnets
        if(-not $mapping){[pscustomobject]@{Test='AD site/subnet';Status='WARN';Address=$address.IPAddress;Interface=$address.InterfaceAlias;CurrentSite=$currentSite;Detail='No matching IPv4 subnet object exists in Active Directory.'};continue}
        $site=[string]$mapping.Subnet.Site;$siteName=$site
        if($site -match '^CN=([^,]+)'){$siteName=$Matches[1]}
        $status=if($siteResult.ExitCode -eq 0 -and $siteName -eq $currentSite){'PASS'}else{'WARN'}
        [pscustomobject]@{Test='AD site/subnet';Status=$status;Address=$address.IPAddress;Interface=$address.InterfaceAlias;CurrentSite=$currentSite;MappedSubnet=$mapping.Subnet.Name;MappedSite=$siteName;Detail='Uses the longest matching IPv4 AD subnet. VPN and virtual adapters may legitimately map differently.'}
    }
}

function Test-AdPrivateIpv4 {
    param([string]$Address)
    $parsed=$null
    if(-not [Net.IPAddress]::TryParse($Address,[ref]$parsed) -or $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){return $false}
    $bytes=$parsed.GetAddressBytes()
    return $bytes[0] -eq 10 -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168) -or $bytes[0] -eq 127 -or ($bytes[0] -eq 169 -and $bytes[1] -eq 254)
}

function Get-AdDnsClientQuality {
    param($Context)
    $query='_ldap._tcp.dc._msdcs.'+$Context.Domain
    $rows=@(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {$_.ServerAddresses.Count})
    if(-not $rows.Count){return [pscustomobject]@{Test='AD DNS client';Status='WARN';Query=$query;Detail='No configured IPv4 DNS servers were reported.'}}
    foreach($row in $rows){foreach($server in @($row.ServerAddresses)){
        $public=-not (Test-AdPrivateIpv4 $server)
        try{
            $records=@(Resolve-DnsName -Server $server -Name $query -Type SRV -DnsOnly -ErrorAction Stop | Where-Object {$_.Type -eq 'SRV'})
            if(-not $records.Count){throw 'No AD domain-controller SRV records returned.'}
            $status=if($public){'WARN'}else{'PASS'}
            $detail="Returned $($records.Count) AD SRV record(s)."
            if($public){$detail+=' Resolver is publicly routable; verify it is an approved authoritative/internal AD DNS service.'}
            [pscustomobject]@{Test='AD DNS client';Status=$status;Interface=$row.InterfaceAlias;Server=$server;Query=$query;Targets=@($records.NameTarget | Select-Object -Unique) -join ', ';Detail=$detail}
        }catch{[pscustomobject]@{Test='AD DNS client';Status='WARN';Interface=$row.InterfaceAlias;Server=$server;Query=$query;Detail=$_.Exception.Message}}
    }}
}

function Get-AdChecks {
    @(
        [pscustomobject]@{Key='1'; Id='ad-context'; Name='Domain membership and machine role'; MinPS='5.0'; Commands=@('Get-CimInstance'); Admin=$false; Roles=@(); Action={param($c,$dc) $c}}
        [pscustomobject]@{Key='2'; Id='ad-discovery'; Name='DC discovery and AD site'; MinPS='5.0'; Commands=@('nltest.exe'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdDiscovery $c}}
        [pscustomobject]@{Key='3'; Id='ad-dns'; Name='AD LDAP / Kerberos SRV and DC addresses'; MinPS='5.0'; Commands=@('Resolve-DnsName'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdDns $c}}
        [pscustomobject]@{Key='4'; Id='ad-secure'; Name='Computer secure channel (no repair)'; MinPS='5.0'; Commands=@('Test-ComputerSecureChannel'); Admin=$false; Roles=@('Domain member'); Action={param($c,$dc) Test-AdSecureChannel $dc}}
        [pscustomobject]@{Key='5'; Id='ad-time'; Name='Time source / status and DC offset'; MinPS='5.0'; Commands=@('w32tm.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdTime $dc}}
        [pscustomobject]@{Key='6'; Id='ad-shares'; Name='SYSVOL and NETLOGON access'; MinPS='5.0'; Commands=@(); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Test-AdShares $dc}}
        [pscustomobject]@{Key='7'; Id='ad-identity'; Name='Current identity and Kerberos tickets / sessions'; MinPS='5.0'; Commands=@('whoami.exe','klist.exe'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdIdentity}}
        [pscustomobject]@{Key='8'; Id='ad-ports'; Name='Domain controller service ports'; MinPS='5.0'; Commands=@(); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Test-AdDcPorts $dc}}
        [pscustomobject]@{Key='9'; Id='ad-rootdse'; Name='LDAP RootDSE capabilities and naming contexts'; MinPS='5.0'; Commands=@(); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdRootDse $dc}}
        [pscustomobject]@{Key='10'; Id='ad-fsmo'; Name='FSMO role owners'; MinPS='5.0'; Commands=@('netdom.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdFsmoRoles $c}}
        [pscustomobject]@{Key='11'; Id='ad-replication'; Name='AD replication summary, inbound status, and queue'; MinPS='5.0'; Commands=@('repadmin.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdReplicationHealth $dc}}
        [pscustomobject]@{Key='12'; Id='ad-dcdiag'; Name='Selected domain controller diagnostics'; MinPS='5.0'; Commands=@('dcdiag.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdDcDiagnostics $dc}}
        [pscustomobject]@{Key='13'; Id='ad-events'; Name='Recent AD, DNS, DFSR, Netlogon, and KDC events'; MinPS='5.0'; Commands=@('Get-WinEvent'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc) Get-AdEventSummary $dc}}
        [pscustomobject]@{Key='14'; Id='ad-site-subnet'; Name='Local AD site and subnet mapping'; MinPS='5.0'; Commands=@('nltest.exe','Get-ADReplicationSubnet','Get-NetIPAddress'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Get-AdSiteSubnetDiagnostic}}
        [pscustomobject]@{Key='15'; Id='ad-user'; Name='Targeted AD user diagnostic'; MinPS='5.0'; Commands=@('Get-ADUser'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Get-AdUserDiagnostic $value}}
        [pscustomobject]@{Key='16'; Id='ad-computer'; Name='Targeted AD computer diagnostic'; MinPS='5.0'; Commands=@('Get-ADComputer'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Get-AdComputerDiagnostic $value}}
        [pscustomobject]@{Key='17'; Id='ad-spn'; Name='Exact service principal name lookup'; MinPS='5.0'; Commands=@('setspn.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Find-AdSpn $value}}
        [pscustomobject]@{Key='18'; Id='ad-spn-duplicates'; Name='Duplicate SPN scan (forest-wide; potentially slow)'; MinPS='5.0'; Commands=@('setspn.exe'); Admin=$true; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Find-AdDuplicateSpn}}
        [pscustomobject]@{Key='19'; Id='ad-dns-quality'; Name='DNS client quality and per-resolver AD SRV test'; MinPS='5.0'; Commands=@('Get-DnsClientServerAddress','Resolve-DnsName'); Admin=$false; Roles=@('Domain member','Domain controller'); Action={param($c,$dc,$value) Get-AdDnsClientQuality $c}}
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
    param([string]$Id, [string]$Controller, [string]$InputValue)
    $entry = Get-AdChecks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $entry) { throw "Unknown AD check: $Id" }
    $context = Get-AdContext
    $availability = Get-AdAvailability $entry $context
    if (-not $availability.Available) { throw $availability.Reason }
    & $entry.Action $context $Controller $InputValue
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
        if (-not [int]::TryParse((Read-PcInput 'Plan number'),[ref]$number) -or $number -lt 1 -or $number -gt $plans.Count) { throw 'Choose a listed plan.' }
        $repairParameters.PlanGuid=$plans[$number-1].Guid
    }
    if ($Entry.Id -eq 'nic-awake') {
        $nics=@(Get-NetAdapter -Physical -ErrorAction Stop)
        $nics | Select-Object InterfaceIndex,Name,Status,InterfaceDescription | Format-Table -AutoSize | Out-Host
        $index=-1
        if (-not [int]::TryParse((Read-PcInput 'NIC InterfaceIndex'),[ref]$index) -or $index -notin $nics.InterfaceIndex) { throw 'Choose a listed physical NIC.' }
        $repairParameters.InterfaceIndex=$index
    }
    if ($Entry.Id -eq 'repair-trust') {
        $answer = Read-PcInput 'DC hostname [automatic discovery]'
        if ($answer) { $repairParameters.Controller = $answer.Trim() }
    }
    if ($Entry.Id -eq 'renew-dhcp') {
        $adapters = @(Get-NetworkDhcpAdapters)
        if ($adapters.Count -eq 0) { throw 'No active DHCP-enabled IPv4 adapters found.' }
        $adapters | Format-Table -AutoSize | Out-Host
        $index = -1
        if (-not [int]::TryParse((Read-PcInput 'InterfaceIndex to renew'), [ref]$index) -or $index -notin $adapters.InterfaceIndex) { throw 'Choose an InterfaceIndex from the list.' }
        $repairParameters.InterfaceIndex = $index
    }
    Invoke-NetworkRepair @repairParameters
}
# BEGIN NETWORK DISCOVERY
# Embedded into Windows-Toolkit.ps1 for the single-download launcher.
function ConvertTo-DiscoveryMac([string]$Mac) {
    $value=$Mac.Trim()
    if($value -notmatch '^(?:[0-9A-Fa-f]{12}|(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}|[0-9A-Fa-f]{4}(?:\.[0-9A-Fa-f]{4}){2})$'){return ''}
    return ($value -replace '[:.\-]','').ToUpperInvariant()
}
function Get-DiscoveryOuiDatabase {
    param([string]$CacheDirectory=(Join-Path $env:LOCALAPPDATA 'Random-Toolkits\oui'))
    $map=@{};$date='';$status='Unavailable';$cache=Join-Path $CacheDirectory 'assignments.csv'
    try{
        if(Test-Path -LiteralPath $cache){
            foreach($row in (Import-Csv -LiteralPath $cache -Encoding UTF8 -ErrorAction Stop)){
                if($row.Assignment -notmatch '^(?:[A-F0-9]{6}|[A-F0-9]{7}|[A-F0-9]{9})$' -or [string]::IsNullOrWhiteSpace($row.Organization)){throw 'Invalid cached assignment data.'}
                $map[$row.Assignment]=$row.Organization
            }
            if(-not $map.Count){throw 'Empty cached assignment data.'}
            $date=(Get-Item -LiteralPath $cache).LastWriteTimeUtc.ToString('o');$status='Cached'
        }
    }catch{$map=@{};$date=''}
    $temporary=New-Object 'Collections.Generic.List[string]'
    try{
        $attempt=Join-Path $CacheDirectory 'last-attempt.txt'
        $fresh=$date -and ([datetime]::UtcNow-[datetime]::Parse($date).ToUniversalTime()).TotalDays -lt 30
        $recent=(Test-Path -LiteralPath $attempt) -and ([datetime]::UtcNow-(Get-Item -LiteralPath $attempt).LastWriteTimeUtc).TotalHours -lt 24
        if(-not $fresh -and -not $recent){
            $null=[IO.Directory]::CreateDirectory($CacheDirectory)
            [IO.File]::WriteAllText($attempt,[datetime]::UtcNow.ToString('o'))
            Write-Host 'Downloading IEEE MAC assignment lists for local lookup (cached for 30 days)...'
            $records=New-Object 'Collections.Generic.List[object]';$newMap=@{}
            foreach($source in @(@('oui/oui.csv',6,'MA-L'),@('oui28/mam.csv',7,'MA-M'),@('oui36/oui36.csv',9,'MA-S'))){
                $file=Join-Path $CacheDirectory ([guid]::NewGuid().ToString('N')+'.tmp');$temporary.Add($file)
                Invoke-WebRequest -UseBasicParsing -Uri ('https://standards-oui.ieee.org/'+$source[0]) -OutFile $file -TimeoutSec 15 -ErrorAction Stop
                $count=0
                foreach($row in (Import-Csv -LiteralPath $file -Encoding UTF8 -ErrorAction Stop)){
                    if($row.Registry -ne $source[2] -or $row.Assignment -notmatch ('^[A-Fa-f0-9]{'+$source[1]+'}$') -or [string]::IsNullOrWhiteSpace($row.'Organization Name')){throw 'Invalid IEEE assignment list.'}
                    $key=$row.Assignment.ToUpperInvariant();$name=$row.'Organization Name' -replace '[\x00-\x1F\x7F]',' '
                    $records.Add([pscustomobject]@{Assignment=$key;Organization=$name});$newMap[$key]=$name;$count++
                }
                if(-not $count){throw 'Empty IEEE assignment list.'}
            }
            $staged=Join-Path $CacheDirectory ([guid]::NewGuid().ToString('N')+'.tmp');$temporary.Add($staged)
            $records.ToArray() | Export-Csv -LiteralPath $staged -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Move-Item -LiteralPath $staged -Destination $cache -Force -ErrorAction Stop
            $map=$newMap;$date=(Get-Item -LiteralPath $cache).LastWriteTimeUtc.ToString('o');$status='Downloaded'
        }elseif($map.Count -and -not $fresh){$status='Stale cache'}
    }catch{
        $status=if($map.Count){'Stale cache (refresh unavailable)'}else{'Unavailable (download/cache error)'}
        Write-Verbose $_.Exception.Message
        Write-Warning 'IEEE lookup data could not be refreshed. Discovery still works; cached assignments will be used when available.'
    }finally{foreach($file in $temporary){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}}}
    [pscustomobject]@{Entries=$map;RetrievedUtc=$date;Status=$status}
}
function Resolve-DiscoveryOui([string]$Mac,$Database) {
    $value=ConvertTo-DiscoveryMac $Mac;$prefix='';$vendor='';$kind='Invalid MAC'
    if($value){
        $first=[Convert]::ToInt32($value.Substring(0,2),16)
        if($value -eq '000000000000'){$kind='Unspecified'}
        elseif($value -eq 'FFFFFFFFFFFF'){$kind='Broadcast'}
        elseif($first -band 1){$kind='Multicast'}
        elseif($first -band 2){$kind='Locally administered (may be randomized)'}
        elseif(-not $Database -or -not $Database.Entries.Count){$kind='Database unavailable'}
        else{
            $kind='No IEEE match'
            foreach($length in @(9,7,6)){
                $candidate=$value.Substring(0,$length)
                if($Database.Entries.ContainsKey($candidate)){$prefix=$candidate+'/'+($length*4);$vendor=$Database.Entries[$candidate];$kind='IEEE assignment';break}
            }
        }
    }
    $formatted=if($value){([regex]::Matches($value,'..') | ForEach-Object {$_.Value}) -join ':'}else{''}
    [pscustomobject]@{MAC=$formatted;OuiPrefix=$prefix;Vendor=$vendor;MacStatus=$kind}
}
function Add-DiscoveryMacInfo($Rows,$Database,[object[]]$Neighbors) {
    $index=@{}
    foreach($neighbor in $Neighbors){
        if([string]$neighbor.State -notin @('Reachable','Stale','Delay','Probe','Permanent')){continue}
        $mac=ConvertTo-DiscoveryMac ([string]$neighbor.LinkLayerAddress)
        if(-not $mac -or $mac -in @('000000000000','FFFFFFFFFFFF')){continue}
        if(-not $index.ContainsKey([string]$neighbor.IPAddress)){$index[[string]$neighbor.IPAddress]=@()}
        $index[[string]$neighbor.IPAddress]+=$neighbor
    }
    foreach($row in $Rows){
        $matches=@($index[[string]$row.Address] | Where-Object {$null -ne $_})
        $macs=@($matches | ForEach-Object {ConvertTo-DiscoveryMac $_.LinkLayerAddress} | Select-Object -Unique)
        $info=Resolve-DiscoveryOui '' $Database
        if($macs.Count -eq 1){$info=Resolve-DiscoveryOui $macs[0] $Database}
        elseif($macs.Count -gt 1){$info.MacStatus='Ambiguous neighbor entries'}
        else{$info.MacStatus='No neighbor MAC available'}
        foreach($property in $info.PSObject.Properties){$row | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force}
        $row | Add-Member -NotePropertyName MacInterfaces -NotePropertyValue (($matches | Select-Object -ExpandProperty InterfaceIndex -Unique) -join ',') -Force
        $row | Add-Member -NotePropertyName MacNeighborState -NotePropertyValue (($matches | ForEach-Object {[string]$_.State} | Select-Object -Unique) -join ',') -Force
        $row | Add-Member -NotePropertyName OuiRetrievedUtc -NotePropertyValue $Database.RetrievedUtc -Force
        $row | Add-Member -NotePropertyName OuiDatabaseStatus -NotePropertyValue $Database.Status -Force
    }
}
function ConvertTo-DiscoveryNumber([string]$Address) {
    if($Address -notmatch '^\d{1,3}(\.\d{1,3}){3}$'){throw 'Use dotted-decimal IPv4 addresses.'}
    [uint64]$value=0
    foreach($part in $Address.Split('.')){if([int]$part -gt 255){throw 'IPv4 octets must be 0-255.'};$value=$value*256+[int]$part}
    return $value
}
function ConvertFrom-DiscoveryNumber([uint64]$Value) {
    return ('{0}.{1}.{2}.{3}' -f (($Value -shr 24) -band 255),(($Value -shr 16) -band 255),(($Value -shr 8) -band 255),($Value -band 255))
}
function Get-DiscoveryTargets([string]$Scope) {
    $text=$Scope.Trim();[uint64]$first=0;[uint64]$last=0
    if($text.Contains('/')){
        $parts=$text.Split('/');$prefix=0
        if($parts.Count -ne 2 -or -not [int]::TryParse($parts[1],[ref]$prefix) -or $prefix -lt 22 -or $prefix -gt 32){throw 'Use an IPv4 CIDR prefix from /22 to /32 (maximum 1024 addresses).'}
        $ip=ConvertTo-DiscoveryNumber $parts[0];[uint64]$size=[math]::Pow(2,32-$prefix)
        $first=[uint64]([math]::Floor($ip/[double]$size)*$size);$last=$first+$size-1
        if($prefix -le 30){$first++;$last--}
    }elseif($text.Contains('-')){
        $parts=$text.Split('-');if($parts.Count -ne 2){throw 'Use startIPv4-endIPv4.'}
        $first=ConvertTo-DiscoveryNumber $parts[0].Trim();$last=ConvertTo-DiscoveryNumber $parts[1].Trim()
    }else{$first=ConvertTo-DiscoveryNumber $text;$last=$first}
    if($last -lt $first -or $last-$first+1 -gt 1024){throw 'Choose an ascending range of at most 1024 addresses.'}
    if($first -eq 0 -or $last -ge 3758096384){throw 'Unspecified, multicast and reserved broadcast targets are not supported.'}
    for($n=$first;$n -le $last;$n++){ConvertFrom-DiscoveryNumber $n}
}
function Get-DiscoveryInterfaceScopes([object[]]$Addresses) {
    $rows=New-Object 'Collections.Generic.List[object]'
    foreach($address in $Addresses){
        try{
            $ip=[string]$address.IPAddress;$value=ConvertTo-DiscoveryNumber $ip;$prefix=[int]$address.PrefixLength
            if($value -eq 0 -or $value -ge 3758096384 -or $ip -like '127.*' -or $prefix -lt 0 -or $prefix -gt 32){continue}
            if($address.PSObject.Properties['AddressState'] -and [string]$address.AddressState -notin @('Preferred','Deprecated')){continue}
            # A /22 is the largest range accepted by the scanner. For broader connected
            # networks, scan the /22 window containing this interface instead of failing.
            $scanPrefix=[math]::Max(22,$prefix);[uint64]$size=[math]::Pow(2,32-$scanPrefix)
            [uint64]$network=[math]::Floor($value/[double]$size)*$size
            $scope=(ConvertFrom-DiscoveryNumber $network)+'/'+$scanPrefix
            $count=@(Get-DiscoveryTargets $scope).Count
            $note=if($ip -like '169.254.*'){'link-local; excluded from A'}elseif($prefix -lt 22){"subnet /$prefix; capped to /22"}else{'connected subnet'}
            $rows.Add([pscustomobject]@{Number=0;Interface=[string]$address.InterfaceAlias;Address=$ip;PrefixLength=$prefix;AutoScope=$scope;Addresses=$count;Routable=($ip -notlike '169.254.*');Note=$note})
        }catch{Write-Verbose ("Ignoring unusable interface address: "+$_.Exception.Message)}
    }
    $sorted=@($rows.ToArray() | Sort-Object @{Expression='Routable';Descending=$true},Interface,Address)
    for($index=0;$index -lt $sorted.Count;$index++){$sorted[$index].Number=$index+1}
    return $sorted
}
function Select-DiscoveryScopes([object[]]$Interfaces) {
    if(-not $Interfaces.Count){
        Write-Warning 'No usable local IPv4 interfaces were detected.'
        return @((Read-PcInput 'Target CIDR, single IPv4 or startIPv4-endIPv4 (max 1024 addresses)'))
    }
    Write-Host ''
    $Interfaces | Select-Object @{n='#';e={$_.Number}},Interface,Address,@{n='Prefix';e={'/'+$_.PrefixLength}},AutoScope,Addresses,Note | Format-Table -AutoSize | Out-Host
    $answer=Read-PcInput 'Interface number(s), A: all routable interfaces, or M: manual target'
    if($answer.Trim() -eq 'M'){
        return @((Read-PcInput 'Target CIDR, single IPv4 or startIPv4-endIPv4 (max 1024 addresses)'))
    }
    $selected=@()
    if($answer.Trim() -eq 'A'){$selected=@($Interfaces | Where-Object Routable)}
    else{
        foreach($token in $answer.Split(',')){
            $number=0
            if(-not [int]::TryParse($token.Trim(),[ref]$number)){throw 'Choose A, M, or comma-separated interface numbers.'}
            $match=@($Interfaces | Where-Object Number -eq $number)
            if($match.Count -ne 1){throw "Interface number $number is not available."}
            $selected+=$match[0]
        }
    }
    $scopes=@($selected | Select-Object -ExpandProperty AutoScope -Unique)
    if(-not $scopes.Count){throw 'No routable IPv4 interfaces are available. Choose M for a manual target.'}
    return $scopes
}
function Get-DiscoveryPorts([string]$Text) {
    $ports=@($Text.Split(',') | ForEach-Object {
        $port=0;if(-not [int]::TryParse($_.Trim(),[ref]$port) -or $port -lt 1 -or $port -gt 65535){throw 'Ports must be comma-separated integers from 1 to 65535.'};$port
    } | Select-Object -Unique)
    if($ports.Count -gt 16){throw 'Choose at most 16 TCP ports.'}
    return $ports
}
function Read-DiscoveryCancelKey {
    try{if(-not [Console]::IsInputRedirected -and [Console]::KeyAvailable){return [Console]::ReadKey($true).Key}}catch{}
}
function Invoke-NetworkDiscovery {
    param([Parameter(Mandatory=$true)][string]$Scope,[int[]]$Ports=@(22,80,443,445,3389,9100),
        [ValidateRange(100,2000)][int]$TimeoutMs=400,[ValidateRange(1,64)][int]$Concurrency=32)
    $targets=@(Get-DiscoveryTargets $Scope)
    $Ports=@(Get-DiscoveryPorts ($Ports -join ','))
    $worker={param($ip,$ports,$timeout)
        $pingStatus='No response';$latency=$null;$ping=New-Object Net.NetworkInformation.Ping
        try{$reply=$ping.Send($ip,$timeout);$pingStatus=[string]$reply.Status;if($reply.Status -eq 'Success'){$latency=$reply.RoundtripTime}}
        catch{$pingStatus='Error'}finally{$ping.Dispose()}
        $open=@();$closed=@();$unanswered=@();$errors=@()
        foreach($port in $ports){
            $client=New-Object Net.Sockets.TcpClient;$pending=$null
            try{
                $pending=$client.BeginConnect($ip,$port,$null,$null)
                if($pending.AsyncWaitHandle.WaitOne($timeout)){$client.EndConnect($pending);$open+=$port}else{$unanswered+=$port}
            }catch{
                $errorObject=$_.Exception;while($errorObject.InnerException){$errorObject=$errorObject.InnerException}
                if($errorObject -is [Net.Sockets.SocketException] -and $errorObject.SocketErrorCode -eq 'ConnectionRefused'){$closed+=$port}
                else{$errors+=$port}
            }finally{$client.Close();if($pending){$pending.AsyncWaitHandle.Close()}}
        }
        [pscustomobject]@{Address=$ip;Responded=($pingStatus -eq 'Success' -or $open.Count -gt 0 -or $closed.Count -gt 0);Ping=$pingStatus;LatencyMs=$latency;OpenTCP=($open -join ',');ClosedTCP=($closed -join ',');NoResponseTCP=($unanswered -join ',');ErrorTCP=($errors -join ',')}
    }
    $pool=[RunspaceFactory]::CreateRunspacePool(1,$Concurrency);$pool.Open()
    $active=New-Object Collections.ArrayList;$rows=New-Object 'Collections.Generic.List[object]';$next=0;$cancelled=$false
    try{
        while($next -lt $targets.Count -or $active.Count){
            while($next -lt $targets.Count -and $active.Count -lt $Concurrency){
                $ps=[PowerShell]::Create();$ps.RunspacePool=$pool
                $null=$ps.AddScript($worker.ToString()).AddArgument($targets[$next]).AddArgument($Ports).AddArgument($TimeoutMs)
                $null=$active.Add([pscustomobject]@{Shell=$ps;Handle=$ps.BeginInvoke()});$next++
            }
            foreach($job in @($active.ToArray())){
                if($job.Handle.IsCompleted){
                    try{foreach($row in $job.Shell.EndInvoke($job.Handle)){$rows.Add($row)};if($job.Shell.HadErrors){throw ($job.Shell.Streams.Error | Out-String)}}
                    finally{$job.Shell.Dispose();$active.Remove($job)}
                }
            }
            Write-Progress -Activity 'Network discovery' -Status ("{0}/{1} addresses complete | B: stop and browse partial results" -f $rows.Count,$targets.Count) -PercentComplete (100*$rows.Count/$targets.Count)
            $key=Read-DiscoveryCancelKey
            if($key -eq 'B' -or $key -eq 'Escape'){$cancelled=$true;break}
            if($active.Count){Start-Sleep -Milliseconds 50}
        }
    }finally{
        foreach($job in $active){$job.Shell.Stop();$job.Shell.Dispose()}
        $pool.Close();$pool.Dispose();Write-Progress -Activity 'Network discovery' -Completed
    }
    [pscustomobject]@{Scope=$Scope;Requested=$targets.Count;Completed=$rows.Count;Cancelled=$cancelled;Rows=@($rows.ToArray() | Sort-Object {ConvertTo-DiscoveryNumber $_.Address})}
}
function Invoke-NetworkDiscoveryScopes {
    param([Parameter(Mandatory=$true)][string[]]$Scopes,[int[]]$Ports=@(22,80,443,445,3389,9100),
        [ValidateRange(100,2000)][int]$TimeoutMs=400,[ValidateRange(1,64)][int]$Concurrency=32)
    $requested=0
    foreach($scope in $Scopes){$requested+=@(Get-DiscoveryTargets $scope).Count}
    $rows=New-Object 'Collections.Generic.List[object]';$completed=0;$cancelled=$false
    foreach($scope in $Scopes){
        $targets=@(Get-DiscoveryTargets $scope)
        Write-Host ("Scanning {0} through {1}: {2} addresses; TCP ports {3}. B stops the scan." -f $targets[0],$targets[-1],$targets.Count,($Ports -join ','))
        $scan=Invoke-NetworkDiscovery -Scope $scope -Ports $Ports -TimeoutMs $TimeoutMs -Concurrency $Concurrency
        foreach($row in $scan.Rows){$rows.Add($row)};$completed+=$scan.Completed
        if($scan.Cancelled){$cancelled=$true;break}
    }
    [pscustomobject]@{Scope=($Scopes -join '; ');Scopes=@($Scopes);Requested=$requested;Completed=$completed;Cancelled=$cancelled;Rows=@($rows.ToArray() | Sort-Object {ConvertTo-DiscoveryNumber $_.Address})}
}
function New-NetworkDiscoveryMenuItem($Row,[switch]$ProbeView) {
    $open=if([string]::IsNullOrWhiteSpace([string]$Row.OpenTCP)){'none'}else{[string]$Row.OpenTCP}
    $labelParts=@(
        [pscustomobject]@{Text=([string]$Row.Address);Color='Cyan'}
        [pscustomobject]@{Text=' | TCP open: ';Color='DarkGray'}
        [pscustomobject]@{Text=$open;Color=$(if($open -eq 'none'){'DarkGray'}else{'Yellow'})}
    )
    if($ProbeView){
        $detail="Ping: $($Row.Ping) | $($Row.LatencyMs) ms | Open: $($Row.OpenTCP) | Closed: $($Row.ClosedTCP) | No response: $($Row.NoResponseTCP) | Errors: $($Row.ErrorTCP)"
        $pingColor=if($Row.Ping -eq 'Success'){'Green'}elseif($Row.Ping -eq 'Error'){'Red'}else{'DarkGray'}
        $detailParts=@(
            [pscustomobject]@{Text='Ping: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.Ping);Color=$pingColor}
            [pscustomobject]@{Text=(' | '+[string]$Row.LatencyMs+' ms | Open: ');Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.OpenTCP);Color='Yellow'}
            [pscustomobject]@{Text=' | Closed: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.ClosedTCP);Color='Gray'}
            [pscustomobject]@{Text=' | No response: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.NoResponseTCP);Color='DarkGray'}
            [pscustomobject]@{Text=' | Errors: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.ErrorTCP);Color='Red'}
        )
    }else{
        $detail="MAC: $($Row.MAC) | $($Row.Vendor) | $($Row.MacStatus)"
        $detailParts=@(
            [pscustomobject]@{Text='MAC: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.MAC);Color='Magenta'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.Vendor);Color='Cyan'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.MacStatus);Color='Gray'}
        )
    }
    [pscustomobject]@{Id=$Row.Address;Label=($Row.Address+' | TCP open: '+$Row.OpenTCP);Detail=$detail;LabelParts=$labelParts;DetailParts=$detailParts;SearchText=($Row.MAC+' '+$Row.Vendor+' '+$Row.Ping);Data=$Row}
}
function Start-NetworkDiscovery {
    Write-Host 'NETWORK DISCOVERY | IPv4 ICMP + TCP connect | No administrator required' -ForegroundColor Cyan
    $interfaces=@()
    if(Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue){$interfaces=@(Get-DiscoveryInterfaceScopes @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue))}
    $scopes=@(Select-DiscoveryScopes $interfaces)
    foreach($scope in $scopes){$null=@(Get-DiscoveryTargets $scope)}
    $text=Read-PcInput 'TCP ports [22,80,443,445,3389,9100; maximum 16]'
    if([string]::IsNullOrWhiteSpace($text)){$text='22,80,443,445,3389,9100'}
    $ports=@(Get-DiscoveryPorts $text)
    $timeout=400;$answer=Read-PcInput 'Probe timeout milliseconds [400; 100-2000]'
    if(-not [string]::IsNullOrWhiteSpace($answer)){
        if(-not [int]::TryParse($answer,[ref]$timeout) -or $timeout -lt 100 -or $timeout -gt 2000){throw 'Timeout must be 100-2000 milliseconds.'}
    }
    $result=Invoke-NetworkDiscoveryScopes -Scopes $scopes -Ports $ports -TimeoutMs $timeout
    $neighbors=@()
    try{if(Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue){$neighbors=@(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)}}catch{Write-Warning 'Neighbor cache unavailable; MAC addresses will be omitted.'}
    $database=Get-DiscoveryOuiDatabase
    Add-DiscoveryMacInfo $result.Rows $database $neighbors
    $state=@{};$showAll=$false;$probeView=$false
    while($true){
        $rows=@($result.Rows | Where-Object {$showAll -or $_.Responded})
        $menu=@(foreach($row in $rows){New-NetworkDiscoveryMenuItem $row -ProbeView:$probeView})
        $description="$($result.Completed)/$($result.Requested) checked | Partial/cancelled: $($result.Cancelled). No response does not mean offline; MAC/vendor are unverified cache observations."
        $choice=Show-PcMenu -Title 'Windows > Network > Discovery' -Items $menu -State $state -Filterable -Refreshable -Description $description -Commands @{A=('All/responding (all: '+$showAll+')');D='MAC/probe view';M='Lookup MAC';E='Export all scan rows to CSV';L='Scan and vendor-data notes'}
        switch($choice.Action){
            'Back'{return}
            'Select'{Show-PcListDetails $choice.Item.Data 'Device observations'}
            'Refresh'{
                Write-Host "Rescan the same scope(s): $($scopes -join ', '); ports: $($ports -join ', ')"
                $result=Invoke-NetworkDiscoveryScopes -Scopes $scopes -Ports $ports -TimeoutMs $timeout
                $neighbors=@();try{if(Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue){$neighbors=@(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)}}catch{Write-Warning 'Neighbor cache unavailable.'}
                Add-DiscoveryMacInfo $result.Rows $database $neighbors
            }
            'Command'{switch($choice.Command){
                'A'{$showAll=-not $showAll}
                'D'{$probeView=-not $probeView}
                'L'{Show-PcListDetails ([pscustomobject]@{Scope=$result.Scope;Completed=$result.Completed;Requested=$result.Requested;Cancelled=$result.Cancelled;IEEEStatus=$database.Status;RetrievedUTC=$database.RetrievedUtc;Notes='No response does not mean offline. Open ports do not identify services/device type. Closed means refused. MACs are exact-IP neighbor-cache observations, possibly stale/proxied. Routed targets usually have no MAC. Local/randomized MACs have no vendor attribution; vendor is the registered assignee, not verified identity.'}) 'Scan notes'}
                'M'{try{Show-PcListDetails (Resolve-DiscoveryOui (Read-PcInput 'MAC address') $database) 'MAC lookup'}catch [OperationCanceledException]{}}
                'E'{
                    try{$path=Read-PcInput 'New CSV file path';if(Test-Path -LiteralPath $path){throw 'Choose a new filename; existing files are not overwritten.'};$result.Rows | Select-Object *,@{n='ScanScope';e={$result.Scope}},@{n='ScanCancelled';e={$result.Cancelled}},@{n='AddressesRequested';e={$result.Requested}},@{n='AddressesCompleted';e={$result.Completed}} | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop;Write-Host "Saved: $path";Wait-PcMenuReturn}
                    catch [OperationCanceledException]{}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn}
                }
            }}
        }
    }
}
# END NETWORK DISCOVERY

# BEGIN NETWORK CONNECTIONS
function Format-PcSocketEndpoint {
    param([string]$Address,[int]$Port)
    if($Address.Contains(':')){return ('[{0}]:{1}' -f $Address,$Port)}
    return ('{0}:{1}' -f $Address,$Port)
}
function Get-PcNetworkConnections {
    $issues=New-Object 'Collections.Generic.List[string]'
    $sockets=New-Object 'Collections.Generic.List[object]'
    foreach($protocol in @('TCP','UDP')){
        $command=if($protocol -eq 'TCP'){'Get-NetTCPConnection'}else{'Get-NetUDPEndpoint'}
        try{
            if(-not (Get-Command $command -ErrorAction SilentlyContinue)){throw "$command is unavailable on this Windows installation."}
            foreach($socket in @(& $command -ErrorAction Stop)){$sockets.Add([pscustomobject]@{Protocol=$protocol;Socket=$socket})}
        }catch{$issues.Add($protocol+': '+$_.Exception.Message)}
    }
    $processes=@{}
    try{
        foreach($process in @(Get-CimInstance Win32_Process -Property ProcessId,Name,ExecutablePath,CreationDate -OperationTimeoutSec 5 -ErrorAction Stop)){
            $processes[[string]$process.ProcessId]=$process
        }
    }catch{$issues.Add('Process metadata: '+$_.Exception.Message)}
    $rows=New-Object 'Collections.Generic.List[object]'
    $identities=@{}
    foreach($entry in $sockets){
        $socket=$entry.Socket;$ownerId=[long]$socket.OwningProcess
        $local=Format-PcSocketEndpoint ([string]$socket.LocalAddress) ([int]$socket.LocalPort)
        $remote=if($entry.Protocol -eq 'TCP'){Format-PcSocketEndpoint ([string]$socket.RemoteAddress) ([int]$socket.RemotePort)}else{'*'}
        $state=if($entry.Protocol -eq 'TCP'){[string]$socket.State}else{'Bound'}
        $name='Unavailable / exited';$path=$null;$ownership='Best-effort PID lookup; snapshots are not atomic.'
        if($ownerId -eq 0){$name='Unattributed';$ownership='Windows supplied PID 0; no live process is attributed.'}
        elseif($processes.ContainsKey([string]$ownerId)){
            $process=$processes[[string]$ownerId];$reused=$false
            if($socket.CreationTime -is [datetime] -and $process.CreationDate -is [datetime] -and $socket.CreationTime.Year -ge 2000){
                $reused=($process.CreationDate.ToUniversalTime() - $socket.CreationTime.ToUniversalTime()).TotalSeconds -gt 2
            }
            if($reused){$name='PID reused / exited';$ownership='Current process started after this endpoint; ownership withheld.'}
            else{$name=[string]$process.Name;$path=[string]$process.ExecutablePath}
        }
        $pathStatus=if($path){'Available'}else{'Unavailable (permissions, exited process or kernel/unattributed endpoint)'}
        $identity=$entry.Protocol+'|'+$local+'|'+$remote+'|'+$ownerId+'|'+$socket.CreationTime
        $base=$identity;$suffix=1;while($identities.ContainsKey($identity)){$suffix++;$identity=$base+'|'+$suffix};$identities[$identity]=$true
        $rows.Add([pscustomobject]@{Id=$identity;Protocol=$entry.Protocol;State=$state;LocalEndpoint=$local;RemoteEndpoint=$remote;LocalAddress=$socket.LocalAddress;LocalPort=$socket.LocalPort;RemoteAddress=$(if($entry.Protocol -eq 'TCP'){$socket.RemoteAddress}else{$null});RemotePort=$(if($entry.Protocol -eq 'TCP'){$socket.RemotePort}else{$null});ProcessId=$ownerId;ProcessName=$name;ExecutablePath=$path;PathStatus=$pathStatus;Ownership=$ownership;Created=$socket.CreationTime})
    }
    [pscustomobject]@{CollectedAt=(Get-Date);Rows=@($rows.ToArray() | Sort-Object Protocol,@{Expression={if($_.State -eq 'Listen'){0}else{1}}},LocalPort,LocalAddress,RemoteEndpoint,ProcessId);Issues=@($issues.ToArray())}
}
function New-PcNetworkConnectionMenuItem {
    param($Row)
    $path=if($Row.ExecutablePath){$Row.ExecutablePath}else{'Executable path unavailable'}
    $stateColor=switch([string]$Row.State){'Established'{'Green'}'Listen'{'Yellow'}'Bound'{'Cyan'}'TimeWait'{'DarkGray'}default{'Gray'}}
    $remoteAddress=if($Row.Protocol -eq 'UDP'){'*'}else{[string]$Row.RemoteAddress}
    $remotePort=if($null -ne $Row.RemotePort){[string]$Row.RemotePort}else{''}
    $localAddress=if(([string]$Row.LocalAddress).Contains(':')){'['+[string]$Row.LocalAddress+']'}else{[string]$Row.LocalAddress}
    if($Row.Protocol -ne 'UDP' -and $remoteAddress.Contains(':')){$remoteAddress='['+$remoteAddress+']'}
    $labelParts=@(
        [pscustomobject]@{Text=([string]$Row.Protocol);Color='Cyan'}
        [pscustomobject]@{Text=' ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.State);Color=$stateColor}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=$localAddress;Color='White'}
        [pscustomobject]@{Text=':';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.LocalPort);Color='Yellow'}
        [pscustomobject]@{Text=' -> ';Color='DarkGray'}
        [pscustomobject]@{Text=$remoteAddress;Color='Gray'}
    )
    if($remotePort){$labelParts+=@([pscustomobject]@{Text=':';Color='DarkGray'},[pscustomobject]@{Text=$remotePort;Color='Yellow'})}
    $detailParts=@(
        [pscustomobject]@{Text='PID ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.ProcessId);Color='Magenta'}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.ProcessName);Color='Cyan'}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=$path;Color='Gray'}
    )
    [pscustomobject]@{
        Id=$Row.Id
        Label=('{0} {1} | {2} -> {3}' -f $Row.Protocol,$Row.State,$Row.LocalEndpoint,$Row.RemoteEndpoint)
        Detail=('PID {0} | {1} | {2}' -f $Row.ProcessId,$Row.ProcessName,$path)
        LabelParts=$labelParts
        DetailParts=$detailParts
        SearchText=($Row.ProcessId.ToString()+' '+$Row.ProcessName+' '+$Row.ExecutablePath)
        Data=$Row
    }
}
function Start-PcNetworkConnections {
    $snapshot=Get-PcNetworkConnections;$state=@{};$protocol='TCP';$tcpState='All'
    while($true){
        $rows=@($snapshot.Rows | Where-Object {($protocol -eq 'Both' -or $_.Protocol -eq $protocol) -and ($tcpState -eq 'All' -or ($_.Protocol -eq 'TCP' -and $_.State -eq $tcpState))})
        $menu=@(foreach($row in $rows){New-PcNetworkConnectionMenuItem $row})
        $description=('{0:HH:mm:ss} snapshot | {1} / {2} | {3} entries | Collection issues: {4} (C)' -f $snapshot.CollectedAt,$protocol,$tcpState,$rows.Count,$snapshot.Issues.Count)
        $choice=Show-PcMenu -Title 'Windows > Network > Connections' -Items $menu -State $state -Filterable -Refreshable -Description $description -Commands @{T='TCP/UDP/both';L='TCP listeners';E='Established TCP';A='All states';C='Collection notes'}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$snapshot=Get-PcNetworkConnections}
            'Select'{Show-PcListDetails ($choice.Item.Data | Select-Object Protocol,State,LocalEndpoint,RemoteEndpoint,ProcessId,ProcessName,ExecutablePath,PathStatus,Ownership,Created) 'Connection details (cached snapshot)'}
            'Command'{switch($choice.Command){
                'T'{$protocol=switch($protocol){'TCP'{'UDP'}'UDP'{'Both'}default{'TCP'}};$tcpState='All'}
                'L'{$protocol='TCP';$tcpState='Listen'}
                'E'{$protocol='TCP';$tcpState='Established'}
                'A'{$tcpState='All'}
                'C'{Show-PcListDetails ([pscustomobject]@{CollectedAt=$snapshot.CollectedAt;TCP=@($snapshot.Rows | Where-Object Protocol -EQ TCP).Count;UDP=@($snapshot.Rows | Where-Object Protocol -EQ UDP).Count;CollectionIssues=($snapshot.Issues -join "`n");Notes='Read-only numeric endpoints; no DNS queries or network probes. R collects a fresh snapshot. UDP rows are bound local sockets, not TCP-style connections; no remote peer is supplied. Process attribution is best effort because endpoints and processes are collected separately. Administrator access may reveal additional executable paths. A listener does not establish firewall reachability.'}) 'Connection collection notes'}
            }}
        }
    }
}
# END NETWORK CONNECTIONS

function Get-NetworkChecks {
    # Add entries here. Requirements are evaluated before displaying AND running a check.
    @(
        [pscustomobject]@{Key='connections';Id='connections';Name='Network connections (TCP/UDP, PID and process)';MinPS='5.0';Commands=@('Get-NetTCPConnection','Get-CimInstance');Admin=$false;Action={param($t,$p) Start-PcNetworkConnections}}
        [pscustomobject]@{Key='discovery';Id='discovery';Name='Discover network devices / TCP ports';MinPS='5.0';Commands=@();Admin=$false;Action={param($t,$p) Start-NetworkDiscovery}}
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
        [pscustomobject]@{Key='disk';Id='disk';Name='Compatibility disk scanner 0.4.6 (verified download)';MinPS='5.0';Commands=@();Admin=$false;Action={param($t,$p) Start-PcDiskExplorer}}
        [pscustomobject]@{Key='disk-helper';Id='disk-helper';Name='Disk Usage 1.3.1 (automatic MFT/native)';MinPS='5.1';Commands=@('Expand-Archive','Get-FileHash');Admin=$false;Action={param($t,$p) Start-PcDiskHelper}}
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
        [pscustomobject]@{Key='2'; Id='connectivity'; Name='Connectivity and adapters'; Checks=@('connectivity','tcp','overview','discovery','connections'); AdChecks=@(); Repairs=@('renew-dhcp')}
        [pscustomobject]@{Key='3'; Id='dns'; Name='DNS'; Checks=@('dns'); AdChecks=@(); Repairs=@('flush-dns')}
        [pscustomobject]@{Key='4'; Id='ad'; Name='Active Directory and time'; Checks=@(); AdChecks=@('ad-context','ad-discovery','ad-dns','ad-secure','ad-time','ad-shares','ad-identity','ad-ports','ad-rootdse','ad-fsmo','ad-replication','ad-dcdiag','ad-events','ad-site-subnet','ad-user','ad-computer','ad-spn','ad-spn-duplicates','ad-dns-quality'); Repairs=@('repair-trust','resync-time')}
        [pscustomobject]@{Key='5'; Id='routing'; Name='Routing and proxy'; Checks=@('routes','proxy'); AdChecks=@(); Repairs=@()}
        [pscustomobject]@{Key='6'; Id='firewall'; Name='Firewall'; Checks=@('firewall'); AdChecks=@(); Repairs=@()}
        [pscustomobject]@{Key='7'; Id='power'; Name='Power and device health'; Checks=@('power','nic-power','sleep','wake','quality'); AdChecks=@(); Repairs=@('set-power-plan','nic-awake')}
        [pscustomobject]@{Key='8'; Id='storage'; Name='Disk usage explorers'; Checks=@('disk-helper','disk'); AdChecks=@(); Repairs=@()}
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
        $inputValue = $null
        if ($entry.Id -in @('ad-secure','ad-time','ad-shares','ad-ports','ad-rootdse','ad-replication','ad-dcdiag','ad-events')) {
            $answer = Read-PcInput 'DC hostname [automatic discovery]'
            if ($answer) { $dcName = $answer.Trim() }
            if ($dcName) { $null = Get-AdController $dcName }
        }
        if($entry.Id -eq 'ad-user'){$inputValue=Read-PcInput 'User identity';Test-AdObjectIdentity $inputValue;$inputValue=$inputValue.Trim()}
        if($entry.Id -eq 'ad-computer'){$inputValue=Read-PcInput 'Computer identity';Test-AdObjectIdentity $inputValue;$inputValue=$inputValue.Trim()}
        if($entry.Id -eq 'ad-spn'){$inputValue=Read-PcInput 'Exact SPN [for example HTTP/server.example.com]';Test-AdSpnValue $inputValue;$inputValue=$inputValue.Trim()}
        if($entry.Id -eq 'ad-spn-duplicates'){
            $confirmation=Read-Host 'Scan the current forest for duplicate SPNs? This can take time. [y/N]'
            if($confirmation -notmatch '^(?i:y|yes)$'){[pscustomobject]@{Test='Duplicate SPN scan';Status='CANCELLED';Detail='Scan not started.'};return}
        }
        Invoke-AdCheck $entry.Id $dcName $inputValue
        return
    }
    $probeTarget = 'example.com'
    $probePort = 443
    if ($entry.Id -in @('connectivity','dns','tcp','quick')) {
        $answer = Read-PcInput 'Target hostname or IP [example.com]'
        if (-not [string]::IsNullOrWhiteSpace($answer)) { $probeTarget = $answer.Trim() }
        Test-NetworkTarget $probeTarget
    }
    if ($entry.Id -eq 'tcp') {
        $answer = Read-PcInput 'TCP port [443]'
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
    $category=Get-NetworkCategories | Where-Object Id -EQ $Id | Select-Object -First 1
    if(-not $category){throw "Unknown category: $Id"}
    $state=@{}
    while($true){
        $context=Get-AdContext;$items=@(Get-NetworkMenuItems $category)
        $menu=@(foreach($item in $items){
            $availability=Get-NetworkItemAvailability $item $context
            $reason=if(-not $availability.Available){$availability.Reason}else{''}
            $kind=if($item.Kind -eq 'Repair'){'Change'}else{'Check'}
            $detail="PowerShell $($item.Entry.MinPS)+"
            if($item.Entry.Admin){$detail+=' | Administrator'}
            if($kind -eq 'Change'){$detail+=' | Requires confirmation'}
            New-PcMenuItem $item.Key $item.Entry.Name $kind $detail $reason
        })
        $description=if($Id -eq 'ad'){"$($context.Computer) | $($context.Role) | $($context.Domain)"}else{'Changes require confirmation.'}
        $answer=Read-PcCategoryMenu ("Windows > "+$category.Name) $menu $state $description
        if($answer -eq 'B'){return}
        $item=$items | Where-Object Key -EQ $answer | Select-Object -First 1
        Clear-PcMenuScreen
        try{
            $availability=Get-NetworkItemAvailability $item (Get-AdContext)
            if(-not $availability.Available){throw $availability.Reason}
            Invoke-InteractiveCheck $item | Format-List | Out-Host
        }catch [OperationCanceledException]{continue}catch{Write-Warning $_.Exception.Message}
        if($item.Entry.Id -in @('disk','disk-helper','event-browser','discovery','connections')){continue}
        $null=Read-Host 'Press Enter to return'
    }
}

function Start-NetworkMenu {
    $state=@{}
    while($true){
        $categories=@(Get-NetworkCategories | Where-Object {$_.Id -in @('overview','connectivity','dns','ad','routing','firewall')})
        $menu=@($categories | ForEach-Object {New-PcMenuItem $_.Key $_.Name})
        $menu+=New-PcMenuItem 'A' 'Active Directory shortcut'
        $answer=Read-PcCategoryMenu 'Windows > Network' $menu $state
        if($answer -eq 'B'){return}
        if($answer -eq 'A'){Start-AdMenu;continue}
        $category=$categories | Where-Object Key -EQ $answer | Select-Object -First 1
        Start-NetworkCategory $category.Id
    }
}

# BEGIN TOOLKIT CLEANUP
function Get-ToolkitCleanupRoots {
    [pscustomobject]@{Temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\');Data=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Random-Toolkits')).TrimEnd('\')}
}
function Assert-ToolkitCleanupPath([string]$Path,[string]$Root) {
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\');$boundary=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    if(-not $full.StartsWith($boundary+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path is outside the cleanup boundary.'}
    $cursor=$full
    while($cursor){
        if(Test-Path -LiteralPath $cursor){$entry=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop;if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Links/reparse points are excluded.'}}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-ToolkitCleanupTree([string]$Path,[string]$Root) {
    Assert-ToolkitCleanupPath $Path $Root
    $pending=New-Object 'Collections.Generic.Stack[string]';$pending.Push($Path)
    $entries=New-Object 'Collections.Generic.List[object]'
    while($pending.Count){
        $item=Get-Item -LiteralPath $pending.Pop() -Force -ErrorAction Stop
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Contains a link/reparse point; skipped without following it.'}
        if($item.LastWriteTimeUtc -gt [datetime]::UtcNow.AddMinutes(-10)){throw 'Recently modified (within 10 minutes); may still be in use.'}
        $entries.Add([pscustomobject]@{Path=$item.FullName;Directory=$item.PSIsContainer;Bytes=$(if($item.PSIsContainer){0L}else{$item.Length});Stamp=$item.LastWriteTimeUtc.Ticks})
        if($item.PSIsContainer){foreach($child in (Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)){$pending.Push($child.FullName)}}
    }
    return $entries.ToArray()
}
function Get-ToolkitCleanupCandidates {
    param([ValidateSet('Temp','Cache','Both')][string]$Scope='Temp')
    $roots=Get-ToolkitCleanupRoots;$targets=New-Object 'Collections.Generic.List[object]'
    if($Scope -ne 'Cache'){
        foreach($item in (Get-ChildItem -LiteralPath $roots.Temp -Force -ErrorAction Stop)){
            $kind=''
            if($item.Name -match '^toolkit-disk-[a-f0-9]{32}\.ps1$'){$kind='Temporary script'}
            elseif($item.Name -match '^toolkit-helper-[a-f0-9]{32}$'){$kind='Helper package / fixture'}
            elseif($item.Name -match '^(?:toolkit-(?:helper-compare|disk-test|long-test|disk-benchmark|allocation|mft-live|wof)|helper-navigation|helper keyboard |oui-test|cleanup-safety-test)[-]?[a-f0-9]{32}$'){$kind='Test fixture'}
            elseif($item.Name -match '^toolkit-(?:helper|launcher)-[a-z0-9-]+\.json$'){$kind='Diagnostic report (may contain local paths)'}
            elseif($item.Name -match '^discovery-test-[a-f0-9]{32}\.csv$'){$kind='Discovery test export'}
            if($kind){$targets.Add([pscustomobject]@{Path=$item.FullName;Root=$roots.Temp;Kind=$kind})}
        }
    }
    if($Scope -ne 'Temp'){
        $oui=Join-Path $roots.Data 'oui'
        if(Test-Path -LiteralPath $oui){$targets.Add([pscustomobject]@{Path=$oui;Root=$roots.Data;Kind='Public IEEE cache'})}
        $m365=Join-Path $roots.Data 'm365'
        if(Test-Path -LiteralPath $m365){
            Assert-ToolkitCleanupPath $m365 $roots.Data
            foreach($version in (Get-ChildItem -LiteralPath $m365 -Directory -Force -ErrorAction Stop)){
                if($version.Name -notmatch '^\d+\.\d+\.\d+$' -or ($version.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
                foreach($file in (Get-ChildItem -LiteralPath $version.FullName -File -Force -ErrorAction Stop)){
                    if($file.Name -eq 'M365-Toolkit.ps1' -or $file.Name -match '^\.download-[a-f0-9]{32}\.ps1$'){$targets.Add([pscustomobject]@{Path=$file.FullName;Root=$roots.Data;Kind='Cached M365 script'})}
                }
            }
        }
    }
    $helperRunning=@(Get-Process DiskHelper -ErrorAction SilentlyContinue).Count -gt 0
    foreach($target in $targets){
        $reason='';$entries=@();$bytes=0L
        try{
            if($helperRunning -and $target.Kind -eq 'Helper package / fixture'){throw 'A DiskHelper process is running; packages are retained.'}
            $entries=@(Get-ToolkitCleanupTree $target.Path $target.Root)
            foreach($entry in $entries){$bytes+=$entry.Bytes}
        }catch{$reason=$_.Exception.Message}
        [pscustomobject]@{Path=$target.Path;Root=$target.Root;Kind=$target.Kind;Bytes=$bytes;Eligible=($reason -eq '');Reason=$reason;Entries=$entries}
    }
}
function Remove-ToolkitCleanupCandidate($Candidate,[string]$Scope) {
    # Re-discover ownership and contents after confirmation; never trust a supplied path alone.
    $current=@(Get-ToolkitCleanupCandidates $Scope | Where-Object {$_.Path -eq $Candidate.Path})
    if($current.Count -ne 1 -or -not $current[0].Eligible){throw 'Target is no longer eligible; rescan the cleanup preview.'}
    $before=($Candidate.Entries | Sort-Object Path | ForEach-Object {"$($_.Path)|$($_.Directory)|$($_.Bytes)|$($_.Stamp)"}) -join "`n"
    $after=($current[0].Entries | Sort-Object Path | ForEach-Object {"$($_.Path)|$($_.Directory)|$($_.Bytes)|$($_.Stamp)"}) -join "`n"
    if($before -cne $after){throw 'Contents changed since preview; skipped.'}
    foreach($entry in ($current[0].Entries | Sort-Object @{Expression={$_.Path.Length};Descending=$true})){
        Assert-ToolkitCleanupPath $entry.Path $current[0].Root
        # Nonrecursive deletion: a newly added child prevents directory deletion.
        if($entry.Directory){[IO.Directory]::Delete($entry.Path,$false)}
        else{Remove-Item -LiteralPath $entry.Path -Force -ErrorAction Stop}
    }
}
function Start-ToolkitCleanup {
    $state=@{}
    while($true){
        $menu=@(
            New-PcMenuItem '1' 'Temporary packages, diagnostic reports and test fixtures' 'Change' 'Preview before confirmation'
            New-PcMenuItem '2' 'Download caches' 'Change' 'IEEE and cached M365 scripts; preview first'
            New-PcMenuItem '3' 'Temporary files and download caches' 'Change' 'Preview both'
        )
        $answer=Read-PcCategoryMenu 'Windows > Toolkit cleanup' $menu $state 'Current account only. User exports, reports, registry undo files and sign-in sessions are retained.'
        if($answer -in @('B','0') -or $null -eq $answer){return}
        $scope=switch($answer){'1'{'Temp'}'2'{'Cache'}'3'{'Both'}default{''}}
        if(-not $scope){continue}
        Clear-PcMenuScreen
        try{
            $items=@(Get-ToolkitCleanupCandidates $scope)
            if(-not $items.Count){Write-Host 'No recognized cleanup candidates found.';continue}
            $items | Select-Object Path,Kind,Bytes,Eligible,Reason | Format-List | Out-Host
            $eligible=@($items | Where-Object Eligible);$size=($eligible | Measure-Object Bytes -Sum).Sum
            Write-Host ("Eligible: {0} items, {1:N2} MiB. Skipped items remain. Deletion is permanent, not a secure erase." -f $eligible.Count,($size/1MB))
            if(-not $eligible.Count){continue}
            if((Read-Host 'Delete only the eligible items listed above? [y/N]') -notmatch '^(?i:y|yes)$'){continue}
            foreach($item in $eligible){
                try{Remove-ToolkitCleanupCandidate $item $scope;Write-Host ('Removed: '+$item.Path)}
                catch{Write-Warning ("Retained or partially removed: {0}: {1}" -f $item.Path,$_.Exception.Message)}
            }
        }catch{Write-Warning $_.Exception.Message}finally{Wait-PcMenuReturn}
    }
}
# END TOOLKIT CLEANUP

# BEGIN HEALTH DASHBOARD
function New-PcHealthFinding($Status,$Title,$Detail,$Target) {
    [pscustomobject]@{Status=$Status;Title=$Title;Detail=[string]$Detail;Target=$Target}
}
function Get-PcHealthProbes {
    param([switch]$IncludeNetwork)
    @(
        [pscustomobject]@{Name='Disk space';Target='storage';Run={
            $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -OperationTimeoutSec 5 -ErrorAction Stop)
            if(-not $disks.Count){throw 'No fixed logical disks were reported.'}
            foreach($disk in $disks){
                if($disk.Size -le 0){New-PcHealthFinding UNAVAILABLE ($disk.DeviceID+' capacity') 'Capacity was not reported.' storage;continue}
                $percent=100*$disk.FreeSpace/$disk.Size;$status=if($percent -lt 10){'WARN'}else{'PASS'}
                New-PcHealthFinding $status ($disk.DeviceID+' free space') ('{0:N1} GiB free ({1:N1}%). Warning threshold: below 10% free.' -f ($disk.FreeSpace/1GB),$percent) storage
            }
        }}
        [pscustomobject]@{Name='Storage health';Target='storage';Run={
            $disks=@(Get-PhysicalDisk -ErrorAction Stop)
            if(-not $disks.Count){throw 'The storage provider reported no physical disks.'}
            foreach($disk in $disks){
                $health=[string]$disk.HealthStatus
                $status=if($health -eq 'Healthy'){'PASS'}elseif($health -in @('Warning','Unhealthy')){'WARN'}else{'UNAVAILABLE'}
                if($status -eq 'PASS' -and @($disk.OperationalStatus | Where-Object {[string]$_ -ne 'OK'}).Count){$status='REVIEW'}
                New-PcHealthFinding $status ('Storage: '+$disk.FriendlyName) ("Provider health: $health; operation: $($disk.OperationalStatus -join ', '). This is the Windows storage-provider assessment, not a complete surface/SMART test.") storage
            }
        }}
        [pscustomobject]@{Name='Pending reboot';Target='power';Run={
            $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
            $present=@($paths | Where-Object {Test-Path -LiteralPath $_ -ErrorAction Stop})
            if($present.Count){New-PcHealthFinding WARN 'Restart requested by Windows servicing' ($present -join "`n") power}
            else{New-PcHealthFinding PASS 'Servicing reboot indicators' 'Neither of the two servicing reboot markers is present. Other applications may still need a restart.' power}
        }}
        [pscustomobject]@{Name='Automatic services';Target='log:System';Run={
            $stopped=@(Get-CimInstance Win32_Service -Filter "StartMode = 'Auto' AND State <> 'Running'" -OperationTimeoutSec 5 -ErrorAction Stop)
            if(-not $stopped.Count){New-PcHealthFinding PASS 'Automatic services' 'No automatic service is currently outside the Running state.' 'log:System'}
            else{
                $failed=@($stopped | Where-Object {$_.ExitCode -notin @(0,1077,$null)})
                $status=if($failed.Count){'WARN'}else{'REVIEW'}
                $detail=($stopped | ForEach-Object {"$($_.Name): $($_.State), exit code $($_.ExitCode)"}) -join "`n"
                New-PcHealthFinding $status ("{0} automatic services not running" -f $stopped.Count) ("Trigger-start, delayed-start and idle services can legitimately stop. Nonzero exit codes are evidence to inspect, not an instruction to start every service.`n"+$detail) 'log:System'
            }
        }}
        [pscustomobject]@{Name='Recent application crashes';Target='log:Application';Run={
            $events=@(Get-PcEventRecords -LogName Application -Hours 24 -Ids 1000 -Provider 'Application Error' -Limit 100)
            $detail=if($events.Count){($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Message)"}) -join "`n"}else{'No Application Error / 1000 events found in the last 24 hours. Other crash records may use different providers.'}
            $status=if($events.Count){'REVIEW'}else{'PASS'}
            New-PcHealthFinding $status ("Application crash events: {0}{1}" -f $events.Count,$(if($events.Count -eq 100){' (query cap reached)'}else{''})) $detail 'log:Application'
        }}
        [pscustomobject]@{Name='Recent Windows Update failures';Target='log:Microsoft-Windows-WindowsUpdateClient/Operational';Run={
            $events=@(Get-PcEventRecords -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' -Hours 168 -Ids 20 -Limit 100)
            $detail=if($events.Count){($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Message)"}) -join "`n"}else{'No update-install failure events (ID 20) in this channel over seven days. This does not check for missing updates.'}
            $status=if($events.Count){'REVIEW'}else{'PASS'}
            New-PcHealthFinding $status ("Update failure events: {0}{1}" -f $events.Count,$(if($events.Count -eq 100){' (query cap reached)'}else{''})) $detail 'log:Microsoft-Windows-WindowsUpdateClient/Operational'
        }}
        [pscustomobject]@{Name='Power plan';Target='power';Run={
            $power=@(Get-PcPowerOverview);$overview=$power | Where-Object {$_.PSObject.Properties['ActivePlan']} | Select-Object -First 1
            if(-not $overview -or -not $overview.ActivePlan){throw 'Active power plan could not be determined.'}
            New-PcHealthFinding INFO ('Power plan: '+$overview.ActivePlan) ($overview.Device+"`n"+$overview.Assessment+' Balanced is not automatically a fault; choose settings appropriate to AC/battery use.') power
        }}
        [pscustomobject]@{Name='NIC sleep settings';Target='power';Run={
            $nics=@(Get-PcNicPower)
            if(-not $nics.Count){New-PcHealthFinding INFO 'NIC power settings' 'No physical adapters were reported.' power}
            foreach($nic in $nics){
                # Power-saving support is a policy choice, not a health failure. Keep it
                # available as context without putting normal laptop settings in Attention.
                $status=if($nic.Status -eq 'UNAVAILABLE'){'UNAVAILABLE'}else{'INFO'}
                New-PcHealthFinding $status ('NIC sleep: '+$nic.Adapter) ("Power off: $($nic.AllowComputerToTurnOffDevice); selective suspend: $($nic.SelectiveSuspend); disconnect sleep: $($nic.DeviceSleepOnDisconnect). $($nic.Detail)") power
            }
        }}
        [pscustomobject]@{Name='Network configuration';Target='connectivity';Run={
            $adapters=@(Get-NetworkOverview | Where-Object {$_.State -eq 'Up' -and $_.Type -ne 'Loopback'})
            if(-not $adapters.Count){New-PcHealthFinding WARN 'Network adapters' 'No non-loopback adapter reports Up. This does not test external connectivity.' connectivity}
            $addressed=@($adapters | Where-Object Addresses);$unaddressed=@($adapters | Where-Object {-not $_.Addresses})
            if($unaddressed.Count){
                $status=if($addressed.Count){'INFO'}else{'REVIEW'}
                New-PcHealthFinding $status ("{0} active interfaces without IP addresses" -f $unaddressed.Count) ('Virtual/filter interfaces can legitimately lack addresses; they are not separate network failures. Interfaces: '+($unaddressed.Adapter -join ', ')) connectivity
            }
            foreach($adapter in $addressed){
                $adapterIdentity=[string]$adapter.Adapter+' '+[string]$adapter.Description
                $virtual=([string]$adapter.Type -eq 'Tunnel') -or ($adapterIdentity -match '(?i)\bvirtual\b|\bvmware\b|\bhyper-v\b|\bvethernet\b|\bvirtualbox\b|\bwireguard\b|\bwintun\b|\btap-windows\b|\bvpn\b')
                $status=if((-not $adapter.Gateways -or -not $adapter.DNS) -and -not $virtual){'REVIEW'}else{'INFO'}
                New-PcHealthFinding $status ('Network: '+$adapter.Adapter) ("Addresses: $($adapter.Addresses)`nGateways: $($adapter.Gateways)`nDNS servers: $($adapter.DNS)`nVirtual/VPN/local-only adapters may legitimately have no gateway or DNS. Open connectivity checks to test reachability.") connectivity
            }
        }}
        [pscustomobject]@{Name='AD domain context';Target='ad';Run={
            $context=Get-AdContext
            $status=if($context.Role -eq 'Unknown'){'UNAVAILABLE'}else{'INFO'}
            $detail="$($context.Computer): $($context.Role); domain: $($context.Domain). $($context.Detail)"
            if($context.Role -eq 'Domain member'){$detail+=' Membership alone does not validate trust. Run the live checks or open AD tools to verify trust and DNS.'}
            elseif($context.Role -eq 'Domain controller'){$detail+=' Member-computer secure-channel tests are not appropriate for a domain controller.'}
            else{$detail+=' AD secure-channel checks are not applicable to a workgroup PC.'}
            New-PcHealthFinding $status 'Domain membership / trust scope' $detail ad
        }}
    )
    if($IncludeNetwork){
        [pscustomobject]@{Name='Gateway reachability';Target='connectivity';Run={
            $gateways=@(Get-NetworkOverview | Where-Object State -eq Up | ForEach-Object {$_.Gateways -split ',\s*'} | Where-Object {$_ -and $_ -notin @('0.0.0.0','::')} | Select-Object -Unique -First 3)
            if(-not $gateways.Count){New-PcHealthFinding REVIEW 'Gateway reachability' 'No gateway was reported. VPN or local-only routing may still work.' connectivity}
            foreach($gateway in $gateways){$reply=Test-NetworkPing $gateway;New-PcHealthFinding $reply.Status ('Gateway: '+$gateway) ($reply.Detail+'. ICMP can be blocked; failure does not prove the network is down. At most three configured gateways are checked.') connectivity}
        }}
        [pscustomobject]@{Name='DNS resolution';Target='dns';Run={
            $context=Get-AdContext;$name=if($context.Role -in @('Domain member','Domain controller')){$context.Domain}else{'example.com'}
            try{
                $task=[Net.Dns]::GetHostAddressesAsync($name)
                if(-not $task.Wait(2000)){throw 'Resolver exceeded the two-second wait; the underlying OS lookup may finish later.'}
                $addresses=@($task.Result | ForEach-Object {$_.ToString()});if(-not $addresses.Count){throw 'No addresses returned.'}
                New-PcHealthFinding PASS ('DNS: '+$name) ("System resolver returned: $($addresses -join ', '). Cached results may be used; this does not test AD SRV records or every configured DNS server.") dns
            }catch{New-PcHealthFinding WARN ('DNS: '+$name) $_.Exception.Message dns}
        }}
        [pscustomobject]@{Name='AD secure channel';Target='ad';Run={
            $context=Get-AdContext
            if($context.Role -eq 'Domain member'){
                $result=Test-AdSecureChannel
                New-PcHealthFinding $result.Status 'AD secure channel' ($result.Detail+' A failure can reflect DC reachability; inspect before repairing.') ad
            }else{$status=if($context.Role -eq 'Unknown'){'UNAVAILABLE'}else{'INFO'};New-PcHealthFinding $status 'AD secure channel not run' ("Detected role: $($context.Role). Only domain-member computers use this check; DCs and workgroups are not tested.") ad}
        }}
    }
}
function Get-PcHealthDashboard {
    param([switch]$IncludeNetwork)
    $rows=New-Object 'Collections.Generic.List[object]';$probes=@(Get-PcHealthProbes -IncludeNetwork:$IncludeNetwork);$index=0
    try{
        foreach($probe in $probes){
            Write-Progress -Activity 'Windows health dashboard (read-only)' -Status $probe.Name -PercentComplete (100*$index/$probes.Count)
            try{foreach($row in @(& $probe.Run)){$rows.Add($row)}}catch{$rows.Add((New-PcHealthFinding UNAVAILABLE $probe.Name $_.Exception.Message $probe.Target))}
            $index++
        }
    }finally{Write-Progress -Activity 'Windows health dashboard (read-only)' -Completed}
    $rank=@{WARN=0;REVIEW=1;UNAVAILABLE=2;INFO=3;PASS=4}
    [pscustomobject]@{CollectedAt=(Get-Date);Rows=@($rows.ToArray() | Sort-Object @{Expression={$rank[$_.Status]}},Title)}
}
function Open-PcHealthTarget([string]$Target) {
    if($Target.StartsWith('log:')){Start-PcEventBrowser -DefaultLog $Target.Substring(4) -Quick}
    elseif($Target -in @('storage','power','connectivity','dns','ad')){Start-NetworkCategory $Target}
    else{throw 'Unknown dashboard target.'}
}
function Show-PcHealthFinding($Finding) {
    Clear-PcMenuScreen
    Write-Host ("`n[{0}] {1}" -f $Finding.Status,$Finding.Title) -ForegroundColor Cyan
    Write-Host $Finding.Detail
    while($true){
        Write-Host '1: related tools | Enter / Esc / Backspace / B: back (opening tools does not run a repair)'
        $answer=Read-PcMenuInput (Test-PcMenuKeyboard)
        if($null -eq $answer -or $answer.Trim() -in @('','Select','Back','B','0')){return}
        if($answer.Trim() -eq '1'){try{Open-PcHealthTarget $Finding.Target}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn};return}
    }
}
function New-PcHealthMenuItem($Row,[string]$Identity) {
    $statusColor=switch([string]$Row.Status){'PASS'{'Green'}'WARN'{'Yellow'}'REVIEW'{'Yellow'}'UNAVAILABLE'{'DarkGray'}'INFO'{'Cyan'}default{'Gray'}}
    [pscustomobject]@{
        Id=$Identity;Label=($Row.Status+' | '+$Row.Title);SearchText=$Row.Detail;Data=$Row
        LabelParts=@(
            [pscustomobject]@{Text=([string]$Row.Status);Color=$statusColor}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Row.Title);Color='White'}
        )
    }
}
function Start-PcHealthDashboard {
    $network=$false;$showAll=$false;$snapshot=Get-PcHealthDashboard;$state=@{}
    while($true){
        $identities=@{}
        $visibleRows=if($showAll){@($snapshot.Rows)}else{@($snapshot.Rows | Where-Object Status -in @('WARN','REVIEW','UNAVAILABLE'))}
        $menu=@(foreach($row in $visibleRows){
            $identity=$row.Target+'|'+$row.Title
            if(@($snapshot.Rows | Where-Object {($_.Target+'|'+$_.Title) -eq $identity}).Count -gt 1){$identity+='|'+$row.Detail}
            $base=$identity;$suffix=1
            while($identities.ContainsKey($identity)){$suffix++;$identity=$base+'|'+$suffix}
            $identities[$identity]=$true
            New-PcHealthMenuItem $row $identity
        })
        $counts=@{};foreach($status in @('WARN','REVIEW','UNAVAILABLE','INFO','PASS')){$counts[$status]=@($snapshot.Rows | Where-Object Status -eq $status).Count}
        $view=if($showAll){'All results'}else{'Attention only'}
        $description=("{0:g} | {1} | W {2}, R {3}, U {4}, info {5}, pass {6} | Live checks {7}" -f $snapshot.CollectedAt,$view,$counts.WARN,$counts.REVIEW,$counts.UNAVAILABLE,$counts.INFO,$counts.PASS,$(if($network){'on'}else{'off'}))
        $choice=Show-PcMenu -Title 'Windows > Health dashboard' -Items $menu -State $state -Filterable -Refreshable -Compact -EmptyMessage 'No results in this view. Clear the filter or press A to change views.' -Description $description -Commands @{A=('View: '+$(if($showAll){'all results'}else{'attention only'}));C='Run live network checks (no repair)'}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$snapshot=Get-PcHealthDashboard -IncludeNetwork:$network}
            'Command'{if($choice.Command -eq 'A'){$showAll=-not $showAll;$state.SelectedId=''}else{$network=$true;$snapshot=Get-PcHealthDashboard -IncludeNetwork}}
            'Select'{Show-PcHealthFinding $choice.Item.Data}
        }
    }
}
# END HEALTH DASHBOARD

# BEGIN STARTUP TASKS
function Test-PcLaunchPath([string]$Command,[switch]$CommandLine) {
    $path=$Command.Trim()
    if(-not $path){return [pscustomobject]@{Path='';Status='UNVERIFIED';Detail='No executable action (may be COM-based).'}}
    if($CommandLine){
        if($path.StartsWith('"')){if($path -notmatch '^"([^"]+)"') {return [pscustomobject]@{Path=$path;Status='UNVERIFIED';Detail='Malformed quoted command.'}};$path=$Matches[1]}
        else{
            if($path -match '^(.+?\.exe)(?:\s|$)' -and $Matches[1].Contains(' ')){return [pscustomobject]@{Path=$Matches[1];Status='UNVERIFIED';Detail='Unquoted executable path with spaces is ambiguous; inspect the original command.'}}
            $path=($path -split '\s+',2)[0]
        }
    }else{$path=$path.Trim('"')}
    if($path -match '%(?:USERPROFILE|APPDATA|LOCALAPPDATA|HOMEDRIVE|HOMEPATH|USERNAME)%'){return [pscustomobject]@{Path=$path;Status='UNVERIFIED';Detail='User-dependent environment variable; the run-as account may differ.'}}
    $path=[Environment]::ExpandEnvironmentVariables($path)
    if($path -match '%' -or $path -notmatch '^[A-Za-z]:\\' -or $path.StartsWith('\\')){return [pscustomobject]@{Path=$path;Status='UNVERIFIED';Detail='Relative, network or unresolved path; not probed or resolved through the current PATH.'}}
    try{
        $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if($item.PSIsContainer){return [pscustomobject]@{Path=$path;Status='REVIEW';Detail='Executable path points to a directory.'}}
        [pscustomobject]@{Path=$path;Status='FOUND';Detail='File exists; arguments, scripts, signatures and dependencies are not validated.'}
    }catch{
        $status=if($_.CategoryInfo.Category -eq 'ObjectNotFound'){'MISSING'}else{'UNVERIFIED'}
        [pscustomobject]@{Path=$path;Status=$status;Detail=$_.Exception.Message}
    }
}
function Get-PcTaskResult($Code,$LastRunTime) {
    if($null -eq $Code){return [pscustomobject]@{Status='UNAVAILABLE';Hex='';Meaning='Run information unavailable'}}
    [long]$value=$Code;if($value -lt 0){$value+=4294967296L}
    $hex='0x{0:X8}' -f $value
    if($value -eq 267011 -or ($value -eq 0 -and (-not $LastRunTime -or [datetime]$LastRunTime -lt [datetime]'2000-01-01'))){return [pscustomobject]@{Status='INFO';Hex=$hex;Meaning='Has not run / no usable last-run timestamp'}}
    if($value -eq 0){return [pscustomobject]@{Status='OK';Hex=$hex;Meaning='Last result was zero (does not validate application output)'}}
    $info=@{267008='Ready';267009='Running';267010='Disabled';267012='No more scheduled runs';267013='Not scheduled';267016='Event trigger has no set run time';267045='Queued'}
    if($value -le [int]::MaxValue -and $info.ContainsKey([int]$value)){return [pscustomobject]@{Status='INFO';Hex=$hex;Meaning=$info[[int]$value]}}
    [pscustomobject]@{Status='REVIEW';Hex=$hex;Meaning='Nonzero result: inspect scheduler history and action-specific exit-code meaning. Not every nonzero application code means failure.'}
}
function Get-PcStartupEntries {
    foreach($entry in @(Get-CimInstance Win32_StartupCommand -OperationTimeoutSec 5 -ErrorAction Stop)){
        $check=Test-PcLaunchPath ([string]$entry.Command) -CommandLine
        $status=if($check.Status -in @('MISSING','REVIEW')){'REVIEW'}else{'INFO'}
        [pscustomobject]@{Kind='Startup';Name=$entry.Name;Status=$status;State='Enabled state not determined';Location=$entry.Location;User=$entry.User;Command=$entry.Command;Executable=$check.Path;PathStatus=$check.Status;Detail=$check.Detail}
    }
}
function Get-PcScheduledTaskEntries {
    $tasks=@(Get-ScheduledTask -ErrorAction Stop);$index=0
    try{
        foreach($task in $tasks){
            Write-Progress -Activity 'Inspecting scheduled tasks (read-only)' -Status ("{0}/{1}: {2}" -f ($index+1),$tasks.Count,$task.TaskName) -PercentComplete (100*$index/[math]::Max(1,$tasks.Count))
            $info=$null;$errorText=''
            try{$info=$task | Get-ScheduledTaskInfo -ErrorAction Stop}catch{$errorText=$_.Exception.Message}
            $result=Get-PcTaskResult $info.LastTaskResult $info.LastRunTime
            $checks=@();$actions=@()
            foreach($action in $task.Actions){
                $checks+=Test-PcLaunchPath ([string]$action.Execute)
                $actions+=[pscustomobject]@{Execute=$action.Execute;Arguments=$action.Arguments;WorkingDirectory=$action.WorkingDirectory;ClassId=$action.ClassId}
            }
            $status=$result.Status
            if(@($checks | Where-Object {$_.Status -in @('MISSING','REVIEW')}).Count){$status='REVIEW'}
            [pscustomobject]@{Kind='Task';Name=$task.TaskName;Status=$status;State=[string]$task.State;Location=$task.TaskPath;User=$task.Principal.UserId;LastRun=$info.LastRunTime;NextRun=$info.NextRunTime;MissedRuns=$info.NumberOfMissedRuns;Result=$result.Hex;ResultMeaning=$result.Meaning;Actions=($actions | ConvertTo-Json -Depth 4 -Compress);Paths=($checks | ConvertTo-Json -Depth 4 -Compress);Triggers=($task.Triggers | Select-Object Enabled,StartBoundary,EndBoundary,DaysInterval,UserId | ConvertTo-Json -Depth 4 -Compress);Detail=$errorText}
            $index++
        }
    }finally{Write-Progress -Activity 'Inspecting scheduled tasks (read-only)' -Completed}
}
function New-PcStartupTaskMenuItem($Row,[ValidateSet('Startup','Task')][string]$Kind) {
    $statusColor=switch([string]$Row.Status){'OK'{'Green'}'FOUND'{'Green'}'REVIEW'{'Yellow'}'MISSING'{'Red'}'UNAVAILABLE'{'DarkGray'}'INFO'{'Cyan'}default{'Gray'}}
    $detail=if($Kind -eq 'Startup'){@('Command: '+$Row.Command; 'Source: '+$Row.Location+' | Path: '+$Row.PathStatus)}else{@($Row.Location+' | '+$Row.State;'Result: '+$Row.Result+' | '+$Row.ResultMeaning)}
    $firstDetailParts=if($Kind -eq 'Startup'){@(
        [pscustomobject]@{Text='Command: ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.Command);Color='Gray'}
    )}else{@(
        [pscustomobject]@{Text=([string]$Row.Location);Color='Gray'}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.State);Color=$(if($Row.State -eq 'Running'){'Green'}elseif($Row.State -eq 'Disabled'){'DarkGray'}else{'Cyan'})}
    )}
    [pscustomobject]@{
        Id=($Row.Location+'|'+$Row.Name+'|'+$Row.User+'|'+$Row.Command)
        Label=($Row.Status+' | '+$Row.Name);Detail=$detail;SearchText=($Row.Command+' '+$Row.Executable);Data=$Row
        LabelParts=@(
            [pscustomobject]@{Text=([string]$Row.Status);Color=$statusColor}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Row.Name);Color='Cyan'}
        )
        DetailParts=$firstDetailParts
    }
}
function Start-PcStartupTaskBrowser([ValidateSet('Startup','Task')][string]$Kind) {
    $state=@{};$reviewOnly=$false;$reload=$true;$all=@()
    while($true){
        if($reload){$all=if($Kind -eq 'Startup'){@(Get-PcStartupEntries)}else{@(Get-PcScheduledTaskEntries)};$reload=$false}
        $rows=@($all | Where-Object {-not $reviewOnly -or $_.Status -in @('REVIEW','UNAVAILABLE')} | Sort-Object @{Expression={if($_.Status -eq 'REVIEW'){0}elseif($_.Status -eq 'UNAVAILABLE'){1}else{2}}},Name)
        $menu=@(foreach($row in $rows){New-PcStartupTaskMenuItem $row $Kind})
        $description=if($Kind -eq 'Startup'){'Read-only; inventory may omit packaged apps and enabled/approved state.'}else{'Read-only; visible tasks only. Nonzero results need review, not proof of failure.'}
        $choice=Show-PcMenu -Title ('Windows > Startup/tasks > '+$Kind) -Items $menu -State $state -Filterable -Refreshable -DetailLines 2 -Description $description -Commands @{C=('Review only: '+$reviewOnly+' / toggle')}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$reload=$true}
            'Command'{$reviewOnly=-not $reviewOnly}
            'Select'{Show-PcListDetails $choice.Item.Data ($Kind+' details')}
        }
    }
}
function Start-PcStartupTaskMenu {
    $state=@{}
    while($true){
        $menu=@(
            New-PcMenuItem '1' 'Startup entries' 'Browse'
            New-PcMenuItem '2' 'Scheduled tasks' 'Browse'
            New-PcMenuItem '3' 'Task Scheduler event log' 'Browse'
            New-PcMenuItem '4' 'Open Windows Startup Apps settings' 'Open'
            New-PcMenuItem '5' 'Open Task Scheduler' 'Open'
        )
        $answer=Read-PcCategoryMenu 'Windows > Startup and scheduled tasks' $menu $state 'Inventory is read-only; Windows management shortcuts open separately.'
        if($null -eq $answer -or $answer.Trim() -in @('B','0')){return}
        try{
            switch($answer.Trim()){
                '1'{Start-PcStartupTaskBrowser Startup}
                '2'{Start-PcStartupTaskBrowser Task}
                '3'{Start-PcEventBrowser -DefaultLog 'Microsoft-Windows-TaskScheduler/Operational' -Quick}
                '4'{Start-Process 'ms-settings:startupapps' -ErrorAction Stop}
                '5'{Start-Process -FilePath (Join-Path $env:WINDIR 'System32\mmc.exe') -ArgumentList ('"'+(Join-Path $env:WINDIR 'System32\taskschd.msc')+'"') -ErrorAction Stop}
                default{Write-Warning 'Choose a listed option.'}
            }
        }catch [OperationCanceledException]{}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn}
    }
}
# END STARTUP TASKS

# BEGIN SYSTEM MAINTENANCE
function Assert-PcMaintenanceAdmin {
    $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$true})
    if(-not $availability.Available){throw $availability.Reason}
}
function Get-PcServiceInventory {
    Get-CimInstance Win32_Service -OperationTimeoutSec 10 -ErrorAction Stop | Sort-Object DisplayName | Select-Object Name,DisplayName,State,StartMode,StartName,PathName,ProcessId,Description
}
function Invoke-PcServiceAction {
    param([string]$Name,[ValidateSet('Start','Stop','Restart')][string]$Action)
    Assert-PcMaintenanceAdmin
    $service=Get-Service -Name $Name -ErrorAction Stop | Where-Object Name -EQ $Name
    if(-not $service){throw 'Service no longer exists.'}
    $running=@($service.DependentServices | Where-Object Status -NE 'Stopped')
    if($Action -ne 'Start' -and $running.Count){throw ('Stop/restart blocked: active dependent services: '+($running.Name -join ', ')+'. Review them individually first.')}
    if($Action -ne 'Start' -and -not $service.CanStop){throw 'This service cannot currently be stopped.'}
    Write-Host ("{0} service {1} ({2}); current state: {3}. This may interrupt applications or remote access." -f $Action,$service.Name,$service.DisplayName,$service.Status)
    if((Read-Host 'Proceed? [y/N]') -notmatch '^(?i:y|yes)$'){return}
    switch($Action){
        'Start' {Start-Service -InputObject $service -ErrorAction Stop}
        'Stop' {Stop-Service -InputObject $service -ErrorAction Stop}
        'Restart' {Restart-Service -InputObject $service -ErrorAction Stop}
    }
    Get-Service -Name $Name -ErrorAction Stop | Select-Object Name,DisplayName,Status | Format-Table | Out-Host
}
function Show-PcServiceDetails($Row) {
    $state=@{}
    while($true){
        $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$true})
        $reason=if(-not $availability.Available){$availability.Reason}else{''}
        $menu=@(
            New-PcMenuItem 'D' 'Details, account, path and dependencies' 'Check'
            New-PcMenuItem '1' 'Start service' 'Change' 'Requires confirmation' $reason
            New-PcMenuItem '2' 'Stop service' 'Change' 'Active dependents block stopping' $reason
            New-PcMenuItem '3' 'Restart service' 'Change' 'Active dependents block restarting' $reason
            New-PcMenuItem 'E' 'Related Service Control Manager events' 'Browse' 'Last 24 hours; message match'
        )
        $answer=Read-PcCategoryMenu ('Windows > Services > '+$Row.Name) $menu $state ($Row.DisplayName+' | '+$Row.State+' | '+$Row.StartMode)
        if($answer -eq 'B'){return}
        Clear-PcMenuScreen
        try{
            switch($answer){
                'D'{
                    $Row | Format-List * | Out-Host
                    $service=Get-Service -Name $Row.Name -ErrorAction Stop | Where-Object Name -EQ $Row.Name
                    Write-Host ('Requires: '+($service.ServicesDependedOn.Name -join ', '))
                    Write-Host ('Dependents: '+($service.DependentServices.Name -join ', '))
                }
                '1'{Invoke-PcServiceAction $Row.Name Start}
                '2'{Invoke-PcServiceAction $Row.Name Stop}
                '3'{Invoke-PcServiceAction $Row.Name Restart}
                'E'{Start-PcEventBrowser -DefaultLog System -Quick -InitialProvider 'Service Control Manager' -InitialText $Row.DisplayName}
            }
            $updated=@(Get-PcServiceInventory | Where-Object Name -EQ $Row.Name)
            if(-not $updated.Count){Write-Warning 'Service no longer exists.';Wait-PcMenuReturn;return};$Row=$updated[0]
        }catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn;continue}
        if($answer -ne 'E'){Wait-PcMenuReturn}
    }
}
function New-PcServiceMenuItem($Row) {
    $stateColor=switch([string]$Row.State){'Running'{'Green'}'Start Pending'{'Yellow'}'Stop Pending'{'Yellow'}'Paused'{'Yellow'}'Stopped'{'Gray'}default{'DarkGray'}}
    $modeColor=switch([string]$Row.StartMode){'Auto'{'Cyan'}'Automatic'{'Cyan'}'Disabled'{'DarkGray'}default{'Gray'}}
    [pscustomobject]@{
        Id=$Row.Name;Label=($Row.State+' | '+$Row.StartMode+' | '+$Row.DisplayName+' ('+$Row.Name+')');Detail=$Row.PathName;SearchText=$Row.StartName;Data=$Row
        LabelParts=@(
            [pscustomobject]@{Text=([string]$Row.State);Color=$stateColor}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Row.StartMode);Color=$modeColor}
            [pscustomobject]@{Text=' | ';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Row.DisplayName);Color='White'}
            [pscustomobject]@{Text=' (';Color='DarkGray'}
            [pscustomobject]@{Text=([string]$Row.Name);Color='Magenta'}
            [pscustomobject]@{Text=')';Color='DarkGray'}
        )
        DetailParts=@([pscustomobject]@{Text=([string]$Row.PathName);Color='Gray'})
    }
}
function Start-PcServices {
    $state=@{};$reload=$true;$rows=@()
    while($true){
        try{if($reload){$rows=@(Get-PcServiceInventory);$reload=$false}}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn;return}
        $menu=@(foreach($row in $rows){New-PcServiceMenuItem $row})
        $choice=Show-PcMenu -Title 'Windows > Services' -Items $menu -State $state -Filterable -Refreshable -Description 'Enter opens details and confirmed actions. Filtering also searches executable paths and accounts.'
        switch($choice.Action){
            'Back'{return} 'Refresh'{$reload=$true}
            'Select'{Show-PcServiceDetails $choice.Item.Data;$reload=$true}
        }
    }
}
function Get-PcRepairCommand {
    param([ValidateSet('CheckHealth','ScanHealth','VerifyFiles','RestoreHealth','RepairFiles')][string]$Action)
    $folder=if([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess){'Sysnative'}else{'System32'}
    $binary='dism.exe';$arguments=@('/Online','/Cleanup-Image',('/'+$Action),'/NoRestart')
    if($Action -in @('VerifyFiles','RepairFiles')){$binary='sfc.exe';$arguments=@($(if($Action -eq 'VerifyFiles'){'/verifyonly'}else{'/scannow'}))}
    [pscustomobject]@{Path=(Join-Path $env:WINDIR "$folder\$binary");Arguments=$arguments;Repair=($Action -in @('RestoreHealth','RepairFiles'));Action=$Action}
}
function Invoke-PcRepairNative($Command) {
    & $Command.Path @($Command.Arguments) | Out-Host
    return $LASTEXITCODE
}
function Invoke-PcWindowsRepair {
    param([ValidateSet('CheckHealth','ScanHealth','VerifyFiles','RestoreHealth','RepairFiles')][string]$Action)
    Assert-PcMaintenanceAdmin
    $command=Get-PcRepairCommand $Action
    if(-not (Test-Path -LiteralPath $command.Path -PathType Leaf)){throw "Unavailable: $($command.Path)"}
    if($Action -notin @('VerifyFiles','RepairFiles') -and [Environment]::OSVersion.Version -lt [version]'6.2'){throw 'Online component-store health commands require Windows 8 / Server 2012 or later.'}
    Write-Host ($command.Path+' '+($command.Arguments -join ' '))
    if($command.Repair){
        Write-Host 'This repairs Windows components/files. RestoreHealth may use Windows Update or your configured repair source. No automatic reboot.'
        if((Read-Host 'Run this repair? [y/N]') -notmatch '^(?i:y|yes)$'){return}
    }
    Write-Host 'This can take time. Native progress/results follow; let the operation finish before leaving this screen.'
    $timer=[Diagnostics.Stopwatch]::StartNew();$code=Invoke-PcRepairNative $command;$timer.Stop()
    Write-Host ("Completed in {0:n1} minutes; exit code: {1}" -f $timer.Elapsed.TotalMinutes,$code)
    if($code -eq 3010){Write-Warning 'A restart is required. Restart manually when ready.'}
    elseif($code -ne 0){Write-Warning 'Review the native result and logs; the operation did not return zero.'}
    else{Write-Host 'Command returned zero. Read its findings above; this alone does not establish that Windows is healthy.'}
    Write-Host ('DISM log: '+(Join-Path $env:WINDIR 'Logs\DISM\dism.log'))
    Write-Host ('SFC/CBS log: '+(Join-Path $env:WINDIR 'Logs\CBS\CBS.log'))
}
function Start-PcWindowsRepair {
    $state=@{}
    while($true){
        $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$true})
        $reason=if(-not $availability.Available){$availability.Reason}else{''}
        $definitions=@(
            @('1','DISM CheckHealth','Check','Previously recorded corruption; quick','CheckHealth'),
            @('2','DISM ScanHealth','Check','Scan component store; no repair','ScanHealth'),
            @('3','SFC verify-only','Check','Check protected system files; no repair','VerifyFiles'),
            @('4','DISM RestoreHealth','Change','Repair component store; confirmation required','RestoreHealth'),
            @('5','SFC scannow','Change','Repair system files; confirmation required','RepairFiles')
        )
        $menu=@(foreach($definition in $definitions){
            $blocked=$reason;$command=Get-PcRepairCommand $definition[4]
            if(-not (Test-Path -LiteralPath $command.Path -PathType Leaf)){$blocked='Missing '+$command.Path}
            if($definition[4] -notin @('VerifyFiles','RepairFiles') -and [Environment]::OSVersion.Version -lt [version]'6.2'){$blocked='Requires Windows 8 / Server 2012 or later'}
            New-PcMenuItem $definition[0] $definition[1] $definition[2] $definition[3] $blocked
        })
        $answer=Read-PcCategoryMenu 'Windows > Repair centre' $menu $state 'Administrator required. Repair order: RestoreHealth, review result, then SFC scannow.'
        if($null -eq $answer -or $answer.Trim() -in @('B','0')){return}
        $action=switch($answer.Trim()){'1'{'CheckHealth'} '2'{'ScanHealth'} '3'{'VerifyFiles'} '4'{'RestoreHealth'} '5'{'RepairFiles'}}
        if(-not $action){Write-Warning 'Choose a listed option.';continue}
        Clear-PcMenuScreen
        try{Invoke-PcWindowsRepair $action}catch{Write-Warning $_.Exception.Message}
        $null=Read-Host 'Enter to return'
    }
}
# END SYSTEM MAINTENANCE

# BEGIN MENU ENGINE
# Shared menu foundation. Returns a choice; never invokes an item's action.
function Test-PcMenuKeyboard {
    try{return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected}catch{return $false}
}
function Clear-PcMenuScreen {
    if(Test-PcMenuKeyboard){try{Clear-Host}catch{}}
}
function ConvertFrom-PcMenuKey($Key) {
    switch([string]$Key.Key){
        'UpArrow'{return 'Up'} 'DownArrow'{return 'Down'}
        'Enter'{return 'Select'} 'Escape'{return 'Back'} 'Backspace'{return 'Back'}
        'PageUp'{return 'Previous'} 'PageDown'{return 'Next'}
        'Home'{return 'First'} 'End'{return 'Last'}
    }
    return [string]$Key.KeyChar
}
function Read-PcMenuKey { return [Console]::ReadKey($true) }
function Write-PcMenuSelection([string]$Digits) {
    Write-Host ("`rSelection: {0,-10}" -f ($Digits+'_')) -NoNewline -ForegroundColor Cyan
}
function Read-PcMenuInput([bool]$Keyboard) {
    if(-not $Keyboard){return Read-Host 'Number / Enter: select | B/0: back'}
    $digits=''
    Write-PcMenuSelection $digits
    try {
        while($true){
            $key=Read-PcMenuKey
            if($key.Key -eq 'Backspace' -and $digits.Length){$digits=$digits.Substring(0,$digits.Length-1);Write-PcMenuSelection $digits;continue}
            $value=ConvertFrom-PcMenuKey $key
            if($value -match '^\d$'){if($digits.Length -lt 9){$digits+=$value};Write-PcMenuSelection $digits;continue}
            if($value -eq 'Select' -and $digits.Length){return $digits}
            if($value -in @('Up','Down','Select','Back','Previous','Next','First','Last','f','r','b','n','p','a','c','l','e','d','m','x','s','t')){return $value}
        }
    } finally {Write-Host ''}
}
function Format-PcMenuText {
    param([AllowNull()][string]$Text,[int]$Width=100)
    $clean=($Text -replace '[\x00-\x1F\x7F]',' ')
    $Width=[math]::Max(4,$Width)
    if($clean.Length -le $Width){return $clean}
    $length=$Width-3
    if([char]::IsHighSurrogate($clean[$length-1])){$length--}
    return $clean.Substring(0,$length)+'...'
}
function Get-PcMenuHeading {
    param([string]$Title,[string]$Version=$script:PcToolkitVersion)
    if($Title -eq 'Windows'){return "WINDOWS TOOLKIT $Version"}
    if($Title.StartsWith('Windows > ')){$Title=$Title.Substring(10)}
    return "WINDOWS TOOLKIT $Version | $Title"
}
function Get-PcMenuPageSize {
    param([int]$WindowHeight,[ValidateRange(1,3)][int]$DetailLines=1,[ValidateRange(1,100)][int]$Maximum=100)
    # Header, filter, page/status lines, controls and selection prompt use about six rows.
    # Keep three additional rows for wrapping and terminal variance without wasting a third of the viewport.
    $reservedRows=9
    return [int][math]::Max(1,[math]::Min($Maximum,[math]::Floor(($WindowHeight-$reservedRows)/[double]($DetailLines+1))))
}
function Write-PcMenuSegments {
    param([object[]]$Segments,[string]$Prefix='',[int]$Width=100,[string]$FallbackColor='Gray')
    $cleanPrefix=($Prefix -replace '[\x00-\x1F\x7F]',' ')
    $cleanSegments=@(foreach($segment in $Segments){
        [pscustomobject]@{Text=([string]$segment.Text -replace '[\x00-\x1F\x7F]',' ');Color=$(if($segment.Color){[string]$segment.Color}else{$FallbackColor})}
    })
    $bounded=Format-PcMenuText ($cleanPrefix+(($cleanSegments | ForEach-Object Text) -join '')) $Width
    $prefixLength=[math]::Min($cleanPrefix.Length,$bounded.Length)
    if($prefixLength){Write-Host $bounded.Substring(0,$prefixLength) -NoNewline -ForegroundColor $FallbackColor}
    $offset=$prefixLength
    foreach($segment in $cleanSegments){
        if($offset -ge $bounded.Length){break}
        $count=[math]::Min($segment.Text.Length,$bounded.Length-$offset)
        if($count){Write-Host $bounded.Substring($offset,$count) -NoNewline -ForegroundColor $segment.Color;$offset+=$count}
    }
    if($offset -lt $bounded.Length){Write-Host $bounded.Substring($offset) -NoNewline -ForegroundColor $FallbackColor}
    Write-Host ''
}
function Test-PcMenuCursorControl {
    try{return -not [Console]::IsOutputRedirected -and [Console]::CursorTop -ge 0}catch{return $false}
}
function Get-PcMenuCursorTop { return [Console]::CursorTop }
function Set-PcMenuCursorPosition([int]$Left,[int]$Top) { [Console]::SetCursorPosition($Left,$Top) }
function Clear-PcMenuRegion {
    param([int]$Top,[int]$Lines,[int]$Width)
    for($line=0;$line -lt $Lines;$line++){
        Set-PcMenuCursorPosition 0 ($Top+$line)
        Write-Host (' '*$Width) -NoNewline
    }
}
function Write-PcMenuDisplayItem {
    param($Row,[string]$DisplayKey,[bool]$Selected,[int]$Width,[int]$DetailLines,[switch]$ExpandedPreview,[switch]$Compact)
    $marker=if($Selected){'>'}else{' '}
    $kind=if($Row.Kind){' ['+$Row.Kind+']'}else{''}
    $color=if($Row.DisabledReason){'DarkGray'}elseif($Selected){'Cyan'}else{'Gray'}
    if($Row.LabelParts -and -not $Row.DisabledReason){
        $labelParts=@($Row.LabelParts)
        if($kind){$labelParts+=@([pscustomobject]@{Text=$kind;Color=$color})}
        Write-PcMenuSegments $labelParts ('{0} [{1}] ' -f $marker,$DisplayKey) $Width $color
    }else{Write-Host (Format-PcMenuText ('{0} [{1}] {2}{3}' -f $marker,$DisplayKey,$Row.Label,$kind) $Width) -ForegroundColor $color}
    $detail=@()
    if(-not $Compact){$detail=@($Row.Detail | Select-Object -First $DetailLines)}
    if($ExpandedPreview -and $Selected -and $Row.SelectedDetail){$detail=@($Row.SelectedDetail | Select-Object -First 3)}
    if($Row.DisabledReason){$detail=@('UNAVAILABLE: '+$Row.DisabledReason)}
    if(-not $Compact -and -not $detail.Count){$detail=@('')}
    for($detailIndex=0;$detailIndex -lt $detail.Count;$detailIndex++){
        if($detailIndex -eq 0 -and $Row.DetailParts -and -not $Row.DisabledReason -and -not ($ExpandedPreview -and $Selected -and $Row.SelectedDetail)){
            Write-PcMenuSegments @($Row.DetailParts) '    ' $Width $color
        }else{Write-Host (Format-PcMenuText ('    '+$detail[$detailIndex]) $Width) -ForegroundColor $color}
    }
    return 1+$detail.Count
}
function Show-PcMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [object[]]$Items=@(),
        [string]$Version=$script:PcToolkitVersion,
        [string]$Description='',
        [hashtable]$State=@{},
        [switch]$Filterable,
        [switch]$Refreshable,
        [ValidateRange(1,100)][int]$PageSize=100,
        [switch]$Plain,
        [switch]$Compact,
        [string]$EmptyMessage='No matching items.',
        [hashtable]$Commands=@{},
        [ValidateRange(1,3)][int]$DetailLines=1,
        [switch]$ExpandedPreview
    )
    # Item contract: unique nonempty Id, Label; optional Kind, Detail, DisabledReason,
    # LabelParts and DetailParts arrays containing Text/Color objects.
    # Caller retains State and handles Select/Refresh/Back; no scriptblock is executed here.
    $ids=@{};$keys=@{};$displayKeys=@{};$ordinal=0
    foreach($item in $Items){
        if([string]::IsNullOrWhiteSpace([string]$item.Id) -or [string]::IsNullOrWhiteSpace([string]$item.Label)){throw 'Menu items require Id and Label.'}
        if($ids.ContainsKey([string]$item.Id)){throw "Duplicate menu item Id: $($item.Id)"}
        $ids[[string]$item.Id]=$true
        $ordinal++;$key=if($item.Key){[string]$item.Key}else{[string]$ordinal}
        if($key -notmatch '^(?:[1-9][0-9]*|[ACLED])$' -or $keys.ContainsKey($key)){throw "Invalid or duplicate menu key: $key"}
        $keys[$key]=[string]$item.Id;$displayKeys[[string]$item.Id]=$key
    }
    foreach($key in $Commands.Keys){if($key -notmatch '^[ACDEFLMSTX]$' -or $keys.ContainsKey($key) -or ($key -eq 'F' -and $Filterable)){throw "Invalid or conflicting menu command: $key"}}
    if(-not $State.ContainsKey('Filter')){$State.Filter=''}
    if(-not $State.ContainsKey('SelectedId')){$State.SelectedId=''}
    $keyboard=(-not $Plain -and (Test-PcMenuKeyboard));$notice=''
    while($true){
        $rows=@($Items | Where-Object {(-not $Filterable) -or (-not $State.Filter) -or (($_.Label+' '+($_.Detail -join ' ')+' '+$_.SearchText).IndexOf([string]$State.Filter,[StringComparison]::OrdinalIgnoreCase) -ge 0)})
        $selected=0
        for($i=0;$i -lt $rows.Count;$i++){if([string]$rows[$i].Id -eq $State.SelectedId){$selected=$i;break}}
        if($rows.Count){$State.SelectedId=[string]$rows[$selected].Id}
        $size=$PageSize;$width=100;$cursorControl=$false;$menuDetailLines=if($Compact){0}else{$DetailLines}
        if($keyboard){
            try{$size=Get-PcMenuPageSize $Host.UI.RawUI.WindowSize.Height $menuDetailLines $PageSize;$width=[math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{}
            $cursorControl=Test-PcMenuCursorControl
            Clear-Host
        }
        $page=[int][math]::Floor($selected/[double]$size)
        Write-Host (Format-PcMenuText (Get-PcMenuHeading $Title $Version) $width) -ForegroundColor Cyan
        if($Description){Write-Host (Format-PcMenuText $Description $width)}
        if($Filterable){Write-Host (Format-PcMenuText ('Filter: '+$State.Filter) $width)}
        if(-not $rows.Count){Write-Host $EmptyMessage}
        $rowTops=@{};$rowHeights=@{}
        for($i=$page*$size;$i -lt [math]::Min($rows.Count,($page+1)*$size);$i++){
            if($cursorControl){$rowTops[$i]=Get-PcMenuCursorTop}
            $rowHeights[$i]=Write-PcMenuDisplayItem $rows[$i] $displayKeys[[string]$rows[$i].Id] ($i -eq $selected) $width $menuDetailLines -ExpandedPreview:$ExpandedPreview -Compact:$Compact
        }
        Write-Host ("Page {0}/{1} | {2} items" -f ($page+1),[math]::Max(1,[math]::Ceiling($rows.Count/[double]$size)),$rows.Count)
        $footer=if($keyboard){'Arrows: select | Enter: open | Esc/Backspace: back'}else{'Number/Enter: open | B/0: back'}
        if($rows.Count -gt $size){$footer+=' | N/P: pages'}
        if($Filterable){$footer+=' | F: filter'}
        if($Refreshable){$footer+=' | R: refresh'}
        Write-Host $footer
        if($Commands.Count){Write-Host (($Commands.Keys | Sort-Object | ForEach-Object {$_+': '+$Commands[$_]}) -join ' | ')}
        if($notice){Write-Warning $notice;$notice=''}
        while($true){
            $promptTop=if($cursorControl){Get-PcMenuCursorTop}else{-1}
            $answer=Read-PcMenuInput $keyboard
            if($null -eq $answer){return [pscustomobject]@{Action='Back';Item=$null;State=$State}}
            $choice=$answer.Trim();$open=$false;$navigated=$false;$oldSelected=$selected
            if($Commands.ContainsKey($choice)){return [pscustomobject]@{Action='Command';Command=$choice.ToUpperInvariant();Item=$null;State=$State}}
            switch($choice.ToUpperInvariant()){
                {$_ -in @('BACK','B','0')}{return [pscustomobject]@{Action='Back';Item=$null;State=$State}}
                'UP'{$selected=[math]::Max(0,$selected-1);$navigated=$true}
                'DOWN'{$selected=[math]::Min($rows.Count-1,$selected+1);$navigated=$true}
                'FIRST'{$selected=0;$navigated=$true} 'LAST'{$selected=$rows.Count-1;$navigated=$true}
                {$_ -in @('NEXT','N')}{$selected=[math]::Min($rows.Count-1,$selected+$size);$navigated=$true}
                {$_ -in @('PREVIOUS','P')}{$selected=[math]::Max(0,$selected-$size);$navigated=$true}
                'F'{
                    if($Filterable){$filter=Read-Host 'Filter contains [blank: all; B: cancel]';if($null -ne $filter -and $filter.Trim() -ne 'B'){$State.Filter=$filter}}
                    else{$notice='Filtering is not available in this menu.'}
                }
                'R'{if($Refreshable){return [pscustomobject]@{Action='Refresh';Item=$null;State=$State}}else{$notice='Refresh is not available in this menu.'}}
                {$_ -in @('SELECT','')}{$open=$true}
                default{
                    $match=-1
                    if($keys.ContainsKey($choice)){for($j=0;$j -lt $rows.Count;$j++){if([string]$rows[$j].Id -eq $keys[$choice]){$match=$j;break}}}
                    if($match -ge 0){$selected=$match;$open=$true}else{$notice='Choose a listed item or control.'}
                }
            }
            if($selected -ge 0 -and $selected -lt $rows.Count){
                $State.SelectedId=[string]$rows[$selected].Id
                if($open){
                    if($rows[$selected].DisabledReason){$notice=[string]$rows[$selected].DisabledReason}
                    else{return [pscustomobject]@{Action='Select';Item=$rows[$selected];State=$State}}
                }
            }
            if($navigated -and $rows.Count -and $selected -eq $oldSelected -and $cursorControl){
                try{Clear-PcMenuRegion $promptTop 2 $width;Set-PcMenuCursorPosition 0 $promptTop;continue}catch{$cursorControl=$false;break}
            }
            $newPage=if($rows.Count){[int][math]::Floor($selected/[double]$size)}else{0}
            $layoutMatches=$false
            if($cursorControl -and -not $ExpandedPreview -and $navigated -and $newPage -eq $page){
                try{$layoutMatches=([math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1) -eq $width -and (Get-PcMenuPageSize $Host.UI.RawUI.WindowSize.Height $menuDetailLines $PageSize) -eq $size)}catch{}
            }
            if($layoutMatches){
                try{
                    foreach($rowIndex in @($oldSelected,$selected | Select-Object -Unique)){
                        Clear-PcMenuRegion $rowTops[$rowIndex] $rowHeights[$rowIndex] $width
                        Set-PcMenuCursorPosition 0 $rowTops[$rowIndex]
                        $null=Write-PcMenuDisplayItem $rows[$rowIndex] $displayKeys[[string]$rows[$rowIndex].Id] ($rowIndex -eq $selected) $width $menuDetailLines -Compact:$Compact
                    }
                    Clear-PcMenuRegion $promptTop 2 $width;Set-PcMenuCursorPosition 0 $promptTop
                    continue
                }catch{$cursorControl=$false}
            }
            break
        }
    }
}
function Confirm-PcMenuChange {
    param([Parameter(Mandatory=$true)][string]$Description)
    Write-Host $Description
    return ((Read-Host 'Apply this change? [y/N]') -match '^(?i:y|yes)$')
}

function New-PcMenuItem {
    param([string]$Key,[string]$Label,[string]$Kind='Menu',[string]$Detail='', [string]$DisabledReason='')
    [pscustomobject]@{Id=$Key;Key=$Key;Label=$Label;Kind=$Kind;Detail=$Detail;DisabledReason=$DisabledReason}
}
function Get-PcMainSummaryColor([string]$Text) {
    switch -Regex ($Text){
        '^Host:'{return 'Cyan'}
        '^Storage:'{return 'Green'}
        '^Security:'{return 'Magenta'}
        default{return 'White'}
    }
}
function Read-PcCategoryMenu {
    param([string]$Title,[object[]]$Items,[hashtable]$State,[string[]]$Description=@(),[switch]$Root)
    $keyboard=Test-PcMenuKeyboard;$selected=0
    for($i=0;$i -lt $Items.Count;$i++){if($Items[$i].Id -eq $State.SelectedId){$selected=$i;break}}
    while($true){
        $width=120
        if($keyboard){try{$width=[math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{};Clear-Host}
        Write-Host ("`n"+(Get-PcMenuHeading $Title)) -ForegroundColor Cyan
        foreach($line in $Description){if($line){$descriptionColor=if($Root){Get-PcMainSummaryColor $line}else{'DarkGray'};Write-Host (Format-PcMenuText $line $width) -ForegroundColor $descriptionColor}}
        for($i=0;$i -lt $Items.Count;$i++){
            $item=$Items[$i]
            $color=if($keyboard -and $i -eq $selected){'Cyan'}elseif($item.DisabledReason){'DarkGray'}elseif($item.Kind -eq 'Change'){'Yellow'}else{'Gray'}
            $marker=if($keyboard -and $i -eq $selected){'>'}else{' '}
            $label='{0} [{1}] {2}' -f $marker,$item.Key,$item.Label
            if($item.Kind -eq 'Change'){$label+=' [CHANGES SYSTEM]'}
            if($item.DisabledReason){$label+=' [UNAVAILABLE: '+$item.DisabledReason+']'}
            elseif(([string]($item.Detail -join ' ')) -match '(?i)\bPowerShell\s+(7(?:\.\d+)*)\+'){$label+=' - PowerShell '+$Matches[1]+'+'}
            Write-Host (Format-PcMenuText $label $width) -ForegroundColor $color
        }
        if($Root){
            if($keyboard){Write-Host 'Arrows + Enter or number + Enter | Ctrl+C: quit'}
            else{Write-Host 'Number + Enter | Ctrl+C: quit'}
        }elseif($keyboard){Write-Host 'Arrows + Enter or number + Enter | Esc/Backspace/B/0: back'}
        else{Write-Host 'Number + Enter | B / 0: back'}
        $answer=Read-PcMenuInput $keyboard
        if($null -eq $answer){return 'B'}
        if($answer.Trim() -in @('Back','B','0')){if($Root){continue};return 'B'}
        $item=$null
        switch($answer.Trim().ToUpperInvariant()){
            'UP'{$selected=[math]::Max(0,$selected-1)}
            'DOWN'{$selected=[math]::Min($Items.Count-1,$selected+1)}
            'FIRST'{$selected=0} 'LAST'{$selected=$Items.Count-1}
            {$_ -in @('SELECT','')}{if($Items.Count){$item=$Items[$selected]}}
            default{$item=$Items | Where-Object Key -EQ $answer.Trim() | Select-Object -First 1;if(-not $item){Write-Warning 'Choose a listed number or shortcut.';Wait-PcMenuReturn}}
        }
        if($selected -ge 0 -and $selected -lt $Items.Count){$State.SelectedId=[string]$Items[$selected].Id}
        if(-not $item){continue}
        for($i=0;$i -lt $Items.Count;$i++){if($Items[$i].Id -eq $item.Id){$selected=$i;break}}
        $State.SelectedId=[string]$item.Id
        if($item.DisabledReason){Write-Warning $item.DisabledReason;Wait-PcMenuReturn;continue}
        $State.SelectedId=[string]$item.Id
        return [string]$item.Id
    }
}
function Wait-PcMenuReturn {
    if(Test-PcMenuKeyboard){$null=Read-Host 'Enter to return'}
}

function Show-PcListDetails {
    param($Row,[string]$Title='Details')
    Clear-PcMenuScreen
    Write-Host ("`n"+$Title) -ForegroundColor Cyan
    $Row | Format-List * | Out-Host
    while($true){
        Write-Host 'Enter / Esc / Backspace / B: back'
        $answer=Read-PcMenuInput (Test-PcMenuKeyboard)
        if($null -eq $answer -or $answer.Trim() -in @('','Select','Back','B','0')){return}
    }
}
# END MENU ENGINE

function Get-PcInternetPrivateIPv4 {
    try {
        $routes=@(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Where-Object {$_.State -ne 'Invalid'} | Sort-Object @{Expression={([int64]$_.RouteMetric)+([int64]$_.InterfaceMetric)}},InterfaceIndex)
        foreach($route in $routes){
            $addresses=@(Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction Stop | Where-Object {
                $_.IPAddress -and -not $_.SkipAsSource -and $_.AddressState -notin @('Tentative','Duplicate','Invalid') -and $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*'
            } | Sort-Object @{Expression={if($_.AddressState -eq 'Preferred'){0}else{1}}},IPAddress)
            if($addresses.Count){return [string]$addresses[0].IPAddress}
        }
    } catch {}

    $socket=$null
    try {
        # A connected UDP socket asks the Windows routing stack for the selected source
        # address without sending a packet.
        $socket=New-Object Net.Sockets.Socket ([Net.Sockets.AddressFamily]::InterNetwork),([Net.Sockets.SocketType]::Dgram),([Net.Sockets.ProtocolType]::Udp)
        $socket.Connect([Net.IPAddress]::Parse('1.1.1.1'),53)
        $address=[string]$socket.LocalEndPoint.Address
        if($address -and $address -notlike '127.*' -and $address -notlike '169.254.*'){return $address}
    } catch {} finally {if($socket){$socket.Dispose()}}
    return $null
}

function Get-PcSecurityHeader {
    $defender=$null
    try{if(Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue){$defender=Get-MpComputerStatus -ErrorAction Stop}}catch{}
    if($defender -and $defender.AntivirusEnabled -and $defender.RealTimeProtectionEnabled){
        $label='Microsoft Defender';if($defender.AMProductVersion){$label+=' '+[string]$defender.AMProductVersion}
        $label+=' | Real-time: On';if($defender.AntivirusSignatureVersion){$label+=' | Signatures: '+[string]$defender.AntivirusSignatureVersion}
        return $label
    }
    $providers=@()
    try{
        $registered=@(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -OperationTimeoutSec 3 -ErrorAction Stop | Where-Object {$_.displayName -and $_.displayName -notmatch 'Microsoft Defender|Windows Defender'})
        foreach($name in @($registered.displayName | Sort-Object -Unique)){
            $version=$null
            foreach($product in @($registered | Where-Object displayName -eq $name)){
                try{$version=(Get-Item -LiteralPath $product.pathToSignedProductExe -ErrorAction Stop).VersionInfo.ProductVersion}catch{}
                if($version){break}
            }
            $providers+=if($version){$name+' '+$version}else{$name}
        }
    }catch{}
    $mode=if($defender -and $defender.AMRunningMode){[string]$defender.AMRunningMode}elseif($defender){'Inactive'}else{'Unavailable'}
    if($providers.Count){return (($providers -join ', ')+' (registered) | Defender: '+$mode)}
    if($defender){
        $label='Microsoft Defender';if($defender.AMProductVersion){$label+=' '+[string]$defender.AMProductVersion}
        return ($label+' | Real-time: Off | Mode: '+$mode)
    }
    return 'Unavailable'
}

function Test-PcSystemSummaryCache($Summary,[string]$SchemaVersion='0.25.0') {
    return ($null -ne $Summary -and [string]$Summary.SchemaVersion -eq $SchemaVersion)
}

function Format-PcUptime([timespan]$Value) {
    if($Value.TotalSeconds -lt 0){return 'Unavailable'}
    if($Value.Days -gt 0){return ('{0}d {1:00}h {2:00}m' -f $Value.Days,$Value.Hours,$Value.Minutes)}
    if($Value.Hours -gt 0){return ('{0}h {1:00}m' -f $Value.Hours,$Value.Minutes)}
    return ('{0}m' -f [math]::Max(0,$Value.Minutes))
}

function Get-PcSystemSummary {
    $schemaVersion='0.25.0'
    if(Test-PcSystemSummaryCache $script:PcSystemSummary $schemaVersion){return $script:PcSystemSummary}

    $unavailable='Unavailable'
    $username=$unavailable;$groups=$unavailable;$privateIp=$unavailable;$publicIp=$unavailable
    $hostname=[Environment]::MachineName;$storage=$unavailable;$cpu=$unavailable;$ram=$unavailable;$osVersion=$unavailable;$securitySummary=$unavailable
    $userSid=$unavailable;$authenticationType=$unavailable;$administrator=$unavailable;$groupNames=@()
    $manufacturer=$unavailable;$model=$unavailable;$domain=$unavailable;$domainJoined=$unavailable
    $cpuCores=$unavailable;$logicalProcessors=$unavailable;$diskDetails=@();$osArchitecture=$unavailable;$lastBoot=$unavailable;$lastBootTime=$null;$uptime=$unavailable

    try {
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        $username=[string]$identity.Name
        $userSid=[string]$identity.User.Value
        $authenticationType=[string]$identity.AuthenticationType
        $principal=New-Object Security.Principal.WindowsPrincipal($identity)
        $administrator=[string]($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
        $groupNames=@(foreach($sid in $identity.Groups){try{$sid.Translate([Security.Principal.NTAccount]).Value}catch{[string]$sid.Value}}) | Sort-Object -Unique
        if($groupNames.Count){$groups=$groupNames -join ', '}
    } catch {
        if([Environment]::UserName){$username=[Environment]::UserName}
    }
    try {$selectedAddress=Get-PcInternetPrivateIPv4;if($selectedAddress){$privateIp=$selectedAddress}} catch {}
    try {
        $response=Invoke-RestMethod -UseBasicParsing -Uri 'https://api.ipify.org?format=json' -TimeoutSec 3 -ErrorAction Stop
        if($response.ip){$publicIp=[string]$response.ip}
    } catch {}
    try {
        $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -OperationTimeoutSec 5 -ErrorAction Stop | Where-Object Size)
        if($disks.Count){
            $total=($disks | Measure-Object Size -Sum).Sum;$free=($disks | Measure-Object FreeSpace -Sum).Sum
            $storage=('{0:N1} GiB free / {1:N1} GiB' -f ($free/1GB),($total/1GB))
            $diskDetails=@($disks | Sort-Object DeviceID | ForEach-Object {('{0} {1:N1} GiB free / {2:N1} GiB' -f $_.DeviceID,($_.FreeSpace/1GB),($_.Size/1GB))})
        }
    } catch {}
    try {
        $processors=@(Get-CimInstance Win32_Processor -OperationTimeoutSec 5 -ErrorAction Stop)
        if($processors.Count){
            $cpu=(@($processors.Name | ForEach-Object {$_.Trim()} | Sort-Object -Unique) -join ' + ')
            $cpuCores=[string](($processors | Measure-Object NumberOfCores -Sum).Sum)
            $logicalProcessors=[string](($processors | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
        }
    } catch {}
    try {
        $computer=Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 5 -ErrorAction Stop
        if($computer.TotalPhysicalMemory){$ram=('{0:N1} GiB' -f ($computer.TotalPhysicalMemory/1GB))}
        if($computer.Manufacturer){$manufacturer=[string]$computer.Manufacturer}
        if($computer.Model){$model=[string]$computer.Model}
        if($computer.Domain){$domain=[string]$computer.Domain}
        $domainJoined=[string][bool]$computer.PartOfDomain
    } catch {}
    try {
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 5 -ErrorAction Stop
        $osVersion=('{0} {1} (build {2})' -f $os.Caption,$os.Version,$os.BuildNumber).Trim()
        if($os.OSArchitecture){$osArchitecture=[string]$os.OSArchitecture}
        if($os.LastBootUpTime){$lastBootTime=[datetime]$os.LastBootUpTime;$lastBoot=$lastBootTime.ToString('yyyy-MM-dd HH:mm:ss');$uptime=Format-PcUptime ((Get-Date)-$lastBootTime)}
    } catch {}
    try{$securitySummary=Get-PcSecurityHeader}catch{}

    $script:PcSystemSummary=[pscustomobject]@{
        SchemaVersion=$schemaVersion
        Username=$username;Groups=$groups;Hostname=$hostname;PrivateIp=$privateIp;PublicIp=$publicIp
        Storage=$storage;Cpu=$cpu;Ram=$ram;OsVersion=$osVersion;SecuritySummary=$securitySummary
        UserSid=$userSid;AuthenticationType=$authenticationType;Administrator=$administrator;GroupNames=@($groupNames)
        Manufacturer=$manufacturer;Model=$model;Domain=$domain;DomainJoined=$domainJoined
        CpuCores=$cpuCores;LogicalProcessors=$logicalProcessors;DiskDetails=@($diskDetails)
        OsArchitecture=$osArchitecture;LastBoot=$lastBoot;LastBootTime=$lastBootTime;Uptime=$uptime
    }
    return $script:PcSystemSummary
}

function Show-PcSystemDetails($Summary) {
    Clear-PcMenuScreen
    Write-Host "`nCOMPUTER AND USER DETAILS" -ForegroundColor Cyan
    Write-Host "`nUSER" -ForegroundColor Cyan
    Write-Host ('Name: '+$Summary.Username)
    Write-Host ('SID: '+$Summary.UserSid)
    Write-Host ('Authentication: '+$Summary.AuthenticationType)
    Write-Host ('Administrator token: '+$Summary.Administrator)
    Write-Host 'Groups:'
    if(@($Summary.GroupNames).Count){foreach($group in $Summary.GroupNames){Write-Host ('  '+$group)}}else{Write-Host ('  '+$Summary.Groups)}

    Write-Host "`nCOMPUTER" -ForegroundColor Cyan
    Write-Host ('Hostname: '+$Summary.Hostname)
    Write-Host ('Manufacturer: '+$Summary.Manufacturer)
    Write-Host ('Model: '+$Summary.Model)
    Write-Host ('Domain/workgroup: '+$Summary.Domain)
    Write-Host ('Domain joined: '+$Summary.DomainJoined)

    Write-Host "`nNETWORK" -ForegroundColor Cyan
    Write-Host ('Internet-route private IPv4: '+$Summary.PrivateIp)
    Write-Host ('Public IP: '+$Summary.PublicIp)

    Write-Host "`nHARDWARE" -ForegroundColor Cyan
    Write-Host ('CPU: '+$Summary.Cpu)
    Write-Host ('Physical cores: '+$Summary.CpuCores)
    Write-Host ('Logical processors: '+$Summary.LogicalProcessors)
    Write-Host ('Physical RAM: '+$Summary.Ram)
    Write-Host 'Fixed storage:'
    if(@($Summary.DiskDetails).Count){foreach($disk in $Summary.DiskDetails){Write-Host ('  '+$disk)}}else{Write-Host ('  '+$Summary.Storage)}

    Write-Host "`nWINDOWS" -ForegroundColor Cyan
    Write-Host ('Version: '+$Summary.OsVersion)
    Write-Host ('Architecture: '+$Summary.OsArchitecture)
    Write-Host ('Last boot: '+$Summary.LastBoot)
    Write-Host ('Uptime: '+(Get-PcSummaryUptime $Summary))
    Write-Host "`nEnter / Esc / Backspace / B: back"
    if(Test-PcMenuKeyboard){
        while($true){
            $answer=ConvertFrom-PcMenuKey (Read-PcMenuKey)
            if($answer -in @('Select','Back','b','B')){return}
        }
    }
    $null=Read-Host 'Enter to return'
}

function Get-PcSummaryUptime($Summary) {
    if($Summary.LastBootTime){try{return Format-PcUptime ((Get-Date)-[datetime]$Summary.LastBootTime)}catch{}}
    return [string]$Summary.Uptime
}

function Format-PcSystemSummary($Summary) {
    $uptime=Get-PcSummaryUptime $Summary
    @(
        "User: $($Summary.Username)"
        "Host: $($Summary.Hostname) | Public IP: $($Summary.PublicIp) | Private IP: $($Summary.PrivateIp)"
        "Storage: $($Summary.Storage) | CPU: $($Summary.Cpu) | RAM: $($Summary.Ram)"
        "OS: $($Summary.OsVersion) | Uptime: $uptime"
        "Security: $($Summary.SecuritySummary)"
    )
}

# BEGIN CERTIFICATE AND TLS DIAGNOSTICS
function Get-PcCertificateDnsNames($Certificate) {
    $names=New-Object 'Collections.Generic.List[string]'
    if($Certificate.PSObject.Properties['DnsNameList']){
        foreach($name in @($Certificate.DnsNameList)){
            $value=if($name.PSObject.Properties['Unicode']){[string]$name.Unicode}else{[string]$name}
            if($value -and -not $names.Contains($value)){$names.Add($value)}
        }
    }
    if(-not $names.Count){
        $simple=$Certificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::DnsName,$false)
        if($simple){$names.Add($simple)}
    }
    $names.ToArray()
}

function Get-PcCertificateEkus($Certificate) {
    $values=New-Object 'Collections.Generic.List[string]'
    foreach($extension in @($Certificate.Extensions)){
        if($extension.Oid.Value -ne '2.5.29.37'){continue}
        try{
            $eku=New-Object Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($extension,$extension.Critical)
            foreach($oid in $eku.EnhancedKeyUsages){$values.Add($(if($oid.FriendlyName){$oid.FriendlyName}else{$oid.Value}))}
        }catch{$values.Add('Unreadable EKU extension')}
    }
    $values.ToArray()
}

function Get-PcCertificateKeyInfo($Certificate) {
    $algorithm=$Certificate.PublicKey.Oid.FriendlyName
    $size=$null
    try{$size=$Certificate.PublicKey.Key.KeySize}catch{}
    [pscustomobject]@{Algorithm=$algorithm;Size=$size}
}

function Get-PcCertificateAssessment($Certificate,[string]$Location,[string]$Store,[int]$WarningDays=30) {
    $now=Get-Date;$status='PASS';$findings=New-Object 'Collections.Generic.List[string]'
    if($Certificate.NotAfter -lt $now){$status='WARN';$findings.Add('Expired')}
    elseif($Certificate.NotBefore -gt $now){$status='WARN';$findings.Add('Not yet valid')}
    elseif($Certificate.NotAfter -le $now.AddDays($WarningDays)){$status='WARN';$findings.Add("Expires within $WarningDays days")}
    $key=Get-PcCertificateKeyInfo $Certificate
    if([string]$Certificate.SignatureAlgorithm.FriendlyName -match '(?i)md5|sha1'){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('Legacy signature algorithm')
    }
    if($key.Algorithm -match '(?i)RSA' -and $key.Size -and $key.Size -lt 2048){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('RSA key shorter than 2048 bits')
    }
    if($Store -in @('My','WebHosting') -and -not $Certificate.HasPrivateKey){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('No private key')
    }
    if($Store -in @('My','WebHosting') -and $Certificate.Subject -eq $Certificate.Issuer){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('Self-signed certificate in a leaf store')
    }
    $ekus=@(Get-PcCertificateEkus $Certificate)
    [pscustomobject]@{
        Status=$status;Location=$Location;Store=$Store;Subject=$Certificate.Subject
        DnsNames=@(Get-PcCertificateDnsNames $Certificate) -join ', '
        Issuer=$Certificate.Issuer;NotBefore=$Certificate.NotBefore;NotAfter=$Certificate.NotAfter
        DaysRemaining=[math]::Floor(($Certificate.NotAfter-$now).TotalDays);Thumbprint=$Certificate.Thumbprint
        HasPrivateKey=$Certificate.HasPrivateKey;KeyAlgorithm=$key.Algorithm;KeySize=$key.Size
        SignatureAlgorithm=$Certificate.SignatureAlgorithm.FriendlyName;EnhancedKeyUsage=$ekus -join ', '
        Finding=$(if($findings.Count){$findings -join '; '}else{'No issue found by the local metadata checks.'})
        Detail='Metadata assessment only. Application bindings, chain trust, revocation and private-key permissions are separate checks.'
    }
}

function Get-PcCertificateStoreItems([string]$Location,[string]$Store) {
    @(Get-ChildItem -LiteralPath ("Cert:\{0}\{1}" -f $Location,$Store) -ErrorAction Stop)
}

function Get-PcCertificateInventory {
    param([int]$WarningDays=30)
    foreach($location in @('LocalMachine','CurrentUser')){
        foreach($store in @('My','WebHosting')){
            try{
                foreach($certificate in @(Get-PcCertificateStoreItems $location $store)){
                    Get-PcCertificateAssessment $certificate $location $store $WarningDays
                }
            }catch{
                [pscustomobject]@{Status='UNAVAILABLE';Location=$location;Store=$store;Subject='Certificate store unavailable';Finding=$_.Exception.Message;Detail='The toolkit continued with the remaining stores.'}
            }
        }
    }
}

function Find-PcCertificate {
    param([Parameter(Mandatory=$true)][string]$Thumbprint)
    $normalized=($Thumbprint -replace '[^0-9a-fA-F]','').ToUpperInvariant()
    if(-not $normalized){throw 'Enter a certificate thumbprint.'}
    foreach($location in @('LocalMachine','CurrentUser')){
        foreach($store in @('My','WebHosting','CA','Root','TrustedPeople')){
            try{
                $match=Get-PcCertificateStoreItems $location $store | Where-Object {($_.Thumbprint -replace '\s','').ToUpperInvariant() -eq $normalized} | Select-Object -First 1
                if($match){return [pscustomobject]@{Certificate=$match;Location=$location;Store=$store}}
            }catch{}
        }
    }
    throw "Certificate $normalized was not found in the inspected user or computer stores."
}

function Get-PcCertificateFromInput([string]$InputValue) {
    $value=$InputValue.Trim()
    if(-not $value){throw 'Enter a certificate thumbprint or a .cer/.crt file path.'}
    if(Test-Path -LiteralPath $value -PathType Leaf){
        $full=[IO.Path]::GetFullPath($value)
        if([IO.Path]::GetExtension($full).ToLowerInvariant() -notin @('.cer','.crt','.der')){throw 'Only public .cer, .crt, or .der certificate files are accepted. PFX/private-key files are not loaded.'}
        $certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2($full)
        return [pscustomobject]@{Certificate=$certificate;Source=$full;Disposable=$true}
    }
    $found=Find-PcCertificate $value
    [pscustomobject]@{Certificate=$found.Certificate;Source=("{0}\{1}" -f $found.Location,$found.Store);Disposable=$false}
}

function Test-PcCertificateChain {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Certificate,[switch]$OnlineRevocation,[string]$Source='Certificate')
    $chain=New-Object Security.Cryptography.X509Certificates.X509Chain
    try{
        $chain.ChainPolicy.RevocationMode=if($OnlineRevocation){[Security.Cryptography.X509Certificates.X509RevocationMode]::Online}else{[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck}
        $chain.ChainPolicy.RevocationFlag=[Security.Cryptography.X509Certificates.X509RevocationFlag]::EntireChain
        $chain.ChainPolicy.VerificationFlags=[Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
        $chain.ChainPolicy.UrlRetrievalTimeout=[timespan]::FromSeconds(10)
        $valid=$chain.Build($Certificate)
        $overall=@($chain.ChainStatus | ForEach-Object {$_.Status.ToString()+': '+$_.StatusInformation.Trim()}) -join '; '
        if(-not $overall){$overall='Chain built successfully.'}
        $index=0
        foreach($element in @($chain.ChainElements)){
            $statuses=@($element.ChainElementStatus | ForEach-Object {$_.Status.ToString()+': '+$_.StatusInformation.Trim()}) -join '; '
            if(-not $statuses){$statuses='OK'}
            [pscustomobject]@{Status=$(if($valid){'PASS'}else{'WARN'});Source=$Source;Position=$index;Subject=$element.Certificate.Subject;Issuer=$element.Certificate.Issuer;NotAfter=$element.Certificate.NotAfter;Thumbprint=$element.Certificate.Thumbprint;ChainStatus=$statuses;RevocationMode=$chain.ChainPolicy.RevocationMode;Detail=$overall}
            $index++
        }
        if(-not $chain.ChainElements.Count){[pscustomobject]@{Status='WARN';Source=$Source;Position=0;Subject=$Certificate.Subject;Thumbprint=$Certificate.Thumbprint;ChainStatus=$overall;RevocationMode=$chain.ChainPolicy.RevocationMode;Detail='Windows returned no chain elements.'}}
    }finally{$chain.Dispose()}
}

function Invoke-PcCertificateChainPrompt {
    $inputValue=Read-PcInput 'Certificate thumbprint or .cer/.crt path'
    $online=(Read-PcInput 'Check revocation online? [y/N]') -match '^(?i:y|yes)$'
    $selected=Get-PcCertificateFromInput $inputValue
    try{Test-PcCertificateChain -Certificate $selected.Certificate -OnlineRevocation:$online -Source $selected.Source}
    finally{if($selected.Disposable){$selected.Certificate.Dispose()}}
}

function Connect-PcTcpClient([string]$HostName,[int]$Port,[int]$TimeoutMilliseconds) {
    $client=New-Object Net.Sockets.TcpClient
    $pending=$client.BeginConnect($HostName,$Port,$null,$null)
    try{
        if(-not $pending.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)){$client.Dispose();throw "TCP connection timed out after $TimeoutMilliseconds ms."}
        try{$client.EndConnect($pending)}catch{$client.Dispose();throw}
    }finally{$pending.AsyncWaitHandle.Close()}
    $client
}

function Test-PcTlsEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$HostName,
        [ValidateRange(1,65535)][int]$Port=443,
        [ValidateSet('SystemDefault','Tls12','Tls11','Tls')][string]$Protocol='SystemDefault',
        [ValidateRange(1000,30000)][int]$TimeoutMilliseconds=8000,
        [switch]$OnlineRevocation
    )
    $dnsTask=[Net.Dns]::GetHostAddressesAsync($HostName)
    if(-not $dnsTask.Wait($TimeoutMilliseconds)){throw "DNS resolution timed out after $TimeoutMilliseconds ms."}
    $addresses=@($dnsTask.Result | ForEach-Object {$_.IPAddressToString})
    if(-not $addresses.Count){throw "DNS returned no addresses for $HostName."}
    $watch=[Diagnostics.Stopwatch]::StartNew();$client=$null;$stream=$null;$remote=$null;$policyErrors=$null
    try{
        $client=Connect-PcTcpClient $HostName $Port $TimeoutMilliseconds;$tcpMs=$watch.ElapsedMilliseconds;$watch.Restart()
        $client.ReceiveTimeout=$TimeoutMilliseconds;$client.SendTimeout=$TimeoutMilliseconds
        $callback=[Net.Security.RemoteCertificateValidationCallback]{param($sender,$certificate,$chain,$errors)$script:PcTlsRemoteCertificateBytes=$certificate.GetRawCertData();$script:PcTlsPolicyErrors=$errors;return $true}
        $script:PcTlsRemoteCertificateBytes=$null;$script:PcTlsPolicyErrors=$null
        $stream=New-Object Net.Security.SslStream($client.GetStream(),$false,$callback)
        $stream.ReadTimeout=$TimeoutMilliseconds;$stream.WriteTimeout=$TimeoutMilliseconds
        $requested=switch($Protocol){'Tls12'{[Security.Authentication.SslProtocols]::Tls12}'Tls11'{[Security.Authentication.SslProtocols]::Tls11}'Tls'{[Security.Authentication.SslProtocols]::Tls}default{[Security.Authentication.SslProtocols]::None}}
        $stream.AuthenticateAsClient($HostName,$null,$requested,$false);$tlsMs=$watch.ElapsedMilliseconds
        if(-not $script:PcTlsRemoteCertificateBytes){throw 'The peer did not present a certificate.'}
        $remote=New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$script:PcTlsRemoteCertificateBytes)
        $policyErrors=[string]$script:PcTlsPolicyErrors
        $chainRows=@(Test-PcCertificateChain -Certificate $remote -OnlineRevocation:$OnlineRevocation -Source ("{0}:{1}" -f $HostName,$Port))
        $chainValid=-not @($chainRows | Where-Object Status -ne 'PASS').Count
        $status=if($policyErrors -eq 'None' -and $chainValid -and $remote.NotBefore -le (Get-Date) -and $remote.NotAfter -ge (Get-Date)){'PASS'}else{'WARN'}
        [pscustomobject]@{
            Status=$status;Host=$HostName;Port=$Port;Addresses=$addresses -join ', ';RequestedProtocol=$Protocol
            NegotiatedProtocol=$stream.SslProtocol;Cipher=$stream.CipherAlgorithm;CipherStrength=$stream.CipherStrength
            Hash=$stream.HashAlgorithm;HashStrength=$stream.HashStrength;KeyExchange=$stream.KeyExchangeAlgorithm;KeyExchangeStrength=$stream.KeyExchangeStrength
            TcpMilliseconds=$tcpMs;TlsMilliseconds=$tlsMs;Subject=$remote.Subject;DnsNames=@(Get-PcCertificateDnsNames $remote) -join ', '
            Issuer=$remote.Issuer;NotBefore=$remote.NotBefore;NotAfter=$remote.NotAfter;Thumbprint=$remote.Thumbprint
            PolicyErrors=$policyErrors;ChainStatus=($chainRows | Select-Object -ExpandProperty Detail -First 1)
            Detail='The diagnostic accepted the presented certificate only to inspect it and sent no application data. PolicyErrors and ChainStatus remain authoritative findings.'
        }
    }finally{
        $script:PcTlsRemoteCertificateBytes=$null;$script:PcTlsPolicyErrors=$null
        if($remote){$remote.Dispose()};if($stream){$stream.Dispose()};if($client){$client.Dispose()}
    }
}

function Invoke-PcTlsEndpointPrompt {
    $hostName=(Read-PcInput 'TLS host name').Trim();if(-not $hostName){throw 'Enter a TLS host name.'}
    $portText=(Read-PcInput 'Port [443]').Trim();$port=443
    if($portText -and (-not [int]::TryParse($portText,[ref]$port) -or $port -lt 1 -or $port -gt 65535)){throw 'Port must be from 1 to 65535.'}
    $protocolText=(Read-PcInput 'Protocol: system, tls12, tls11 or tls [system]').Trim().ToLowerInvariant()
    $protocol=switch($protocolText){'tls12'{'Tls12'}'tls11'{'Tls11'}'tls'{'Tls'}default{'SystemDefault'}}
    $online=(Read-PcInput 'Check certificate revocation online? [y/N]') -match '^(?i:y|yes)$'
    Test-PcTlsEndpoint -HostName $hostName -Port $port -Protocol $protocol -OnlineRevocation:$online
}

function Invoke-PcNetshHttp([string[]]$Arguments) {
    $output=@(& netsh.exe @Arguments 2>&1);$exit=$LASTEXITCODE
    [pscustomobject]@{ExitCode=$exit;Output=@($output | ForEach-Object {[string]$_})}
}

function ConvertFrom-PcHttpSslBindingText([string[]]$Lines) {
    $rows=New-Object 'Collections.Generic.List[object]';$current=$null
    foreach($line in $Lines){
        if($line -match '^\s*(IP:port|Hostname:port|Central Certificate Store)\s*:\s*(.+?)\s*$'){
            if($current){$rows.Add([pscustomobject]$current)}
            $current=[ordered]@{Binding=$Matches[2].Trim();BindingType=$Matches[1];CertificateHash='';CertificateStore='';ApplicationId='';Raw=New-Object 'Collections.Generic.List[string]'}
        }
        if($current){
            $current.Raw.Add($line.Trim())
            if($line -match '^\s*Certificate Hash\s*:\s*(.+?)\s*$'){$current.CertificateHash=($Matches[1] -replace '\s','')}
            elseif($line -match '^\s*Certificate Store Name\s*:\s*(.+?)\s*$'){$current.CertificateStore=$Matches[1].Trim()}
            elseif($line -match '^\s*Application ID\s*:\s*(.+?)\s*$'){$current.ApplicationId=$Matches[1].Trim()}
        }
    }
    if($current){$rows.Add([pscustomobject]$current)}
    $rows.ToArray()
}

function Get-PcHttpSslBindings {
    $result=Invoke-PcNetshHttp @('http','show','sslcert')
    if($result.ExitCode -ne 0){throw ('netsh http show sslcert failed: '+($result.Output -join ' '))}
    $bindings=@(ConvertFrom-PcHttpSslBindingText $result.Output)
    if(-not $bindings.Count){return [pscustomobject]@{Status='INFO';Binding='None found';Finding='No parseable HTTP.sys SSL bindings were returned.';Detail=($result.Output -join "`n")}}
    foreach($binding in $bindings){
        $status='PASS';$finding='Binding certificate found.';$certificate=$null
        if(-not $binding.CertificateHash){$status='WARN';$finding='Binding has no certificate hash.'}
        else{
            $store=if($binding.CertificateStore){$binding.CertificateStore}else{'My'}
            try{$certificate=Get-PcCertificateStoreItems LocalMachine $store | Where-Object {($_.Thumbprint -replace '\s','') -eq ($binding.CertificateHash -replace '\s','')} | Select-Object -First 1}catch{}
            if(-not $certificate){$status='WARN';$finding="Certificate was not found in LocalMachine\$store."}
            elseif($certificate.NotAfter -lt (Get-Date)){$status='WARN';$finding='Bound certificate is expired.'}
            elseif($certificate.NotAfter -le (Get-Date).AddDays(30)){$status='WARN';$finding='Bound certificate expires within 30 days.'}
            elseif(-not $certificate.HasPrivateKey){$status='WARN';$finding='Bound certificate has no accessible private-key association.'}
        }
        [pscustomobject]@{Status=$status;Binding=$binding.Binding;BindingType=$binding.BindingType;ApplicationId=$binding.ApplicationId;CertificateStore=$(if($binding.CertificateStore){$binding.CertificateStore}else{'My'});CertificateHash=$binding.CertificateHash;Subject=$(if($certificate){$certificate.Subject}else{$null});NotAfter=$(if($certificate){$certificate.NotAfter}else{$null});Finding=$finding;Detail=($binding.Raw -join '; ')}
    }
}

function Get-PcCertificateEventSummary {
    param([int]$Hours=168)
    $events=@(Get-PcEventRecords -LogName System -Hours $Hours -Provider Schannel -Limit 100)
    if(-not $events.Count){return [pscustomobject]@{Status='PASS';Log='System';Provider='Schannel';Count=0;Finding="No Schannel events were found in the last $Hours hours.";Detail='Event logging level and log retention affect this result.'}}
    [pscustomobject]@{Status='REVIEW';Log='System';Provider='Schannel';Count=$events.Count;Finding="Schannel events found in the last $Hours hours.";Recent=($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Id) $($_.Message)"}) -join "`n";Detail='Historical events are evidence to inspect, not proof of a current fault.'}
}

function Get-PcCertificateReadiness {
    $rows=New-Object 'Collections.Generic.List[object]'
    $certificates=@(Get-PcCertificateInventory)
    $attention=@($certificates | Where-Object Status -in @('WARN','REVIEW','UNAVAILABLE'))
    $rows.Add([pscustomobject]@{Status=$(if(@($certificates|Where-Object Status -eq 'WARN').Count){'WARN'}elseif($attention.Count){'REVIEW'}else{'PASS'});Check='Local certificate metadata';Finding=$(if($attention.Count){"$($attention.Count) certificate/store findings need review."}else{"$($certificates.Count) certificates checked; no metadata finding."});Detail=($attention | Select-Object -First 10 | ForEach-Object {"$($_.Location)\$($_.Store) $($_.Subject): $($_.Finding)"}) -join "`n"})
    try{
        $bindings=@(Get-PcHttpSslBindings);$bindingAttention=@($bindings|Where-Object Status -in @('WARN','REVIEW','UNAVAILABLE'))
        $rows.Add([pscustomobject]@{Status=$(if(@($bindings|Where-Object Status -eq 'WARN').Count){'WARN'}elseif($bindingAttention.Count){'REVIEW'}else{'PASS'});Check='HTTP.sys SSL bindings';Finding=$(if($bindingAttention.Count){"$($bindingAttention.Count) binding findings need review."}else{"$($bindings.Count) binding results checked."});Detail=($bindingAttention|ForEach-Object{"$($_.Binding): $($_.Finding)"}) -join "`n"})
    }catch{$rows.Add([pscustomobject]@{Status='UNAVAILABLE';Check='HTTP.sys SSL bindings';Finding=$_.Exception.Message;Detail='The readiness check continued.'})}
    try{$rows.Add((Get-PcCertificateEventSummary))}catch{$rows.Add([pscustomobject]@{Status='UNAVAILABLE';Check='Recent Schannel events';Finding=$_.Exception.Message;Detail='The readiness check continued.'})}
    $rows.ToArray()
}

function Get-PcCertificateChecks {
    @(
        [pscustomobject]@{Key='1';Id='cert-inventory';Name='Local certificate health';MinPS='5.0';Commands=@('Get-ChildItem');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateInventory}}
        [pscustomobject]@{Key='2';Id='tls-endpoint';Name='Remote TLS endpoint test';MinPS='5.0';Commands=@();Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Invoke-PcTlsEndpointPrompt}}
        [pscustomobject]@{Key='3';Id='cert-chain';Name='Certificate chain validator';MinPS='5.0';Commands=@('Get-ChildItem');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Invoke-PcCertificateChainPrompt}}
        [pscustomobject]@{Key='4';Id='http-ssl-bindings';Name='HTTP.sys SSL binding audit';MinPS='5.0';Commands=@('netsh.exe');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcHttpSslBindings}}
        [pscustomobject]@{Key='5';Id='cert-readiness';Name='Certificate readiness summary';MinPS='5.0';Commands=@('Get-ChildItem','netsh.exe','Get-WinEvent');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateReadiness}}
        [pscustomobject]@{Key='6';Id='schannel-summary';Name='Recent Schannel event summary';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateEventSummary}}
        [pscustomobject]@{Key='7';Id='capi2-events';Name='CAPI2 certificate event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CAPI2/Operational'}}
        [pscustomobject]@{Key='8';Id='cert-lifecycle-system';Name='Machine certificate lifecycle events';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CertificateServicesClient-Lifecycle-System/Operational'}}
        [pscustomobject]@{Key='9';Id='cert-lifecycle-user';Name='User certificate lifecycle events';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CertificateServicesClient-Lifecycle-User/Operational'}}
    )
}

function Start-PcCertificateMenu { Start-PcDiagnosticMenu 'Windows > Certificates and TLS' @(Get-PcCertificateChecks) }
# END CERTIFICATE AND TLS DIAGNOSTICS

# BEGIN SQL SNIPPETS
# SQL Server Snippets — reusable snippet browser.
#
# Renders the snippet registry returned by Get-PcSqlSnippetRegistry (generated
# from win/sql/* by tests/Sync-SqlSnippets.ps1). It generates, displays, and
# copies T-SQL text only: it never connects to a server, never executes SQL,
# and never requests credentials.
#
# The escaping helpers below are the T-SQL-specific extension point. To add
# another engine later, supply a dialect with its own identifier/literal rules
# and reuse the menu, parameter, and clipboard machinery unchanged.

function ConvertTo-PcSqlIdentifier {
    # [name] with embedded ] escaped as ]].
    param([AllowEmptyString()][string]$Value)
    '[' + ($Value -replace '\]', ']]') + ']'
}

function ConvertTo-PcSqlLiteral {
    # N'value' with embedded single quotes doubled; NULL for $null.
    param($Value)
    if ($null -eq $Value) { return 'NULL' }
    "N'" + (([string]$Value) -replace "'", "''") + "'"
}

function ConvertTo-PcSqlParameterValue {
    param([object]$Parameter, [AllowNull()][string]$Value)
    $kind = if ($Parameter.Kind) { [string]$Parameter.Kind } else { 'Identifier' }
    switch ($kind) {
        'Literal' { return ConvertTo-PcSqlLiteral $Value }
        'Integer' {
            if ($Value -notmatch '^-?\d+$') { throw "$($Parameter.Name) must be a whole number." }
            $number = 0L
            if (-not [long]::TryParse($Value, [ref]$number)) { throw "$($Parameter.Name) is outside the supported integer range." }
            if ($null -ne $Parameter.Min -and $number -lt [long]$Parameter.Min) { throw "$($Parameter.Name) must be at least $($Parameter.Min)." }
            if ($null -ne $Parameter.Max -and $number -gt [long]$Parameter.Max) { throw "$($Parameter.Name) must be at most $($Parameter.Max)." }
            return $number.ToString([Globalization.CultureInfo]::InvariantCulture)
        }
        'Decimal' {
            if ($Value -notmatch '^-?(?:\d+(?:\.\d+)?|\.\d+)$') { throw "$($Parameter.Name) must be a decimal number using a period as the decimal separator." }
            $number = [decimal]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture)
            if ($null -ne $Parameter.Min -and $number -lt [decimal]$Parameter.Min) { throw "$($Parameter.Name) must be at least $($Parameter.Min)." }
            if ($null -ne $Parameter.Max -and $number -gt [decimal]$Parameter.Max) { throw "$($Parameter.Name) must be at most $($Parameter.Max)." }
            return $number.ToString([Globalization.CultureInfo]::InvariantCulture)
        }
        'Enum' {
            $allowed = @($Parameter.AllowedValues | ForEach-Object { [string]$_ })
            $match = $allowed | Where-Object { $_ -eq $Value } | Select-Object -First 1
            if ($null -eq $match) { throw "$($Parameter.Name) must be one of: $($allowed -join ', ')." }
            return $match
        }
        default {
            if ([string]::IsNullOrWhiteSpace($Value)) { throw "$($Parameter.Name) cannot be empty." }
            return ConvertTo-PcSqlIdentifier $Value
        }
    }
}

function Expand-PcSqlSnippet {
    # Replaces every {{Name}} token with the (escaped) parameter value.
    param([object]$Snippet, [hashtable]$Values)
    $sql = [string]$Snippet.Sql
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $value = if ($Values -and $Values.ContainsKey($name)) { $Values[$name] } else { $parameter.Default }
        $sql = $sql.Replace('{{' + $name + '}}', (ConvertTo-PcSqlParameterValue $parameter $value))
    }
    return $sql
}

function Get-PcSqlSnippetDefaults {
    param([object]$Snippet)
    $values = @{}
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $values[$name] = if ($null -eq $parameter.Default) { '' } else { [string]$parameter.Default }
    }
    return $values
}

function Read-PcSqlSnippetParameters {
    # Prompt for each parameter; an empty answer keeps the current value.
    param([object]$Snippet, [hashtable]$Values)
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $current = if ($Values -and $Values.ContainsKey($name)) { $Values[$name] } else { $parameter.Default }
        if ($null -eq $current) { $current = '' }
        while ($true) {
            $answer = Read-Host ("  {0} [{1}] (Enter: keep)" -f $name, $current)
            if ($null -eq $answer -or $answer.Trim() -eq '') { break }
            $candidate = $answer.Trim()
            try {
                $null = ConvertTo-PcSqlParameterValue $parameter $candidate
                $Values[$name] = $candidate
                break
            }
            catch { Write-Warning $_.Exception.Message }
        }
    }
    return $Values
}

function Get-PcSqlSnippet {
    param([string]$Id)
    Get-PcSqlSnippetRegistry | Where-Object { [string]$_.Id -eq $Id } | Select-Object -First 1
}

function Get-PcSqlSnippetCategories {
    # Ordered category list for the SQL snippets menu.
    @(
        [pscustomobject]@{ Id='users';           Title='Users & Security';       Description='Logins, users, roles, and permissions.' }
        [pscustomobject]@{ Id='health';          Title='Database Health';        Description='Status, integrity, logs, and recovery configuration.' }
        [pscustomobject]@{ Id='performance';     Title='Performance';            Description='Running queries, blocking, and index health.' }
        [pscustomobject]@{ Id='maintenance';     Title='Maintenance';            Description='Backups, Agent jobs, and file growth.' }
        [pscustomobject]@{ Id='connections';     Title='Connections & Sessions'; Description='Active connections, sessions, and transactions.' }
        [pscustomobject]@{ Id='troubleshooting'; Title='Troubleshooting';        Description='Version, configuration, waits, and tempdb.' }
    )
}

function New-PcSqlSnippetMenuItem {
    param([object]$Snippet)
    $typeColor = if ($Snippet.Type -eq 'MODIFICATION') { 'Yellow' } else { 'Green' }
    [pscustomobject]@{
        Id         = [string]$Snippet.Id
        Label      = [string]$Snippet.Title
        Detail     = [string]$Snippet.Description
        SearchText = [string]$Snippet.Description
        Data       = $Snippet
        LabelParts = @(
            [pscustomobject]@{ Text = [string]$Snippet.Title; Color = 'White' }
            [pscustomobject]@{ Text = '  [' + [string]$Snippet.Type + ']'; Color = $typeColor }
        )
    }
}

function Show-PcSqlSnippet {
    param([object]$Snippet, [string]$Breadcrumb)
    $values = Get-PcSqlSnippetDefaults $Snippet
    $notice = ''
    $parameters = @($Snippet.Parameters)
    $hasParams = $parameters.Count -gt 0
    while ($true) {
        $sql = Expand-PcSqlSnippet $Snippet $values
        Clear-PcMenuScreen
        Write-Host (Get-PcMenuHeading $Breadcrumb) -ForegroundColor Cyan
        Write-Host ''
        Write-Host ([string]$Snippet.Title).ToUpperInvariant() -ForegroundColor Cyan
        Write-Host ''
        $typeColor = if ($Snippet.Type -eq 'MODIFICATION') { 'Yellow' } else { 'Green' }
        Write-Host ('Type: ' + $Snippet.Type) -ForegroundColor $typeColor
        if ($Snippet.Scope) { Write-Host ('Scope: ' + $Snippet.Scope) }
        if ($Snippet.Permissions) { Write-Host ('Permissions: ' + $Snippet.Permissions) }
        if ($Snippet.Compatibility) { Write-Host ('Compatibility: ' + $Snippet.Compatibility) }
        if ($Snippet.Cost) { Write-Host ('Cost: ' + $Snippet.Cost) }
        if ($Snippet.Type -eq 'MODIFICATION') {
            Write-Host 'WARNING: This query modifies data or metadata. Review it carefully and run it only against the intended target.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host 'Description:' -ForegroundColor Gray
        Write-Host ([string]$Snippet.Description)
        if ($Snippet.Docs) {
            Write-Host ('Reference: ' + $Snippet.Docs) -ForegroundColor DarkGray
        }
        if ($hasParams) {
            Write-Host ''
            Write-Host 'Parameters:' -ForegroundColor Gray
            $maxName = ($parameters | ForEach-Object { ([string]$_.Name).Length } | Measure-Object -Maximum).Maximum
            foreach ($parameter in $parameters) {
                $name = [string]$parameter.Name
                $value = if ($values.ContainsKey($name)) { [string]$values[$name] } else { '' }
                $displayValue = ConvertTo-PcSqlParameterValue $parameter $value
                Write-Host ('  ' + $name.PadRight($maxName) + ': ' + $displayValue)
            }
        }
        Write-Host ''
        Write-Host 'Generated SQL:' -ForegroundColor Gray
        Write-Host ('-' * 48) -ForegroundColor DarkGray
        foreach ($line in ($sql -split "`r?`n")) { Write-Host $line }
        Write-Host ('-' * 48) -ForegroundColor DarkGray
        Write-Host 'This toolkit never connects to or executes against SQL Server. Review permissions and target before running.' -ForegroundColor DarkGray
        Write-Host ''
        if ($notice) { Write-Warning $notice; $notice = '' }
        $prompt = if ($hasParams) { '[C] Copy query to clipboard | [P] Edit parameters | [B] Back' } else { '[C] Copy query to clipboard | [B] Back' }
        Write-Host $prompt
        $answer = Read-Host 'Choice'
        if ($null -eq $answer) { return }
        $choice = $answer.Trim().ToUpperInvariant()
        if ($choice -eq 'C') {
            try { Set-Clipboard -Value $sql; Write-Host 'Query copied to clipboard.' -ForegroundColor Green }
            catch { Write-Warning ('Could not copy to clipboard: ' + $_.Exception.Message) }
            $null = Read-Host 'Press Enter to continue'
            continue
        }
        if ($hasParams -and $choice -eq 'P') {
            $values = Read-PcSqlSnippetParameters $Snippet $values
            continue
        }
        if ($choice -in @('B', '')) { return }
        $notice = if ($hasParams) { 'Choose C, P, or B.' } else { 'Choose C or B.' }
    }
}

function Start-PcSqlSnippetCategory {
    param([string]$CategoryId)
    $category = Get-PcSqlSnippetCategories | Where-Object Id -eq $CategoryId | Select-Object -First 1
    if (-not $category) { return }
    $snippets = @(Get-PcSqlSnippetRegistry | Where-Object { [string]$_.Category -eq $CategoryId })
    $state = @{}
    $breadcrumb = 'Windows > SQL Server Snippets > ' + $category.Title
    while ($true) {
        $menu = @(foreach ($snippet in $snippets) { New-PcSqlSnippetMenuItem $snippet })
        $choice = Show-PcMenu -Title $breadcrumb -Items $menu -State $state -Description $category.Description -EmptyMessage 'No snippets in this category.'
        if ($choice.Action -eq 'Back') { return }
        if ($choice.Action -eq 'Select') { Show-PcSqlSnippet $choice.Item.Data $breadcrumb }
    }
}

function Start-PcSqlSnippetsMenu {
    $state = @{}
    while ($true) {
        $categories = @(Get-PcSqlSnippetCategories)
        $menu = @(for ($i = 0; $i -lt $categories.Count; $i++) {
            New-PcMenuItem ([string]($i + 1)) $categories[$i].Title 'Menu' $categories[$i].Description
        })
        $answer = Read-PcCategoryMenu 'Windows > SQL Server Snippets' $menu $state 'Copy-only T-SQL snippets by category. Nothing is executed and no connection is made; many queries need VIEW SERVER STATE or db_owner.'
        if ($null -eq $answer -or $answer -in @('0', 'B', 'Back')) { return }
        $index = [int]$answer - 1
        if ($index -ge 0 -and $index -lt $categories.Count) {
            Start-PcSqlSnippetCategory $categories[$index].Id
        }
    }
}

# BEGIN SQL SNIPPET DATA
function Get-PcSqlSnippetRegistry {
    return @(
        [pscustomobject]@{
            Id='orphaned-users'
            Title='Detect orphaned database users'
            Category='users'
            Description='Lists database users whose SID has no matching server login.'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='Database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Lists database users whose SID has no matching server login (orphaned users).
USE {{Database}};
GO

SELECT dp.name                          AS OrphanedUser,
       dp.type_desc                     AS UserType,
       CONVERT(varchar(85), dp.sid, 1)  AS UserSid,
       dp.create_date                   AS Created
FROM   sys.database_principals AS dp
WHERE  dp.type IN ('S', 'U')
  AND  dp.sid IS NOT NULL
  AND  dp.principal_id > 4
  AND  NOT EXISTS
       (
           SELECT 1
           FROM   sys.server_principals AS sp
           WHERE  sp.sid = dp.sid
       )
ORDER  BY dp.name;
GO

'@
        },
        [pscustomobject]@{
            Id='fix-orphaned-users'
            Title='Fix orphaned database user'
            Category='users'
            Description='Remaps an existing database user to a server login.'
            Type='MODIFICATION'
            Scope='Database'
            Permissions='ALTER ANY USER plus access to the target login'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-user-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'},[pscustomobject]@{Name='User';Default='YourUser';Kind='Identifier'},[pscustomobject]@{Name='Login';Default='YourLogin';Kind='Identifier'})
            Sql=@'
-- Remaps an existing database user to an existing server login.
-- Verify that the login and user are the intended pair before running.
USE {{Database}};
GO

ALTER USER {{User}}
WITH LOGIN = {{Login}};
GO

'@
        },
        [pscustomobject]@{
            Id='db-users-logins'
            Title='List database users and associated logins'
            Category='users'
            Description='Database users joined to their matching server login by SID.'
            Type='READ-ONLY'
            Scope='Database and server'
            Permissions='Database metadata visibility and login metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Database users joined to their matching server login by SID.
USE {{Database}};
GO

SELECT dp.name                                AS DatabaseUser,
       dp.type_desc                           AS UserType,
       ISNULL(sp.name, '(no matching login)') AS ServerLogin,
       sp.type_desc                           AS LoginType,
       sp.is_disabled                         AS LoginDisabled
FROM   sys.database_principals AS dp
       LEFT JOIN sys.server_principals AS sp
              ON sp.sid = dp.sid
WHERE  dp.type IN ('S', 'U')
  AND  dp.principal_id > 4
ORDER  BY dp.name;
GO

'@
        },
        [pscustomobject]@{
            Id='db-permissions'
            Title='List explicit database permissions'
            Category='users'
            Description='Explicit database permissions granted or denied to principals; fixed-role permissions are not included.'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='VIEW SECURITY DEFINITION (SQL Server 2022+) or sufficient metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Explicit database permissions granted or denied to principals.
-- Permissions inherited from fixed database roles are not represented here.
USE {{Database}};
GO

SELECT pr.name                AS Principal,
       pr.type_desc           AS PrincipalType,
       perm.state_desc        AS State,
       perm.permission_name   AS Permission,
       perm.class_desc        AS Class,
       ISNULL(OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id), '(database)') AS Securable
FROM   sys.database_permissions AS perm
       JOIN sys.database_principals AS pr
            ON pr.principal_id = perm.grantee_principal_id
ORDER  BY pr.name, perm.permission_name;
GO

'@
        },
        [pscustomobject]@{
            Id='server-roles-members'
            Title='List server roles and members'
            Category='users'
            Description='Fixed and user-defined server roles and their members (server-scoped).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Server principal metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql'
            Parameters=@()
            Sql=@'
-- Fixed and user-defined server roles and their members (server-scoped).
SELECT r.name                 AS ServerRole,
       m.name                 AS Member,
       m.type_desc            AS MemberType,
       m.is_disabled          AS MemberDisabled
FROM   sys.server_role_members AS rm
       JOIN sys.server_principals AS r
            ON r.principal_id = rm.role_principal_id
       JOIN sys.server_principals AS m
            ON m.principal_id = rm.member_principal_id
ORDER  BY r.name, m.name;
GO

'@
        },
        [pscustomobject]@{
            Id='database-status-sizes'
            Title='Database status and sizes'
            Category='health'
            Description='Status, recovery model, compatibility level, and size for every database.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Database and file metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'
            Parameters=@()
            Sql=@'
-- Status, recovery model, compatibility level, and size for every database.
SELECT d.name          AS DatabaseName,
       d.state_desc    AS State,
       d.recovery_model_desc AS RecoveryModel,
       d.compatibility_level AS CompatibilityLevel,
       CAST(SUM(CASE WHEN mf.type = 0 THEN mf.size ELSE 0 END) * 8 / 1024.0 AS decimal(18,2)) AS DataSizeMB,
       CAST(SUM(CASE WHEN mf.type = 1 THEN mf.size ELSE 0 END) * 8 / 1024.0 AS decimal(18,2)) AS LogSizeMB
FROM   sys.databases AS d
       LEFT JOIN sys.master_files AS mf
              ON mf.database_id = d.database_id
GROUP  BY d.name, d.state_desc, d.recovery_model_desc, d.compatibility_level
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='integrity-check'
            Title='Database integrity check'
            Category='health'
            Description='Full allocation and consistency check (DBCC CHECKDB). Resource intensive.'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='Permissions required by DBCC CHECKDB'
            Compatibility='SQL Server 2016-2025'
            Cost='Heavy'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Literal'})
            Sql=@'
-- Full allocation and consistency check. Resource intensive and can run for
-- a long time on large databases. Read-only: no REPAIR option is supplied.
DBCC CHECKDB ({{Database}})
WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO

'@
        },
        [pscustomobject]@{
            Id='txn-log-usage'
            Title='Transaction log usage'
            Category='health'
            Description='Transaction log file size and used space for the current database.'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='VIEW DATABASE STATE or sufficient database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Transaction log file size and used space for the current database.
USE {{Database}};
GO

SELECT name                                            AS LogFileName,
       CAST(size * 8 / 1024.0 AS decimal(18,2))        AS SizeMB,
       CAST(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024.0 AS decimal(18,2)) AS UsedMB,
       CAST(100.0 * FILEPROPERTY(name, 'SpaceUsed') / NULLIF(size, 0) AS decimal(5,2)) AS UsedPercent
FROM   sys.database_files
WHERE  type = 1;
GO

'@
        },
        [pscustomobject]@{
            Id='compatibility-levels'
            Title='Database compatibility levels'
            Category='health'
            Description='Compatibility level of every database with its friendly SQL Server name.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level'
            Parameters=@()
            Sql=@'
-- Compatibility level of every database with its friendly SQL Server name.
SELECT name                       AS DatabaseName,
       compatibility_level        AS CompatibilityLevel,
       CASE compatibility_level
            WHEN 100 THEN 'SQL Server 2008 / 2008 R2'
            WHEN 110 THEN 'SQL Server 2012'
            WHEN 120 THEN 'SQL Server 2014'
            WHEN 130 THEN 'SQL Server 2016'
            WHEN 140 THEN 'SQL Server 2017'
            WHEN 150 THEN 'SQL Server 2019'
            WHEN 160 THEN 'SQL Server 2022'
            WHEN 170 THEN 'SQL Server 2025'
            ELSE 'Unknown / custom'
       END                        AS CompatibilityLevelName
FROM   sys.databases
ORDER  BY name;
GO

'@
        },
        [pscustomobject]@{
            Id='recovery-models'
            Title='Recovery models'
            Category='health'
            Description='Recovery model and current log reuse wait for every database.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server'
            Parameters=@()
            Sql=@'
-- Recovery model and current log reuse wait for every database.
SELECT d.name                AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       d.log_reuse_wait_desc AS LogReuseWait
FROM   sys.databases AS d
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='database-free-space'
            Title='Database file and volume free space'
            Category='health'
            Description='File allocation, unallocated space, growth settings, and hosting-volume capacity for one database.'
            Type='READ-ONLY'
            Scope='Database and host volume'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-volume-stats-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- File allocation, unallocated space, growth settings, and volume capacity.
USE {{Database}};
GO

SELECT DB_NAME()                                        AS DatabaseName,
       df.file_id                                       AS FileId,
       df.name                                          AS LogicalFileName,
       df.type_desc                                     AS FileType,
       df.physical_name                                 AS PhysicalName,
       CAST(df.size * 8 / 1024.0 AS decimal(18,2))      AS FileSizeMB,
       CAST(FILEPROPERTY(df.name, 'SpaceUsed') * 8 / 1024.0 AS decimal(18,2)) AS UsedMB,
       CAST((df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8 / 1024.0 AS decimal(18,2)) AS UnallocatedMB,
       CASE WHEN df.is_percent_growth = 1
            THEN CONVERT(varchar(20), df.growth) + '%'
            ELSE CONVERT(varchar(20), df.growth * 8 / 1024) + ' MB'
       END                                              AS GrowthSetting,
       vs.volume_mount_point                            AS VolumeMountPoint,
       CAST(vs.total_bytes / 1048576.0 AS decimal(18,2)) AS VolumeSizeMB,
       CAST(vs.available_bytes / 1048576.0 AS decimal(18,2)) AS VolumeFreeMB
FROM   sys.database_files AS df
       CROSS APPLY sys.dm_os_volume_stats(DB_ID(), df.file_id) AS vs
ORDER  BY df.type, df.file_id;
GO

'@
        },
        [pscustomobject]@{
            Id='currently-executing'
            Title='Currently executing queries'
            Category='performance'
            Description='All requests currently executing on the instance (server-scoped).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@()
            Sql=@'
-- All requests currently executing on the instance (server-scoped).
SELECT r.session_id                                    AS SessionId,
       r.status                                        AS Status,
       r.command                                       AS Command,
       r.blocking_session_id                           AS BlockingSession,
       DB_NAME(r.database_id)                          AS DatabaseName,
       r.cpu_time                                      AS CpuMs,
       r.total_elapsed_time                            AS ElapsedMs,
       s.login_name                                    AS LoginName,
       s.host_name                                     AS HostName,
       s.program_name                                  AS ProgramName,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                 ((CASE r.statement_end_offset
                       WHEN -1 THEN DATALENGTH(t.text)
                       ELSE r.statement_end_offset
                   END - r.statement_start_offset) / 2) + 1) AS QueryText
FROM   sys.dm_exec_requests AS r
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
       CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE  r.session_id <> @@SPID
ORDER  BY r.total_elapsed_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='blocking-sessions'
            Title='Blocking sessions'
            Category='performance'
            Description='Requests blocked by another session, with both sides logins and hosts.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@()
            Sql=@'
-- Requests blocked by another session, including sleeping head blockers.
SELECT blocked.session_id                  AS BlockedSession,
       blocked.blocking_session_id         AS BlockingSession,
       blocked.wait_type                   AS WaitType,
       blocked.wait_time                   AS WaitMs,
       blocked.wait_resource               AS WaitResource,
       DB_NAME(blocked.database_id)        AS DatabaseName,
       blocked_sess.login_name             AS BlockedLogin,
       blocking_sess.login_name            AS BlockingLogin,
       blocked_sess.host_name              AS BlockedHost,
       blocking_sess.host_name             AS BlockingHost,
       blocking_sess.status                AS BlockingSessionStatus,
       blocking_sess.open_transaction_count AS BlockingOpenTransactions,
       blocking_sess.last_request_end_time AS BlockingLastRequestEnd,
       input_buffer.event_info             AS BlockingLastCommand
FROM   sys.dm_exec_requests AS blocked
       JOIN sys.dm_exec_sessions AS blocked_sess
            ON blocked_sess.session_id = blocked.session_id
       JOIN sys.dm_exec_sessions AS blocking_sess
            ON blocking_sess.session_id = blocked.blocking_session_id
       OUTER APPLY sys.dm_exec_input_buffer(blocked.blocking_session_id, NULL) AS input_buffer
WHERE  blocked.blocking_session_id > 0
ORDER  BY blocked.wait_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='blocking-chain'
            Title='Blocking chains and head blockers'
            Category='performance'
            Description='Expands blocking chains from each head blocker, including sleeping sessions.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/understand-resolve-blocking'
            Parameters=@()
            Sql=@'
-- Expands blocking chains from each head blocker, including sleeping sessions.
WITH waits AS
(
    SELECT session_id,
           blocking_session_id,
           wait_type,
           wait_time,
           wait_resource,
           database_id
    FROM   sys.dm_exec_requests
    WHERE  blocking_session_id > 0
),
heads AS
(
    SELECT DISTINCT w.blocking_session_id AS HeadBlocker
    FROM   waits AS w
    WHERE  NOT EXISTS
           (
               SELECT 1
               FROM   waits AS parent
               WHERE  parent.session_id = w.blocking_session_id
           )
),
chain AS
(
    SELECT h.HeadBlocker,
           h.HeadBlocker AS SessionId,
           CAST(NULL AS smallint) AS BlockedBy,
           0 AS Depth,
           CAST('>' + CONVERT(varchar(11), h.HeadBlocker) + '>' AS varchar(max)) AS Visited
    FROM   heads AS h

    UNION ALL

    SELECT c.HeadBlocker,
           w.session_id,
           w.blocking_session_id,
           c.Depth + 1,
           CAST(c.Visited + CONVERT(varchar(11), w.session_id) + '>' AS varchar(max))
    FROM   chain AS c
           JOIN waits AS w
                ON w.blocking_session_id = c.SessionId
    WHERE  c.Visited NOT LIKE '%>' + CONVERT(varchar(11), w.session_id) + '>%'
)
SELECT c.HeadBlocker,
       c.Depth,
       c.SessionId,
       c.BlockedBy,
       s.status                   AS SessionStatus,
       s.open_transaction_count  AS OpenTransactions,
       s.login_name              AS LoginName,
       s.host_name               AS HostName,
       s.program_name            AS ProgramName,
       DB_NAME(w.database_id)    AS DatabaseName,
       w.wait_type               AS WaitType,
       w.wait_time               AS WaitMs,
       w.wait_resource           AS WaitResource,
       input_buffer.event_info   AS LastCommand
FROM   chain AS c
       LEFT JOIN waits AS w ON w.session_id = c.SessionId
       LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = c.SessionId
       OUTER APPLY sys.dm_exec_input_buffer(c.SessionId, NULL) AS input_buffer
ORDER  BY c.HeadBlocker, c.Depth, c.SessionId
OPTION (MAXRECURSION 100);
GO

'@
        },
        [pscustomobject]@{
            Id='long-running-queries'
            Title='Long-running queries'
            Category='performance'
            Description='Queries running longer than the configured threshold (default 5 minutes).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@([pscustomobject]@{Name='ThresholdMinutes';Default='5';Kind='Integer';Min='1';Max='10080'})
            Sql=@'
-- Queries running longer than the configured threshold (default 5 minutes).
SELECT r.session_id                   AS SessionId,
       s.login_name                   AS LoginName,
       DB_NAME(r.database_id)         AS DatabaseName,
       r.total_elapsed_time           AS ElapsedMs,
       r.cpu_time                     AS CpuMs,
       r.logical_reads                AS LogicalReads,
       r.status                       AS Status,
       r.command                      AS Command,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                 ((CASE r.statement_end_offset
                       WHEN -1 THEN DATALENGTH(t.text)
                       ELSE r.statement_end_offset
                   END - r.statement_start_offset) / 2) + 1) AS QueryText
FROM   sys.dm_exec_requests AS r
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
       CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE  r.session_id <> @@SPID
  AND  r.total_elapsed_time > {{ThresholdMinutes}} * 60000
ORDER  BY r.total_elapsed_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='index-fragmentation'
            Title='Index fragmentation'
            Category='performance'
            Description='Index fragmentation above 5% with at least 100 pages (LIMITED scan).'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='VIEW DATABASE STATE or sufficient database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Moderate'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Index fragmentation above 5% with at least 100 pages (LIMITED scan).
USE {{Database}};
GO

SELECT OBJECT_NAME(ips.object_id)               AS TableName,
       i.name                                   AS IndexName,
       ips.index_type_desc                      AS IndexType,
       ips.avg_fragmentation_in_percent         AS FragmentationPercent,
       ips.page_count                           AS PageCount
FROM   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
       JOIN sys.indexes AS i
            ON i.object_id = ips.object_id
           AND i.index_id = ips.index_id
WHERE  ips.avg_fragmentation_in_percent > 5
  AND  ips.page_count > 100
ORDER  BY ips.avg_fragmentation_in_percent DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='missing-indexes'
            Title='Missing index recommendations'
            Category='performance'
            Description='Missing index suggestions ranked by estimated query-cost impact.'
            Type='READ-ONLY'
            Scope='Database'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Missing index suggestions ranked by estimated query-cost impact.
USE {{Database}};
GO

SELECT migs.avg_total_user_cost                       AS AvgQueryCost,
       migs.avg_user_impact                           AS AvgImpactPercent,
       migs.user_seeks + migs.user_scans              AS Reads,
       CONVERT(decimal(28,1), migs.avg_total_user_cost * migs.avg_user_impact *
               (migs.user_seeks + migs.user_scans))   AS ImprovementMeasure,
       migs.last_user_seek                             AS LastUserSeek,
       mid.statement                                  AS [Table],
       mid.equality_columns                           AS EqualityColumns,
       mid.inequality_columns                         AS InequalityColumns,
       mid.included_columns                           AS IncludedColumns
FROM   sys.dm_db_missing_index_details AS mid
       JOIN sys.dm_db_missing_index_groups AS mig
            ON mig.index_handle = mid.index_handle
       JOIN sys.dm_db_missing_index_group_stats AS migs
            ON migs.group_handle = mig.index_group_handle
WHERE  mid.database_id = DB_ID()
ORDER  BY migs.avg_total_user_cost * migs.avg_user_impact *
          (migs.user_seeks + migs.user_scans) DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='backup-history'
            Title='Backup history'
            Category='maintenance'
            Description='Backup history for the last N days (default 7) from msdb.'
            Type='READ-ONLY'
            Scope='Server / msdb'
            Permissions='Read access to msdb backup and SQL Agent history'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'
            Parameters=@([pscustomobject]@{Name='Days';Default='7';Kind='Integer';Min='1';Max='3650'})
            Sql=@'
-- Backup history for the last N days (default 7) from msdb.
SELECT s.database_name                                  AS DatabaseName,
       s.backup_start_date                              AS StartTime,
       s.backup_finish_date                             AS FinishTime,
       CASE s.type
            WHEN 'D' THEN 'Full'
            WHEN 'I' THEN 'Differential'
            WHEN 'L' THEN 'Log'
            WHEN 'F' THEN 'File / Filegroup'
            ELSE s.type
       END                                              AS BackupType,
       CAST(s.backup_size / 1048576.0 AS decimal(18,2)) AS SizeMB,
       s.user_name                                      AS UserName,
       mf.physical_device_name                          AS Destination
FROM   msdb.dbo.backupset AS s
       JOIN msdb.dbo.backupmediafamily AS mf
            ON mf.media_set_id = s.media_set_id
WHERE  s.backup_finish_date >= DATEADD(DAY, -{{Days}}, GETDATE())
ORDER  BY s.backup_finish_date DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='last-successful-backups'
            Title='Last successful backups'
            Category='maintenance'
            Description='Most recent successful full, differential, and log backup per database.'
            Type='READ-ONLY'
            Scope='Server / msdb'
            Permissions='Read access to msdb backup and SQL Agent history'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'
            Parameters=@()
            Sql=@'
-- Most recent successful full, differential, and log backup per database.
SELECT d.name          AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END) AS LastFullBackup,
       MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END) AS LastDifferentialBackup,
       MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END) AS LastLogBackup
FROM   sys.databases AS d
       LEFT JOIN msdb.dbo.backupset AS b
            ON b.database_name = d.name
GROUP  BY d.name, d.recovery_model_desc
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='agent-job-failures'
            Title='SQL Server Agent job failures'
            Category='maintenance'
            Description='Recent SQL Server Agent job failures from msdb history.'
            Type='READ-ONLY'
            Scope='Server / msdb'
            Permissions='Read access to msdb backup and SQL Agent history'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql'
            Parameters=@()
            Sql=@'
-- Recent SQL Server Agent job failures from msdb history.
-- run_date is YYYYMMDD and run_time is HHMMSS integers.
SELECT j.name                        AS JobName,
       j.enabled                     AS JobEnabled,
       h.run_date                    AS RunDate,
       h.run_time                    AS RunTime,
       h.run_status                  AS RunStatus,
       h.message                     AS Message
FROM   msdb.dbo.sysjobs AS j
       JOIN msdb.dbo.sysjobhistory AS h
            ON h.job_id = j.job_id
WHERE  h.run_status = 0
  AND  h.step_id = 0
ORDER  BY h.run_date DESC, h.run_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='file-growth-config'
            Title='Database file growth configuration'
            Category='maintenance'
            Description='Per-file size, growth setting, and max size for every database.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Database and file metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql'
            Parameters=@()
            Sql=@'
-- Per-file size, growth setting, and max size for every database.
SELECT d.name                                        AS DatabaseName,
       mf.name                                       AS FileName,
       mf.type_desc                                  AS FileType,
       CAST(mf.size * 8 / 1024.0 AS decimal(18,2))   AS SizeMB,
       CASE WHEN mf.is_percent_growth = 1
            THEN CAST(mf.growth AS varchar(10)) + '%'
            ELSE CAST(mf.growth * 8 / 1024 AS varchar(20)) + ' MB'
       END                                           AS GrowthSetting,
       CASE WHEN mf.max_size = -1
            THEN 'Unlimited'
            ELSE CAST(mf.max_size * 8 / 1024 AS varchar(20)) + ' MB'
       END                                           AS MaxSizeMB
FROM   sys.master_files AS mf
       JOIN sys.databases AS d
            ON d.database_id = mf.database_id
ORDER  BY d.name, mf.name;
GO

'@
        },
        [pscustomobject]@{
            Id='backup-compliance'
            Title='Backup threshold compliance'
            Category='maintenance'
            Description='Flags online databases whose latest full, differential, or log backup exceeds configurable thresholds.'
            Type='READ-ONLY'
            Scope='Server / msdb'
            Permissions='Read access to msdb backup and SQL Agent history'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-overview-sql-server'
            Parameters=@([pscustomobject]@{Name='FullDays';Default='7';Kind='Integer';Min='1';Max='3650'},[pscustomobject]@{Name='DifferentialDays';Default='1';Kind='Integer';Min='1';Max='3650'},[pscustomobject]@{Name='LogMinutes';Default='60';Kind='Integer';Min='1';Max='525600'})
            Sql=@'
-- Backup recency compared with configurable operational thresholds.
-- Thresholds are reference values; align them with the organization's RPO policy.
WITH latest AS
(
    SELECT database_name,
           MAX(CASE WHEN type = 'D' AND is_copy_only = 0 THEN backup_finish_date END) AS LastFull,
           MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDifferential,
           MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLog
    FROM   msdb.dbo.backupset
    GROUP  BY database_name
)
SELECT d.name                                          AS DatabaseName,
       d.recovery_model_desc                           AS RecoveryModel,
       b.LastFull,
       CASE WHEN b.LastFull >= DATEADD(DAY, -{{FullDays}}, GETDATE())
            THEN 'OK' ELSE 'OVERDUE' END               AS FullBackupStatus,
       b.LastDifferential,
       CASE WHEN b.LastDifferential >= DATEADD(DAY, -{{DifferentialDays}}, GETDATE())
            THEN 'OK' ELSE 'OVERDUE' END               AS DifferentialBackupStatus,
       b.LastLog,
       CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN 'N/A (SIMPLE)'
            WHEN b.LastLog >= DATEADD(MINUTE, -{{LogMinutes}}, GETDATE()) THEN 'OK'
            ELSE 'OVERDUE' END                         AS LogBackupStatus
FROM   sys.databases AS d
       LEFT JOIN latest AS b ON b.database_name = d.name
WHERE  d.database_id <> 2
  AND  d.state = 0
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='active-connections'
            Title='Active connections'
            Category='connections'
            Description='Active user connections to the instance (server-scoped).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- Active user connections to the instance (server-scoped).
SELECT s.session_id                AS SessionId,
       s.login_name                AS LoginName,
       s.host_name                 AS HostName,
       s.program_name              AS ProgramName,
       DB_NAME(s.database_id)      AS DatabaseName,
       s.status                    AS Status,
       s.login_time                AS LoginTime,
       s.last_request_end_time     AS LastActivity
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='sessions-by-database'
            Title='Sessions grouped by database'
            Category='connections'
            Description='Count of sessions per database, split by running and sleeping state.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- Count of sessions per database, split by running and sleeping state.
SELECT DB_NAME(s.database_id)    AS DatabaseName,
       COUNT(*)                  AS SessionCount,
       SUM(CASE WHEN s.status = 'running'  THEN 1 ELSE 0 END) AS Running,
       SUM(CASE WHEN s.status = 'sleeping' THEN 1 ELSE 0 END) AS Sleeping
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
GROUP  BY s.database_id
ORDER  BY SessionCount DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='sleeping-sessions'
            Title='Sleeping sessions'
            Category='connections'
            Description='User sessions that are sleeping, ordered by oldest activity first.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- User sessions that are sleeping, ordered by oldest activity first.
SELECT s.session_id                       AS SessionId,
       s.login_name                       AS LoginName,
       s.host_name                        AS HostName,
       s.program_name                     AS ProgramName,
       DB_NAME(s.database_id)             AS DatabaseName,
       s.last_request_end_time            AS LastActivity,
       DATEDIFF(MINUTE, s.last_request_end_time, GETDATE()) AS IdleMinutes
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.status = 'sleeping'
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time ASC;
GO

'@
        },
        [pscustomobject]@{
            Id='open-transactions'
            Title='Open transactions'
            Category='connections'
            Description='Open transactions, their owning session, age, and type (server-scoped).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'
            Parameters=@()
            Sql=@'
-- Open transactions, their owning session, age, and type (server-scoped).
SELECT at.transaction_id                           AS TransactionId,
       st.session_id                               AS SessionId,
       s.login_name                                AS LoginName,
       DB_NAME(dt.database_id)                     AS DatabaseName,
       at.name                                     AS TransactionName,
       at.transaction_begin_time                   AS BeginTime,
       DATEDIFF(SECOND, at.transaction_begin_time, GETDATE()) AS AgeSeconds,
       CASE at.transaction_type
            WHEN 1 THEN 'Read/Write'
            WHEN 2 THEN 'Read-Only'
            WHEN 3 THEN 'System'
            WHEN 4 THEN 'Distributed'
            ELSE CAST(at.transaction_type AS varchar(10))
       END                                         AS TransactionType
FROM   sys.dm_tran_active_transactions AS at
       JOIN sys.dm_tran_session_transactions AS st
            ON st.transaction_id = at.transaction_id
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = st.session_id
       LEFT JOIN sys.dm_tran_database_transactions AS dt
            ON dt.transaction_id = at.transaction_id
ORDER  BY at.transaction_begin_time ASC;
GO

'@
        },
        [pscustomobject]@{
            Id='long-running-transactions'
            Title='Long-running open transactions'
            Category='connections'
            Description='Open user transactions older than a configurable threshold, with session and last-command context.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'
            Parameters=@([pscustomobject]@{Name='ThresholdMinutes';Default='5';Kind='Integer';Min='1';Max='10080'})
            Sql=@'
-- Open user transactions older than the configured threshold.
SELECT st.session_id                                  AS SessionId,
       s.login_name                                   AS LoginName,
       s.host_name                                    AS HostName,
       s.program_name                                 AS ProgramName,
       s.status                                       AS SessionStatus,
       s.open_transaction_count                       AS SessionOpenTransactions,
       at.transaction_id                              AS TransactionId,
       at.name                                        AS TransactionName,
       at.transaction_begin_time                      AS BeginTime,
       DATEDIFF(MINUTE, at.transaction_begin_time, GETDATE()) AS AgeMinutes,
       r.status                                       AS RequestStatus,
       r.command                                      AS RequestCommand,
       input_buffer.event_info                        AS LastCommand
FROM   sys.dm_tran_active_transactions AS at
       JOIN sys.dm_tran_session_transactions AS st
            ON st.transaction_id = at.transaction_id
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = st.session_id
       LEFT JOIN sys.dm_exec_requests AS r
            ON r.session_id = st.session_id
       OUTER APPLY sys.dm_exec_input_buffer(st.session_id, NULL) AS input_buffer
WHERE  s.is_user_process = 1
  AND  at.transaction_begin_time <= DATEADD(MINUTE, -{{ThresholdMinutes}}, GETDATE())
ORDER  BY at.transaction_begin_time ASC;
GO

'@
        },
        [pscustomobject]@{
            Id='version-edition'
            Title='SQL Server version and edition'
            Category='troubleshooting'
            Description='SQL Server version, edition, and high-availability properties.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Public server metadata access'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql'
            Parameters=@()
            Sql=@'
-- SQL Server version, edition, and high-availability properties.
SELECT SERVERPROPERTY('ServerName')              AS ServerName,
       SERVERPROPERTY('InstanceName')            AS InstanceName,
       SERVERPROPERTY('ProductVersion')          AS ProductVersion,
       SERVERPROPERTY('ProductLevel')            AS ProductLevel,
       SERVERPROPERTY('ProductUpdateLevel')      AS ProductUpdateLevel,
       SERVERPROPERTY('ProductBuildType')        AS ProductBuildType,
       SERVERPROPERTY('Edition')                 AS Edition,
       SERVERPROPERTY('EngineEdition')           AS EngineEdition,
       SERVERPROPERTY('IsClustered')             AS IsClustered,
       SERVERPROPERTY('IsHadrEnabled')           AS IsHadrEnabled;
GO

'@
        },
        [pscustomobject]@{
            Id='server-configuration'
            Title='Server configuration'
            Category='troubleshooting'
            Description='All sp_configure settings with their current, minimum, and maximum values.'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Server configuration metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql'
            Parameters=@()
            Sql=@'
-- All sp_configure settings with their current, minimum, and maximum values.
SELECT name                AS ConfigurationName,
       value_in_use        AS ValueInUse,
       minimum             AS Minimum,
       maximum             AS Maximum,
       description         AS Description,
       is_dynamic          AS IsDynamic,
       is_advanced         AS IsAdvanced
FROM   sys.configurations
ORDER  BY name;
GO

'@
        },
        [pscustomobject]@{
            Id='wait-stats'
            Title='Wait statistics'
            Category='troubleshooting'
            Description='Cumulative wait statistics since the instance started (benign waits excluded).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql'
            Parameters=@()
            Sql=@'
-- Cumulative wait statistics since the instance started (benign waits excluded).
SELECT wait_type                                          AS WaitType,
       waiting_tasks_count                                AS WaitingTasks,
       wait_time_ms                                       AS WaitTimeMs,
       max_wait_time_ms                                   AS MaxWaitTimeMs,
       signal_wait_time_ms                                AS SignalWaitTimeMs,
       CAST(100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER (), 0) AS decimal(5,2)) AS PercentOfWaits
FROM   sys.dm_os_wait_stats
WHERE  wait_type NOT IN (
           'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
           'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE','CHKPT',
           'CLR_AUTO_EVENT','CLR_MANUAL_EVENT','CLR_SEMAPHORE','DBMIRROR_DBM_EVENT',
           'DBMIRROR_EVENTS_QUEUE','DBMIRROR_WORKER_QUEUE','DBMIRRORING_CMD',
           'DIRTY_PAGE_POLL','DISPATCHER_QUEUE_SEMAPHORE','EXECSYNC','FSAGENT',
           'FT_IFTS_SCHEDULER_IDLE_WAIT','FT_IFTSHC_MUTEX','HADR_CLUSAPI_CALL',
           'HADR_FILESTREAM_IOMGR_IOCOMPLETION','HADR_LOGCAPTURE_WAIT',
           'HADR_NOTIFICATION_DEQUEUE','HADR_TIMER_TASK','HADR_WORK_QUEUE',
           'KSOURCE_WAKEUP','LAZYWRITER_SLEEP','LOGMGR_QUEUE','MEMORY_ALLOCATION_EXT',
           'ONDEMAND_TASK_QUEUE','PREEMPTIVE_OS_LIBRARYOPS','PREEMPTIVE_OS_COMOPS',
           'PREEMPTIVE_OS_CRYPTOPS','PREEMPTIVE_OS_PIPEOPS',
           'PREEMPTIVE_OS_AUTHENTICATIONOPS','PREEMPTIVE_OS_GENERICOPS',
           'PREEMPTIVE_OS_VERIFYTRUST','PREEMPTIVE_OS_FILEOPS',
           'PREEMPTIVE_OS_DEVICEOPS','PREEMPTIVE_OS_QUERYREGISTRY',
           'PREEMPTIVE_OS_WRITEFILE','REQUEST_FOR_DEADLOCK_SEARCH','RESOURCE_QUEUE',
           'SERVER_IDLE_CHECK','SLEEP_BPOOL_FLUSH','SLEEP_DBSTARTUP',
           'SLEEP_DCOMSTARTUP','SLEEP_MASTERMDREADY','SLEEP_MASTERUPGRADED',
           'SLEEP_MSDBSTARTUP','SLEEP_SYSTEMTASK','SLEEP_TASK',
           'SLEEP_TEMPDBSTARTUP','SP_SERVER_DIAGNOSTICS_SLEEP',
           'SQLTRACE_BUFFER_FLUSH','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
           'SQLTRACE_WAIT_ENTRIES','WAIT_FOR_RESULTS','WAITFOR',
           'WAITFOR_TASKSHUTDOWN','WAIT_XTP_RECOVERY','WAIT_XTP_HOST_WAIT',
           'WAIT_XTP_OFFLINE_CKPT_NEW_LOG','WAIT_XTP_CKPT_CLOSE',
           'XE_DISPATCHER_JOIN','XE_DISPATCHER_WAIT','XE_TIMER_EVENT'
       )
ORDER  BY wait_time_ms DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='tempdb-usage'
            Title='TempDB usage'
            Category='troubleshooting'
            Description='Net completed-task and active-task tempdb allocation by session, ordered by the largest consumers.'
            Type='READ-ONLY'
            Scope='Server / tempdb'
            Permissions='VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-session-space-usage-transact-sql'
            Parameters=@()
            Sql=@'
-- Net tempdb allocation by session. Session counters cover completed tasks;
-- task counters add allocations belonging to requests that are still active.
WITH completed AS
(
    SELECT session_id,
           (user_objects_alloc_page_count - user_objects_dealloc_page_count) +
           (internal_objects_alloc_page_count - internal_objects_dealloc_page_count) AS NetPages
    FROM   sys.dm_db_session_space_usage
    WHERE  database_id = 2
),
active AS
(
    SELECT session_id,
           SUM((user_objects_alloc_page_count - user_objects_dealloc_page_count) +
               (internal_objects_alloc_page_count - internal_objects_dealloc_page_count)) AS NetPages
    FROM   sys.dm_db_task_space_usage
    WHERE  database_id = 2
    GROUP  BY session_id
)
SELECT s.session_id                                      AS SessionId,
       s.login_name                                      AS LoginName,
       s.host_name                                       AS HostName,
       s.program_name                                    AS ProgramName,
       COALESCE(c.NetPages, 0)                           AS CompletedTaskNetPages,
       COALESCE(a.NetPages, 0)                           AS ActiveTaskNetPages,
       CAST((COALESCE(c.NetPages, 0) + COALESCE(a.NetPages, 0)) * 8 / 1024.0 AS decimal(18,2)) AS NetAllocatedMB
FROM   sys.dm_exec_sessions AS s
       LEFT JOIN completed AS c ON c.session_id = s.session_id
       LEFT JOIN active AS a ON a.session_id = s.session_id
WHERE  COALESCE(c.NetPages, 0) + COALESCE(a.NetPages, 0) <> 0
ORDER  BY NetAllocatedMB DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='recovery-pending'
            Title='Databases in RECOVERY_PENDING state'
            Category='troubleshooting'
            Description='Databases stuck in RECOVERY_PENDING state (state = 3).'
            Type='READ-ONLY'
            Scope='Server'
            Permissions='Database metadata visibility'
            Compatibility='SQL Server 2016-2025'
            Cost='Light'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'
            Parameters=@()
            Sql=@'
-- Databases stuck in RECOVERY_PENDING state (state = 3).
SELECT name                       AS DatabaseName,
       state_desc                 AS State,
       recovery_model_desc        AS RecoveryModel,
       is_in_standby              AS IsInStandby
FROM   sys.databases
WHERE  state = 3
ORDER  BY name;
GO

'@
        }
    )
}
# END SQL SNIPPET DATA
# END SQL SNIPPETS

function Get-PcDefenderStatus {
    $status=Get-MpComputerStatus -ErrorAction Stop
    [pscustomobject]@{
        Test='Microsoft Defender status';Status=$(if($status.AntivirusEnabled -and $status.RealTimeProtectionEnabled){'PASS'}else{'WARN'})
        AntivirusEnabled=$status.AntivirusEnabled;AntispywareEnabled=$status.AntispywareEnabled;AMServiceEnabled=$status.AMServiceEnabled
        RealTimeProtectionEnabled=$status.RealTimeProtectionEnabled;BehaviorMonitorEnabled=$status.BehaviorMonitorEnabled;IoavProtectionEnabled=$status.IoavProtectionEnabled
        NetworkInspectionEnabled=$status.NISEnabled;TamperProtected=$status.IsTamperProtected;EngineVersion=$status.AMEngineVersion
        ProductVersion=$status.AMProductVersion;AntivirusSignatureVersion=$status.AntivirusSignatureVersion;AntivirusSignatureUpdated=$status.AntivirusSignatureLastUpdated
        QuickScanAgeDays=$status.QuickScanAge;QuickScanEnd=$status.QuickScanEndTime;FullScanAgeDays=$status.FullScanAge;FullScanEnd=$status.FullScanEndTime
        Detail='Status reported by the local Defender provider. Another registered antivirus product can legitimately place Defender in passive mode.'
    }
}

function Get-PcDefenderDetections {
    $detections=@(Get-MpThreatDetection -ErrorAction Stop | Sort-Object InitialDetectionTime -Descending | Select-Object -First 50)
    if(-not $detections.Count){return [pscustomobject]@{Test='Defender detections';Status='PASS';Detail='No active or past detections were returned by Microsoft Defender.'}}
    foreach($detection in $detections){
        [pscustomobject]@{Test='Defender detection';Status='WARN';InitialDetection=$detection.InitialDetectionTime;LastThreatStatusChange=$detection.LastThreatStatusChangeTime;ThreatId=$detection.ThreatID;ThreatStatusId=$detection.ThreatStatusID;ActionSuccess=$detection.ActionSuccess;Resources=@($detection.Resources) -join '; ';Detail='Detection history does not by itself prove that a threat remains active.'}
    }
}

function Get-PcAntivirusProviders {
    $products=@(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)
    if(-not $products.Count){return [pscustomobject]@{Test='Registered antivirus';Status='WARN';Detail='Windows Security Center reported no antivirus products. This namespace may be unavailable on Windows Server.'}}
    foreach($product in $products){[pscustomobject]@{Test='Registered antivirus';Status='INFO';Name=$product.displayName;ProductState=('0x{0:X6}' -f [int]$product.productState);ProductPath=$product.pathToSignedProductExe;ReportingPath=$product.pathToSignedReportingExe;Timestamp=$product.timestamp;Detail='ProductState is provider-defined Security Center metadata; use the product status command for authoritative protection state.'}}
}

function Get-PcPlatformSecurity {
    try{
        $tpm=Get-Tpm -ErrorAction Stop
        [pscustomobject]@{Test='TPM';Status=$(if($tpm.TpmPresent -and $tpm.TpmReady){'PASS'}else{'WARN'});Present=$tpm.TpmPresent;Ready=$tpm.TpmReady;Enabled=$tpm.TpmEnabled;Activated=$tpm.TpmActivated;Owned=$tpm.TpmOwned;ManufacturerVersion=$tpm.ManufacturerVersion;Detail='TPM state only; no ownership, provisioning, or clearing operation is performed.'}
    }catch{[pscustomobject]@{Test='TPM';Status='WARN';Detail=$_.Exception.Message}}
    try{
        $enabled=Confirm-SecureBootUEFI -ErrorAction Stop
        [pscustomobject]@{Test='Secure Boot';Status=$(if($enabled){'PASS'}else{'WARN'});Enabled=[bool]$enabled;Detail='Firmware Secure Boot state; no firmware setting is changed.'}
    }catch{[pscustomobject]@{Test='Secure Boot';Status='WARN';Detail=$_.Exception.Message}}
}

function Get-PcDeviceGuardStatus {
    $guard=Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
    $vbs=@('Disabled','Enabled but not running','Running')
    $vbsCode=[int]$guard.VirtualizationBasedSecurityStatus
    $vbsLabel=if($vbsCode -ge 0 -and $vbsCode -lt $vbs.Count){$vbs[$vbsCode]}else{'Unknown'}
    [pscustomobject]@{Test='VBS / Device Guard';Status=$(if([int]$guard.VirtualizationBasedSecurityStatus -eq 2){'PASS'}else{'REVIEW'});VirtualizationBasedSecurity=$vbsLabel;SecurityServicesConfigured=@($guard.SecurityServicesConfigured) -join ',';SecurityServicesRunning=@($guard.SecurityServicesRunning) -join ',';CodeIntegrityPolicyEnforcementStatus=$guard.CodeIntegrityPolicyEnforcementStatus;UserModeCodeIntegrityPolicyEnforcementStatus=$guard.UserModeCodeIntegrityPolicyEnforcementStatus;Detail='Numeric service identifiers are preserved because configured protections vary by Windows edition and policy.'}
}

function Get-PcBitLockerStatus {
    foreach($volume in @(Get-BitLockerVolume -ErrorAction Stop)){
        [pscustomobject]@{Test='BitLocker';Status=$(if([string]$volume.ProtectionStatus -eq 'On'){'PASS'}else{'REVIEW'});MountPoint=$volume.MountPoint;VolumeType=$volume.VolumeType;VolumeStatus=$volume.VolumeStatus;ProtectionStatus=$volume.ProtectionStatus;EncryptionMethod=$volume.EncryptionMethod;EncryptionPercentage=$volume.EncryptionPercentage;LockStatus=$volume.LockStatus;AutoUnlockEnabled=$volume.AutoUnlockEnabled;Detail='Recovery keys and key-protector material are not displayed.'}
    }
}

function Get-PcAuditPolicy { Invoke-AdNative 'auditpol.exe' @('/get','/category:*') }

function Get-PcWindowsUpdateServices {
    $names=@('wuauserv','UsoSvc','WaaSMedicSvc','BITS','CryptSvc')
    $services=@(Get-Service -Name $names -ErrorAction SilentlyContinue)
    foreach($name in $names){
        $service=$services | Where-Object Name -eq $name | Select-Object -First 1
        if($service){[pscustomobject]@{Test='Windows Update service';Status=$(if($service.Status -eq 'Running' -or $service.StartType -in @('Manual','Automatic')){'PASS'}else{'REVIEW'});Name=$service.Name;DisplayName=$service.DisplayName;ServiceStatus=$service.Status;StartType=$service.StartType;Detail='Trigger-start services can legitimately be stopped when idle.'}}
        else{[pscustomobject]@{Test='Windows Update service';Status='UNAVAILABLE';Name=$name;Detail='Service was not found on this Windows edition.'}}
    }
}

function Get-PcWindowsUpdatePolicy {
    $paths=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate','HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU')
    $rows=New-Object 'Collections.Generic.List[object]'
    foreach($path in $paths){
        $item=Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
        if(-not $item){continue}
        foreach($property in $item.PSObject.Properties | Where-Object {$_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'}){
            $rows.Add([pscustomobject]@{Test='Windows Update policy';Status='INFO';Path=$path;Name=$property.Name;Value=([string]$property.Value);Detail='Configured policy value; interpretation depends on Windows version and management authority.'})
        }
    }
    if(-not $rows.Count){return [pscustomobject]@{Test='Windows Update policy';Status='INFO';Detail='No values were found in the two standard Windows Update policy registry paths. MDM policy may still apply.'}}
    $rows.ToArray()
}

function New-PcWindowsUpdateSession { New-Object -ComObject Microsoft.Update.Session }
function Release-PcComObject($Value) { if($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)){$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)} }
function ConvertFrom-PcUpdateResultCode([int]$Code) { @('Not started','In progress','Succeeded','Succeeded with errors','Failed','Aborted')[[math]::Min([math]::Max($Code,0),5)] }

function Get-PcWindowsUpdateHistory {
    $session=$null;$searcher=$null;$history=$null
    try{
        $session=New-PcWindowsUpdateSession;$searcher=$session.CreateUpdateSearcher();$count=[math]::Min(50,[int]$searcher.GetTotalHistoryCount())
        if($count -eq 0){return [pscustomobject]@{Test='Windows Update history';Status='INFO';Detail='Windows Update Agent returned no history entries.'}}
        $history=$searcher.QueryHistory(0,$count)
        for($i=0;$i -lt $history.Count;$i++){$entry=$history.Item($i);$result=ConvertFrom-PcUpdateResultCode ([int]$entry.ResultCode);$hresult=[uint32]([int64]$entry.HResult -band 0xffffffffL);[pscustomobject]@{Test='Windows Update history';Status=$(if([int]$entry.ResultCode -eq 2){'PASS'}else{'WARN'});Date=$entry.Date;Title=$entry.Title;Operation=$(switch([int]$entry.Operation){1{'Installation'}2{'Uninstallation'}default{'Other'}});Result=$result;HResult=('0x{0:X8}' -f $hresult);SupportUrl=$entry.SupportUrl;Detail='Latest 50 Windows Update Agent history events; Settings can use additional orchestrator history.'}}
    }finally{Release-PcComObject $history;Release-PcComObject $searcher;Release-PcComObject $session}
}

function Get-PcInstalledUpdates {
    Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object Source,Description,HotFixID,InstalledBy,InstalledOn
}

function Get-PcUpdateRebootStatus {
    $indicators=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach($path in $indicators){[pscustomobject]@{Test='Update reboot indicator';Status=$(if(Test-Path -LiteralPath $path){'WARN'}else{'PASS'});Indicator=$path;Present=[bool](Test-Path -LiteralPath $path);Detail='Common servicing marker only; absence does not prove that no application or update needs a restart.'}}
    $rename=(Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    [pscustomobject]@{Test='Pending file rename';Status=$(if($rename){'WARN'}else{'PASS'});Present=[bool]$rename;Detail='Pending file rename operations can be created by updates, drivers, or applications.'}
}

function Find-PcAvailableUpdates {
    $session=$null;$searcher=$null;$result=$null;$updates=$null
    try{
        $session=New-PcWindowsUpdateSession;$searcher=$session.CreateUpdateSearcher();$result=$searcher.Search('IsInstalled=0 and IsHidden=0');$updates=$result.Updates
        if(-not $updates.Count){return [pscustomobject]@{Test='Available updates';Status='PASS';Detail='Windows Update Agent returned no applicable, non-hidden updates.'}}
        for($i=0;$i -lt $updates.Count;$i++){$update=$updates.Item($i);[pscustomobject]@{Test='Available update';Status='REVIEW';Title=$update.Title;KB=@($update.KBArticleIDs) -join ',';Severity=$update.MsrcSeverity;Type=$update.Type;Downloaded=$update.IsDownloaded;Mandatory=$update.IsMandatory;RebootRequired=$update.RebootRequired;Detail='Discovery only. The toolkit did not accept a license, download, install, hide, or uninstall this update.'}}
    }finally{Release-PcComObject $updates;Release-PcComObject $result;Release-PcComObject $searcher;Release-PcComObject $session}
}

function Get-PcSecurityChecks {
    @(
        [pscustomobject]@{Key='1';Id='security-defender';Name='Microsoft Defender protection status';MinPS='5.0';Commands=@('Get-MpComputerStatus');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcDefenderStatus}}
        [pscustomobject]@{Key='2';Id='security-detections';Name='Microsoft Defender detection history';MinPS='5.0';Commands=@('Get-MpThreatDetection');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcDefenderDetections}}
        [pscustomobject]@{Key='3';Id='security-providers';Name='Registered antivirus providers';MinPS='5.0';Commands=@('Get-CimInstance');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcAntivirusProviders}}
        [pscustomobject]@{Key='4';Id='security-platform';Name='TPM and Secure Boot status';MinPS='5.0';Commands=@('Get-Tpm','Confirm-SecureBootUEFI');Admin=$true;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcPlatformSecurity}}
        [pscustomobject]@{Key='5';Id='security-vbs';Name='VBS, Credential Guard, and code-integrity status';MinPS='5.0';Commands=@('Get-CimInstance');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcDeviceGuardStatus}}
        [pscustomobject]@{Key='6';Id='security-bitlocker';Name='BitLocker volume status';MinPS='5.0';Commands=@('Get-BitLockerVolume');Admin=$true;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcBitLockerStatus}}
        [pscustomobject]@{Key='7';Id='security-audit';Name='Effective Windows audit policy';MinPS='5.0';Commands=@('auditpol.exe');Admin=$true;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcAuditPolicy}}
        [pscustomobject]@{Key='8';Id='security-firewall';Name='Windows Firewall profiles';MinPS='5.0';Commands=@('Get-NetFirewallProfile');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-NetworkFirewall}}
        [pscustomobject]@{Key='9';Id='security-events';Name='Security event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$true;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Security'}}
        [pscustomobject]@{Key='10';Id='security-defender-events';Name='Microsoft Defender event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-Windows Defender/Operational'}}
    )
}

function Get-PcUpdateChecks {
    @(
        [pscustomobject]@{Key='1';Id='update-services';Name='Windows Update service state';MinPS='5.0';Commands=@('Get-Service');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcWindowsUpdateServices}}
        [pscustomobject]@{Key='2';Id='update-policy';Name='Configured Windows Update policy';MinPS='5.0';Commands=@('Get-ItemProperty');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcWindowsUpdatePolicy}}
        [pscustomobject]@{Key='3';Id='update-history';Name='Windows Update Agent history (latest 50)';MinPS='5.0';Commands=@();Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcWindowsUpdateHistory}}
        [pscustomobject]@{Key='4';Id='update-installed';Name='Installed hotfix inventory';MinPS='5.0';Commands=@('Get-HotFix');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcInstalledUpdates}}
        [pscustomobject]@{Key='5';Id='update-reboot';Name='Update and servicing reboot indicators';MinPS='5.0';Commands=@('Test-Path','Get-ItemProperty');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcUpdateRebootStatus}}
        [pscustomobject]@{Key='6';Id='update-available';Name='Search configured update service for applicable updates';MinPS='5.0';Commands=@();Admin=$true;OpenMenu=$false;ConfirmRun=$true;Action={Find-PcAvailableUpdates}}
        [pscustomobject]@{Key='7';Id='update-events';Name='Windows Update event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-WindowsUpdateClient/Operational'}}
    )
}

function Start-PcDiagnosticMenu {
    param([string]$Title,[object[]]$Entries)
    $state=@{}
    while($true){
        $menu=@(foreach($entry in $Entries){$availability=Get-NetworkAvailability $entry;$reason=if($availability.Available){''}else{$availability.Reason};$detail='Read-only';if($entry.Admin){$detail+=' | Administrator'};if($entry.ConfirmRun){$detail+=' | Confirmation before potentially slow scan'};New-PcMenuItem $entry.Key $entry.Name 'Check' $detail $reason})
        $answer=Read-PcCategoryMenu $Title $menu $state 'Diagnostics only. No security setting or update installation is changed.'
        if($answer -eq 'B'){return}
        $entry=$Entries | Where-Object Key -eq $answer | Select-Object -First 1
        if(-not $entry){continue}
        Clear-PcMenuScreen
        try{
            $availability=Get-NetworkAvailability $entry;if(-not $availability.Available){throw $availability.Reason}
            if($entry.ConfirmRun -and (Read-Host 'Run this read-only scan now? It may contact the configured update service and take several minutes. [y/N]') -notmatch '^(?i:y|yes)$'){[pscustomobject]@{Test=$entry.Id;Status='CANCELLED';Detail='Scan not started.'}|Format-List|Out-Host;continue}
            & $entry.Action | Format-List | Out-Host
        }catch [OperationCanceledException]{continue}catch{Write-Warning $_.Exception.Message}
        if($entry.OpenMenu){continue}
        $null=Read-Host 'Press Enter to return'
    }
}

function Start-PcSecurityMenu { Start-PcDiagnosticMenu 'Windows > Security' @(Get-PcSecurityChecks) }
function Start-PcUpdateMenu { Start-PcDiagnosticMenu 'Windows > Windows Update' @(Get-PcUpdateChecks) }

function Start-WindowsMenu {
    param([switch]$AllowCallerReturn)
    $state=@{}
    while ($true) {
        $systemSummary=Format-PcSystemSummary (Get-PcSystemSummary)
        $menu=@(
            New-PcMenuItem '1' 'Computer and user details' 'Check' 'Full untruncated identity, groups, hardware, network and Windows information'
            New-PcMenuItem '2' 'Network' 'Menu' 'Connectivity, DNS, AD, routing and firewall'
            New-PcMenuItem '3' 'Power and device health'
            New-PcMenuItem '4' 'Storage'
            New-PcMenuItem '5' 'Printing'
            New-PcMenuItem '6' 'Group Policy'
            New-PcMenuItem '7' 'Event Logs'
            New-PcMenuItem '8' 'Registry tweaks'
            New-PcMenuItem '9' 'Health dashboard' 'Menu'
            New-PcMenuItem '10' 'Startup apps and scheduled tasks'
            New-PcMenuItem '11' 'Services'
            New-PcMenuItem '12' 'Windows repair centre'
            New-PcMenuItem '13' 'Microsoft Sysinternals Live' 'Menu' 'Microsoft-hosted network-share shortcuts; no local download'
            New-PcMenuItem '14' 'Windows Security' 'Menu' 'Defender, platform protections, encryption, audit, firewall and events'
            New-PcMenuItem '15' 'Windows Update' 'Menu' 'Services, policy, history, installed fixes, reboot state and read-only search'
            New-PcMenuItem '16' 'Certificates and TLS' 'Menu' 'Certificate health, remote TLS, chain trust, HTTP.sys bindings and events'
            New-PcMenuItem '17' 'SQL Server Snippets' 'Menu' 'Copyable read-only and modification T-SQL queries; nothing is executed or connected'
            New-PcMenuItem '99' 'Toolkit cleanup' 'Change' 'Preview and remove recognized toolkit temporary data or caches'
        )
        $answer=Read-PcCategoryMenu 'Windows' $menu $state $systemSummary -Root:(-not $AllowCallerReturn)
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Show-PcSystemDetails (Get-PcSystemSummary) }
            '2' { Start-NetworkMenu }
            '3' { Start-NetworkCategory 'power' }
            '4' { Start-NetworkCategory 'storage' }
            '5' { Start-NetworkCategory 'printing' }
            '6' { Start-NetworkCategory 'policy' }
            '7' { Start-PcEventLogMenu }
            '8' { Start-PcRegistryMenu }
            '9' { Start-PcHealthDashboard }
            '10' { Start-PcStartupTaskMenu }
            '11' { Start-PcServices }
            '12' { Start-PcWindowsRepair }
            '13' { Start-PcSysinternalsMenu }
            '14' { Start-PcSecurityMenu }
            '15' { Start-PcUpdateMenu }
            '16' { Start-PcCertificateMenu }
            '17' { Start-PcSqlSnippetsMenu }
            '99' { Start-ToolkitCleanup }
            default { Write-Warning 'Choose a listed section.' }
        }
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'Windows PowerShell 5.0+ is required (5.1 recommended).' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This toolkit requires Windows.' }
if ($Check -like 'ad-*') { Invoke-AdCheck $Check $DomainController }
elseif ($Check) { Invoke-NetworkCheck $Check $Target $Port }
elseif (-not $NoMenu) { Start-WindowsMenu }
