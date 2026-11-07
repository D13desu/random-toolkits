# Random Toolkits | Windows Toolkit 0.20.0
# Self-contained: local execution and irm ... | iex use the same source.
[CmdletBinding()]
param(
    [switch]$NoMenu,
    [string]$Check,
    [string]$Target = 'example.com',
    [ValidateRange(1,65535)][int]$Port = 443,
    [string]$DomainController
)

function Read-PcInput {
    param([string]$Prompt)
    $answer=Read-Host ($Prompt+' [B: back]')
    if ($null -ne $answer -and $answer.Trim() -eq 'B') { throw [OperationCanceledException]::new('Back to menu.') }
    return $answer
}

# BEGIN REGISTRY TWEAKS
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
    param([ValidateSet('outlook','rdp')][string]$Id)
    $state=@{}
    while ($true) {
        $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=($Id -eq 'rdp')})
        $reason=if(-not $availability.Available){$availability.Reason}else{''}
        if($Id -eq 'outlook'){
            $title='Windows > Registry > Outlook'
            $menu=@(New-PcMenuItem '1' 'Inspect current size overrides' 'Check';New-PcMenuItem '2' 'Set PST/OST size limit' 'Change' 'Current account; classic Outlook' $reason;New-PcMenuItem '3' 'Reset size overrides' 'Change' 'Restore defaults' $reason)
        }else{
            $title='Windows > Registry > Remote Desktop'
            $menu=@(New-PcMenuItem '1' 'Inspect warning override' 'Check';New-PcMenuItem '2' 'Restore older RDP warning dialog' 'Change' 'Machine-wide; administrator' $reason;New-PcMenuItem '3' 'Reset RDP warning override' 'Change' 'Windows default; administrator' $reason)
        }
        $answer=Read-PcCategoryMenu $title $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        try {
            switch ($answer.Trim()) {
                '1' { $tweak=Get-PcRegistryTweak $Id; Write-Host $tweak.Path; Get-PcRegistryValues $tweak | Format-Table -AutoSize | Out-Host }
                '2' {
                    if ($Id -eq 'outlook') {
                        $size=Read-PcInput 'Maximum GB (1-1000; Enter for 100)'
                        if ([string]::IsNullOrWhiteSpace($size)) { $size='100' }
                        if ($size -notmatch '^\d+$') { throw 'Enter a whole number of GB.' }
                        Invoke-PcRegistryTweak outlook -SizeGB ([int]$size)
                    } else { Invoke-PcRegistryTweak rdp }
                }
                '3' { Invoke-PcRegistryTweak $Id -Reset }
                default { Write-Warning 'Choose a listed option.' }
            }
        } catch [OperationCanceledException] { continue } catch { Write-Warning $_.Exception.Message }
        Wait-PcMenuReturn
    }
}

function Start-PcRegistryMenu {
    $state=@{}
    while ($true) {
        $menu=@(New-PcMenuItem '1' 'Outlook' 'Menu' 'PST/OST file size limits';New-PcMenuItem '2' 'Remote Desktop' 'Menu' 'RDP warning dialog')
        $answer=Read-PcCategoryMenu 'Windows > Registry tweaks' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryCategory outlook }
            '2' { Start-PcRegistryCategory rdp }
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
        [pscustomobject]@{Name='Application';Log='Application'}
        [pscustomobject]@{Name='System';Log='System'}
        [pscustomobject]@{Name='Security (may require elevated access)';Log='Security'}
        [pscustomobject]@{Name='Setup';Log='Setup'}
        [pscustomobject]@{Name='Forwarded Events';Log='ForwardedEvents'}
        [pscustomobject]@{Name='Windows PowerShell';Log='Windows PowerShell'}
        [pscustomobject]@{Name='PowerShell Operational';Log='Microsoft-Windows-PowerShell/Operational'}
        [pscustomobject]@{Name='Microsoft Defender';Log='Microsoft-Windows-Windows Defender/Operational'}
        [pscustomobject]@{Name='Windows Update';Log='Microsoft-Windows-WindowsUpdateClient/Operational'}
        [pscustomobject]@{Name='Group Policy';Log='Microsoft-Windows-GroupPolicy/Operational'}
        [pscustomobject]@{Name='Printing';Log='Microsoft-Windows-PrintService/Admin'}
    )
}
function Start-PcEventLogMenu {
    $state=@{}
    while($true){
        $choices=@(Get-PcEventLogChoices)
        $menu=@(for($i=0;$i -lt $choices.Count;$i++){New-PcMenuItem ([string]($i+1)) $choices[$i].Name 'Browse' $choices[$i].Log})
        $menu+=New-PcMenuItem 'C' 'Custom log / advanced filters' 'Browse'
        $menu+=New-PcMenuItem 'L' 'List/search available logs' 'Check'
        $answer=Read-PcCategoryMenu 'Windows > Event Logs' $menu $state 'Presets show the latest 200 candidates from the last 24 hours. F changes filters inside the browser.'
        if($answer -eq 'B'){return}
        try{
            if($answer -eq 'C'){Start-PcEventBrowser;continue}
            if($answer -eq 'L'){Get-PcEventLogs | Format-Table -AutoSize | Out-Host;Wait-PcMenuReturn;continue}
            $log=$choices[([int]$answer)-1].Log
            $info=Get-WinEvent -ListLog $log -ErrorAction Stop
            if(-not $info.IsEnabled){Write-Warning "$log is disabled. No logging settings were changed.";Wait-PcMenuReturn;continue}
            Start-PcEventBrowser -DefaultLog $log -Quick
        }catch [OperationCanceledException]{continue}
        catch{Write-Warning ("Unable to read this log: {0}. Some logs need elevated access or are not installed on this PC." -f $_.Exception.Message);Wait-PcMenuReturn}
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
        Version='1.3.0'
        Uri='https://github.com/D13desu/random-toolkits/releases/download/disk-helper-v1.3.0/DiskHelper-1.3.0.zip'
        Sha256='9D1FFB11A88F2E2CA4A67AF0F648B28811C7C7BF1F888297B61528E1CF2032CD'
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
# Embedded into Network-Toolkit.ps1 for the single-download launcher.
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
    if(Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue){Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '127.*'} | Select-Object InterfaceAlias,IPAddress,PrefixLength | Format-Table -AutoSize | Out-Host}
    $scope=Read-PcInput 'Target CIDR, single IPv4 or startIPv4-endIPv4 (max 1024 addresses)'
    $targets=@(Get-DiscoveryTargets $scope)
    $text=Read-PcInput 'TCP ports [22,80,443,445,3389,9100; maximum 16]'
    if([string]::IsNullOrWhiteSpace($text)){$text='22,80,443,445,3389,9100'}
    $ports=@(Get-DiscoveryPorts $text)
    $timeout=400;$answer=Read-PcInput 'Probe timeout milliseconds [400; 100-2000]'
    if(-not [string]::IsNullOrWhiteSpace($answer)){
        if(-not [int]::TryParse($answer,[ref]$timeout) -or $timeout -lt 100 -or $timeout -gt 2000){throw 'Timeout must be 100-2000 milliseconds.'}
    }
    Write-Host ("Scanning {0} through {1}: {2} addresses; TCP ports {3}. B stops the scan." -f $targets[0],$targets[-1],$targets.Count,($ports -join ','))
    $result=Invoke-NetworkDiscovery -Scope $scope -Ports $ports -TimeoutMs $timeout
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
                Write-Host "Rescan the same scope: $scope; ports: $($ports -join ', ')"
                $result=Invoke-NetworkDiscovery -Scope $scope -Ports $ports -TimeoutMs $timeout
                $neighbors=@();try{if(Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue){$neighbors=@(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)}}catch{Write-Warning 'Neighbor cache unavailable.'}
                Add-DiscoveryMacInfo $result.Rows $database $neighbors
            }
            'Command'{switch($choice.Command){
                'A'{$showAll=-not $showAll}
                'D'{$probeView=-not $probeView}
                'L'{Show-PcListDetails ([pscustomobject]@{Scope=$scope;Completed=$result.Completed;Requested=$result.Requested;Cancelled=$result.Cancelled;IEEEStatus=$database.Status;RetrievedUTC=$database.RetrievedUtc;Notes='No response does not mean offline. Open ports do not identify services/device type. Closed means refused. MACs are exact-IP neighbor-cache observations, possibly stale/proxied. Routed targets usually have no MAC. Local/randomized MACs have no vendor attribution; vendor is the registered assignee, not verified identity.'}) 'Scan notes'}
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
                $reused=$process.CreationDate.ToUniversalTime() -gt $socket.CreationTime.ToUniversalTime()
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
        [pscustomobject]@{Key='disk-helper';Id='disk-helper';Name='Disk Usage 1.3.0 (automatic MFT/native)';MinPS='5.1';Commands=@('Expand-Archive','Get-FileHash');Admin=$false;Action={param($t,$p) Start-PcDiskHelper}}
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
        [pscustomobject]@{Key='4'; Id='ad'; Name='Active Directory and time'; Checks=@(); AdChecks=@('ad-context','ad-discovery','ad-dns','ad-secure','ad-time','ad-shares'); Repairs=@('repair-trust','resync-time')}
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
        if ($entry.Id -in @('ad-secure','ad-time','ad-shares')) {
            $answer = Read-PcInput 'DC hostname [automatic discovery]'
            if ($answer) { $dcName = $answer.Trim() }
            if ($dcName) { $null = Get-AdController $dcName }
        }
        Invoke-AdCheck $entry.Id $dcName
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
    param([string]$Title,[string]$Version='0.20.0')
    if($Title -eq 'Windows'){return "WINDOWS TOOLKIT $Version"}
    return "WINDOWS $Version | $Title"
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
    $detail=if($Compact){@()}else{@($Row.Detail | Select-Object -First $DetailLines)}
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
        [string]$Version='0.20.0',
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
function Read-PcCategoryMenu {
    param([string]$Title,[object[]]$Items,[hashtable]$State,[string[]]$Description=@())
    $keyboard=Test-PcMenuKeyboard;$selected=0
    for($i=0;$i -lt $Items.Count;$i++){if($Items[$i].Id -eq $State.SelectedId){$selected=$i;break}}
    while($true){
        $width=120
        if($keyboard){try{$width=[math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{};Clear-Host}
        Write-Host ("`n"+(Get-PcMenuHeading $Title)) -ForegroundColor Cyan
        foreach($line in $Description){if($line){Write-Host (Format-PcMenuText $line $width) -ForegroundColor DarkGray}}
        for($i=0;$i -lt $Items.Count;$i++){
            $item=$Items[$i]
            $color=if($keyboard -and $i -eq $selected){'Cyan'}elseif($item.DisabledReason){'DarkGray'}elseif($item.Kind -eq 'Change'){'Yellow'}else{'Gray'}
            $marker=if($keyboard -and $i -eq $selected){'>'}else{' '}
            $label='{0} [{1}] {2}' -f $marker,$item.Key,$item.Label
            if($item.Kind -eq 'Change'){$label+=' [CHANGES SYSTEM]'}
            if($item.DisabledReason){$label+=' [UNAVAILABLE: '+$item.DisabledReason+']'}
            elseif($item.Detail){$label+=' - '+($item.Detail -join ' ')}
            Write-Host (Format-PcMenuText $label $width) -ForegroundColor $color
        }
        if($keyboard){Write-Host 'Arrows + Enter or number + Enter | Esc/Backspace/B/0: back'}
        else{Write-Host 'Number + Enter | B / 0: back'}
        $answer=Read-PcMenuInput $keyboard
        if($null -eq $answer -or $answer.Trim() -in @('Back','B','0')){return 'B'}
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
    Write-Host ("`n"+$Title) -ForegroundColor Cyan
    $Row | Format-List * | Out-Host
    while($true){
        Write-Host 'Enter / Esc / Backspace / B: back'
        $answer=Read-PcMenuInput (Test-PcMenuKeyboard)
        if($null -eq $answer -or $answer.Trim() -in @('','Select','Back','B','0')){return}
    }
}
# END MENU ENGINE

function Get-PcSystemSummary {
    if($script:PcSystemSummary){return $script:PcSystemSummary}

    $unavailable='Unavailable'
    $username=$unavailable;$groups=$unavailable;$privateIp=$unavailable;$publicIp=$unavailable
    $hostname=[Environment]::MachineName;$storage=$unavailable;$cpu=$unavailable;$ram=$unavailable;$osVersion=$unavailable

    try {
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        $username=[string]$identity.Name
        $groupNames=@(foreach($sid in $identity.Groups){try{$sid.Translate([Security.Principal.NTAccount]).Value}catch{[string]$sid.Value}}) | Sort-Object -Unique
        if($groupNames.Count){$groups=$groupNames -join ', '}
    } catch {
        if([Environment]::UserName){$username=[Environment]::UserName}
    }
    try {
        $addresses=@(foreach($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()){
            if($adapter.OperationalStatus -ne [Net.NetworkInformation.OperationalStatus]::Up -or $adapter.NetworkInterfaceType -eq [Net.NetworkInformation.NetworkInterfaceType]::Loopback){continue}
            foreach($address in $adapter.GetIPProperties().UnicastAddresses){
                $value=[string]$address.Address
                if($address.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and $value -notlike '127.*' -and $value -notlike '169.254.*'){$value}
            }
        }) | Sort-Object -Unique
        if($addresses.Count){$privateIp=$addresses -join ', '}
    } catch {}
    try {
        $response=Invoke-RestMethod -UseBasicParsing -Uri 'https://api.ipify.org?format=json' -TimeoutSec 3 -ErrorAction Stop
        if($response.ip){$publicIp=[string]$response.ip}
    } catch {}
    try {
        $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -OperationTimeoutSec 5 -ErrorAction Stop | Where-Object Size)
        if($disks.Count){
            $total=($disks | Measure-Object Size -Sum).Sum;$free=($disks | Measure-Object FreeSpace -Sum).Sum
            $storage=('{0:N1} GiB free / {1:N1} GiB' -f ($free/1GB),($total/1GB))
        }
    } catch {}
    try {
        $processors=@(Get-CimInstance Win32_Processor -OperationTimeoutSec 5 -ErrorAction Stop)
        if($processors.Count){$cpu=(@($processors.Name | ForEach-Object {$_.Trim()} | Sort-Object -Unique) -join ' + ')}
    } catch {}
    try {
        $computer=Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 5 -ErrorAction Stop
        if($computer.TotalPhysicalMemory){$ram=('{0:N1} GiB' -f ($computer.TotalPhysicalMemory/1GB))}
    } catch {}
    try {
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 5 -ErrorAction Stop
        $osVersion=('{0} {1} (build {2})' -f $os.Caption,$os.Version,$os.BuildNumber).Trim()
    } catch {}

    $script:PcSystemSummary=[pscustomobject]@{
        Username=$username;Groups=$groups;Hostname=$hostname;PrivateIp=$privateIp;PublicIp=$publicIp
        Storage=$storage;Cpu=$cpu;Ram=$ram;OsVersion=$osVersion
    }
    return $script:PcSystemSummary
}

function Format-PcSystemSummary($Summary) {
    @(
        "User: $($Summary.Username) | Groups: $($Summary.Groups)"
        "Host: $($Summary.Hostname) | Public IP: $($Summary.PublicIp) | Private IP: $($Summary.PrivateIp)"
        "Storage: $($Summary.Storage) | CPU: $($Summary.Cpu) | RAM: $($Summary.Ram)"
        "OS: $($Summary.OsVersion)"
    )
}

function Start-WindowsMenu {
    $state=@{};$systemSummary=Format-PcSystemSummary (Get-PcSystemSummary)
    while ($true) {
        $menu=@(
            New-PcMenuItem '9' 'Health dashboard' 'Menu'
            New-PcMenuItem '1' 'Network' 'Menu' 'Connectivity, DNS, AD, routing and firewall'
            New-PcMenuItem '2' 'Power and device health'
            New-PcMenuItem '3' 'Storage'
            New-PcMenuItem '4' 'Printing'
            New-PcMenuItem '5' 'Group Policy'
            New-PcMenuItem '6' 'Event Logs'
            New-PcMenuItem '7' 'Registry tweaks'
            New-PcMenuItem '8' 'Toolkit cleanup'
            New-PcMenuItem '10' 'Startup apps and scheduled tasks'
            New-PcMenuItem '11' 'Services'
            New-PcMenuItem '12' 'Windows repair centre'
            New-PcMenuItem '13' 'Microsoft Sysinternals Live' 'Menu' 'Microsoft-hosted network-share shortcuts; no local download'
        )
        $answer=Read-PcCategoryMenu 'Windows' $menu $state $systemSummary
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-NetworkMenu }
            '2' { Start-NetworkCategory 'power' }
            '3' { Start-NetworkCategory 'storage' }
            '4' { Start-NetworkCategory 'printing' }
            '5' { Start-NetworkCategory 'policy' }
            '6' { Start-PcEventLogMenu }
            '7' { Start-PcRegistryMenu }
            '8' { Start-ToolkitCleanup }
            '9' { Start-PcHealthDashboard }
            '10' { Start-PcStartupTaskMenu }
            '11' { Start-PcServices }
            '12' { Start-PcWindowsRepair }
            '13' { Start-PcSysinternalsMenu }
            default { Write-Warning 'Choose a listed section.' }
        }
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'Windows PowerShell 5.0+ is required (5.1 recommended).' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This toolkit requires Windows.' }
if ($Check -like 'ad-*') { Invoke-AdCheck $Check $DomainController }
elseif ($Check) { Invoke-NetworkCheck $Check $Target $Port }
elseif (-not $NoMenu) { Start-WindowsMenu }
