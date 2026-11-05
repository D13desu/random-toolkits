# Random Toolkits | Windows Toolkit 0.8.0
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
        Write-Host ' [B / 0] Back'
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        try {
            switch ($answer.Trim()) {
                '1' { foreach ($id in @('outlook','rdp')) { $tweak=Get-PcRegistryTweak $id; Write-Host $tweak.Path; Get-PcRegistryValues $tweak | Format-Table -AutoSize | Out-Host } }
                '2' { $size=Read-PcInput 'Maximum GB (1-1000; Enter for 100)'; if ([string]::IsNullOrWhiteSpace($size)) { $size='100' }; if ($size -notmatch '^\d+$') { throw 'Enter a whole number of GB.' }; Invoke-PcRegistryTweak outlook -SizeGB ([int]$size) }
                '3' { Invoke-PcRegistryTweak outlook -Reset }
                '4' { Invoke-PcRegistryTweak rdp }
                '5' { Invoke-PcRegistryTweak rdp -Reset }
                default { Write-Warning 'Choose a listed option.' }
            }
        } catch [OperationCanceledException] { continue } catch { Write-Warning $_.Exception.Message }
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
    param([string]$Message,[ValidateRange(20,200)][int]$Width=100)
    $text=($Message -replace '[\x00-\x1F\x7F]',' ' -replace '\s+',' ').Trim()
    if(-not $text){return '[No rendered message; open event for XML.]'}
    for($line=0;$line -lt 3 -and $text.Length;$line++){
        if($text.Length -le $Width){$text;break}
        $take=$Width
        if([char]::IsHighSurrogate($text[$take-1])){$take--}
        $space=$text.LastIndexOf(' ',$take-1,$take)
        if($space -gt 0){$take=$space}
        if($line -eq 2){$text.Substring(0,$take).TrimEnd()+' ...';break}
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
    $keyboard=Test-PcEventKeyboard
    if($keyboard){Clear-Host}
    $EventRecord | Select-Object Time,Id,Level,Provider,Log,RecordId,Machine | Format-List | Out-Host
    Write-Host $EventRecord.Message
    while($true){
        Write-Host 'X: raw XML | M: full message | Enter / Left / Esc: back'
        $answer=Read-PcEventChoice $keyboard 'X: raw XML | M: full message | Enter / B / 0: back'
        switch(([string]$answer).Trim().ToUpperInvariant()){
            ''{return} 'B'{return} '0'{return} '@ENTER'{return}
            'M'{Write-Host $EventRecord.Message}
            'X'{if($EventRecord.Xml){Write-Host $EventRecord.Xml}else{Write-Warning ('XML unavailable: '+$EventRecord.XmlError)}}
        }
    }
}
function Start-PcEventBrowser {
    param([string]$DefaultLog='System',[switch]$Quick,[switch]$FixedLog)
    $log=$DefaultLog;$hours=24;$ids=@();$levels=@();$provider='';$text='';$limit=200
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
    $keyboard=Test-PcEventKeyboard;$selected=0
    $page=0;$pageSize=5;$previewWidth=100
    try{$previewWidth=[math]::Max(20,[math]::Min(120,$Host.UI.RawUI.WindowSize.Width-6))}catch{}
    :events while ($true) {
        if($keyboard){
            try{$pageSize=[math]::Max(1,[math]::Min(5,[math]::Floor(($Host.UI.RawUI.WindowSize.Height-10)/5)));$previewWidth=[math]::Max(20,[math]::Min(120,$Host.UI.RawUI.WindowSize.Width-6))}catch{}
            $page=[int][math]::Floor($selected/[double]$pageSize);Clear-Host
        }
        $pages=[math]::Max(1,[math]::Ceiling($events.Count/[double]$pageSize))
        Write-Host "`n EVENTS | $log | $($events.Count) results | page $($page+1)/$pages" -ForegroundColor Cyan
        Write-Host ("Last {0} hours | Candidate cap: {1} | IDs: {2} | Levels: {3}" -f $hours,$limit,($ids -join ','),($levels -join ','))
        if(-not $events.Count){Write-Host 'No matching events in this window. F opens filters to widen the search.'}
        for ($i=$page*$pageSize; $i -lt [math]::Min($events.Count,($page+1)*$pageSize); $i++) {
            $event=$events[$i]
            $marker=if($i -eq $selected){'>'}else{' '};$color=if($i -eq $selected){'Cyan'}else{'Gray'}
            Write-Host ('{0}[{1}] {2} | {3} | ID {4} | {5}' -f $marker,($i+1),$event.Time,$event.Level,$event.Id,$event.Provider) -ForegroundColor $color
            foreach($line in @(Format-PcEventPreview -Message $event.Message -Width $previewWidth)){Write-Host ('     '+$line)}
            Write-Host ''
        }
        if($keyboard){Write-Host 'Up/Down: select | Enter: full message/XML | PgUp/PgDn: pages | R: refresh | F: filter | Left/Esc: back'}
        $answer=Read-PcEventChoice $keyboard 'Number: full message / XML | N/P: pages | R: refresh | F: filtered view | B / 0: back'
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim().ToUpperInvariant()) {
            '@UP'{$selected=[math]::Max(0,$selected-1);$page=[int][math]::Floor($selected/[double]$pageSize);continue events}
            '@DOWN'{$selected=[math]::Max(0,[math]::Min($events.Count-1,$selected+1));$page=[int][math]::Floor($selected/[double]$pageSize);continue events}
            '@HOME'{$selected=0;$page=0;continue events}
            '@END'{$selected=[math]::Max(0,$events.Count-1);$page=[int][math]::Floor($selected/[double]$pageSize);continue events}
            '@ENTER'{if($events.Count){Show-PcEventDetails $events[$selected]};continue events}
            'N' { $page=[math]::Min($pages-1,$page+1);$selected=$page*$pageSize; continue events }
            'P' { $page=[math]::Max(0,$page-1);$selected=$page*$pageSize; continue events }
            'R' { $events=@(Get-PcEventRecords -LogName $log -Hours $hours -Ids $ids -Levels $levels -Provider $provider -Text $text -Limit $limit);$page=0;$selected=0;continue events }
            'F' { try{Start-PcEventBrowser -DefaultLog $log -FixedLog}catch [OperationCanceledException]{};continue events }
        }
        $number=0
        if ([int]::TryParse($answer,[ref]$number) -and $number -gt 0 -and $number -le $events.Count) { $selected=$number-1;$page=[int][math]::Floor($selected/[double]$pageSize);Show-PcEventDetails $events[$selected] }
        else { Write-Warning 'Choose an event number, N, P or 0.' }
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
    $keyboard=Test-PcEventKeyboard;$selected=0
    while($true){
        if($keyboard){Clear-Host}
        Write-Host "`nWINDOWS TOOLKIT > EVENT LOGS" -ForegroundColor Cyan
        $choices=@(Get-PcEventLogChoices)
        for($i=0;$i -lt $choices.Count;$i++){$marker=if($i -eq $selected){'>'}else{' '};$color=if($i -eq $selected){'Cyan'}else{'Gray'};Write-Host ('{0}[{1}] {2}' -f $marker,($i+1),$choices[$i].Name) -ForegroundColor $color}
        Write-Host ' [C] Custom log / advanced filters   [L] List/search available logs'
        Write-Host ' [B / 0] Back'
        Write-Host 'Choose a log to immediately view its latest 200 events from the last 24 hours. F changes filters inside the browser.'
        if($keyboard){Write-Host 'Up/Down: select | Enter: open log | Left/Esc: back'}
        $answer=Read-PcEventChoice $keyboard;$number=0
        if($null -eq $answer -or $answer.Trim() -in @('B','0')){return}
        switch($answer){
            '@UP'{$selected=[math]::Max(0,$selected-1);continue}
            '@DOWN'{$selected=[math]::Min($choices.Count-1,$selected+1);continue}
            '@HOME'{$selected=0;continue}
            '@END'{$selected=$choices.Count-1;continue}
            '@ENTER'{$answer=[string]($selected+1)}
        }
        if($answer -in @('@UP','@DOWN','@HOME','@END')){continue}
        try{
            if($answer.Trim() -eq 'C'){Start-PcEventBrowser;continue}
            if($answer.Trim() -eq 'L'){Get-PcEventLogs | Format-Table -AutoSize | Out-Host;if($keyboard){$null=Read-Host 'Enter to return'};continue}
            if(-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $choices.Count){Write-Warning 'Choose a listed log.';continue}
            $selected=$number-1;$log=$choices[$selected].Log
            $info=Get-WinEvent -ListLog $log -ErrorAction Stop
            if(-not $info.IsEnabled){Write-Warning "$log is disabled. No logging settings were changed.";if($keyboard){$null=Read-Host 'Enter to return'};continue}
            Start-PcEventBrowser -DefaultLog $log -Quick
        }catch [OperationCanceledException] {continue}
        catch{Write-Warning ("Unable to read this log: {0}. Some logs need elevated access or are not installed on this PC." -f $_.Exception.Message);if($keyboard){$null=Read-Host 'Enter to return'}}
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
    $revision='10efb47886b97a1619756f297d7d6bbf7d3b1295'
    $expected='827A4432D7DF2DF66C2E048331268F5D806A38A601641C07FC88D2B9DE21E3F2'
    $download=Join-Path ([IO.Path]::GetTempPath()) ('toolkit-disk-'+[guid]::NewGuid().ToString('N')+'.ps1')
    try {
        Write-Host 'Downloading verified Disk Usage 0.4.5 from D13desu/random-toolkits...'
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
        Version='0.8.1-experiment'
        Uri='https://github.com/D13desu/random-toolkits/releases/download/disk-helper-experiment-v0.8.1/DiskHelper-0.8.1-experiment.zip'
        Sha256='A3C1090C6B0FA6DE1D4A743421B2E362BBB866883EE2EEC2FEB0D5233CDAFD61'
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
    $page=0;$showAll=$false;$probeView=$false
    while($true){
        $rows=@($result.Rows | Where-Object {$showAll -or $_.Responded})
        Write-Host ("`nDISCOVERY | {0}/{1} addresses checked | Cancelled: {2} | Displayed: {3}" -f $result.Completed,$result.Requested,$result.Cancelled,$rows.Count) -ForegroundColor Cyan
        Write-Host 'No response does not mean offline. Open ports do not identify services or device type. Closed = connection refused; Error = another connection error.'
        Write-Host ('IEEE data: {0} | Retrieved UTC: {1}. Vendor is the registered assignee, not a verified device identity.' -f $database.Status,$database.RetrievedUtc)
        Write-Host 'MACs are exact-IP neighbor-cache observations (possibly stale/proxied); routed targets usually have no MAC. Local/randomized MACs have no vendor attribution.'
        if($probeView){$rows | Select-Object -Skip ($page*20) -First 20 | Format-Table Address,Ping,LatencyMs,OpenTCP,ClosedTCP,NoResponseTCP,ErrorTCP -AutoSize | Out-Host}
        else{$rows | Select-Object -Skip ($page*20) -First 20 | Format-Table Address,MAC,Vendor,MacStatus,OpenTCP -Wrap | Out-Host}
        $answer=Read-Host 'N/P: pages | A: all/responding | D: MAC/probe view | M: lookup MAC | E: export CSV | B / 0: back'
        switch(([string]$answer).Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            'N'{if(($page+1)*20 -lt $rows.Count){$page++}} 'P'{$page=[math]::Max(0,$page-1)}
            'A'{$showAll=-not $showAll;$page=0}
            'D'{$probeView=-not $probeView}
            'M'{try{Resolve-DiscoveryOui (Read-PcInput 'MAC address') $database | Format-List | Out-Host}catch [OperationCanceledException] {}}
            'E'{
                try{$path=Read-PcInput 'New CSV file path';if(Test-Path -LiteralPath $path){throw 'Choose a new filename; existing files are not overwritten.'};$result.Rows | Select-Object *,@{n='ScanScope';e={$result.Scope}},@{n='ScanCancelled';e={$result.Cancelled}},@{n='AddressesRequested';e={$result.Requested}},@{n='AddressesCompleted';e={$result.Completed}} | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop;Write-Host "Saved: $path"}
                catch [OperationCanceledException] {} catch{Write-Warning $_.Exception.Message}
            }
        }
    }
}
# END NETWORK DISCOVERY

function Get-NetworkChecks {
    # Add entries here. Requirements are evaluated before displaying AND running a check.
    @(
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
        [pscustomobject]@{Key='disk';Id='disk';Name='Open disk usage explorer (verified download)';MinPS='5.0';Commands=@();Admin=$false;Action={param($t,$p) Start-PcDiskExplorer}}
        [pscustomobject]@{Key='disk-helper';Id='disk-helper';Name='Experimental MFT disk explorer 0.8.1 (C# helper)';MinPS='5.1';Commands=@('Expand-Archive','Get-FileHash');Admin=$true;Action={param($t,$p) Start-PcDiskHelper}}
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
        [pscustomobject]@{Key='2'; Id='connectivity'; Name='Connectivity and adapters'; Checks=@('connectivity','tcp','overview','discovery'); AdChecks=@(); Repairs=@('renew-dhcp')}
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
        Write-Host "`n [B / 0] Back"
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        $item = $items | Where-Object { $_.Key -eq $answer.Trim() } | Select-Object -First 1
        if (-not $item) { Write-Warning 'Unknown selection'; continue }
        try {
            $availability = Get-NetworkItemAvailability $item (Get-AdContext)
            if (-not $availability.Available) { throw $availability.Reason }
            Invoke-InteractiveCheck $item | Format-List | Out-Host
        } catch [OperationCanceledException] { continue } catch { Write-Warning $_.Exception.Message }
        if ($item.Entry.Id -in @('disk','disk-helper','event-browser','discovery')) { continue }
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
        Write-Host "`n [B / 0] Back"
        Write-Host 'Checks and repairs are grouped by topic. Repairs ask before making changes.' -ForegroundColor DarkGray
        $selection = Read-Host 'Select'
        if ($null -eq $selection -or $selection.Trim() -in @('0','B')) { return }
        # Retain the former AD shortcut for existing users.
        if ($selection.Trim() -eq 'A') { Start-AdMenu; continue }
        $category = Get-NetworkCategories | Where-Object { $_.Key -eq $selection.Trim() -and $_.Id -in @('overview','connectivity','dns','ad','routing','firewall') } | Select-Object -First 1
        if (-not $category) { Write-Warning 'Unknown selection'; continue }
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
    while($true){
        Write-Host "`nTOOLKIT CLEANUP | current account only" -ForegroundColor Cyan
        Write-Host ' [1] Temporary packages, diagnostic reports and test fixtures'
        Write-Host ' [2] Download caches (IEEE and cached M365 scripts)'
        Write-Host ' [3] Both     [B / 0] Back'
        Write-Host 'Saved exports, M365 reports, registry undo files, installed modules and sign-in sessions are retained.'
        $answer=Read-Host 'Select'
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
        }catch{Write-Warning $_.Exception.Message}
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
                $status=if($nic.Status -eq 'UNAVAILABLE'){'UNAVAILABLE'}elseif(@($nic.AllowComputerToTurnOffDevice,$nic.SelectiveSuspend,$nic.DeviceSleepOnDisconnect) -contains 'Enabled'){'REVIEW'}else{'INFO'}
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
                $status=if(-not $adapter.Gateways -or -not $adapter.DNS){'REVIEW'}else{'INFO'}
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
    Write-Host 'Related checks/repair menus retain their requirements and yes/no confirmation. No repair is run by opening this finding.'
    while($true){
        $answer=Read-Host '1: open related tools | B / 0 / Enter: back'
        if([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim() -in @('B','0')){return}
        if($answer.Trim() -eq '1'){try{Open-PcHealthTarget $Finding.Target}catch{Write-Warning $_.Exception.Message};return}
    }
}
function Start-PcHealthDashboard {
    $network=$false;$snapshot=Get-PcHealthDashboard;$selected=0;$keyboard=Test-PcEventKeyboard;$pageSize=8
    while($true){
        if($keyboard){Clear-Host}
        $rows=@($snapshot.Rows);$page=[int][math]::Floor($selected/[double]$pageSize)
        Write-Host ("`nWINDOWS HEALTH | {0} | READ ONLY" -f $snapshot.CollectedAt) -ForegroundColor Cyan
        Write-Host 'Snapshot, not a full health certificate. C runs live gateway, DNS and domain-member trust checks (no repair).'
        Write-Host ('Live network checks included: '+$network)
        $counts=($rows | Group-Object Status | ForEach-Object {"$($_.Name): $($_.Count)"}) -join ' | ';Write-Host $counts
        for($i=$page*$pageSize;$i -lt [math]::Min($rows.Count,($page+1)*$pageSize);$i++){
            $marker=if($i -eq $selected){'>'}else{' '};$color=if($rows[$i].Status -eq 'WARN'){'Yellow'}elseif($i -eq $selected){'Cyan'}else{'Gray'}
            Write-Host ('{0}[{1}] {2,-11} {3}' -f $marker,($i+1),$rows[$i].Status,$rows[$i].Title) -ForegroundColor $color
        }
        Write-Host ('Page {0}/{1} | Up/Down: select | Enter: findings/tools | N/P: pages | R: refresh | C: live network checks | B/Esc: back' -f ($page+1),[math]::Max(1,[math]::Ceiling($rows.Count/[double]$pageSize)))
        $answer=Read-PcEventChoice $keyboard 'Number: finding/tools | N/P: pages | R: refresh | C: live checks | B / 0: back'
        switch(([string]$answer).Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            '@UP'{$selected=[math]::Max(0,$selected-1)}
            '@DOWN'{$selected=[math]::Max(0,[math]::Min($rows.Count-1,$selected+1))}
            '@HOME'{$selected=0} '@END'{$selected=[math]::Max(0,$rows.Count-1)}
            'N'{if(($page+1)*$pageSize -lt $rows.Count){$selected=($page+1)*$pageSize}}
            'P'{$selected=[math]::Max(0,($page-1)*$pageSize)}
            'R'{$snapshot=Get-PcHealthDashboard -IncludeNetwork:$network;$selected=0}
            'C'{$network=$true;$snapshot=Get-PcHealthDashboard -IncludeNetwork;$selected=0}
            '@ENTER'{if($rows.Count){Show-PcHealthFinding $rows[$selected]}}
            default{$number=0;if([int]::TryParse($answer,[ref]$number) -and $number -ge 1 -and $number -le $rows.Count){$selected=$number-1;Show-PcHealthFinding $rows[$selected]}}
        }
    }
}
# END HEALTH DASHBOARD

function Start-WindowsMenu {
    while ($true) {
        Write-Host "`n============================================" -ForegroundColor Cyan
        Write-Host ' RANDOM TOOLKITS | WINDOWS 0.8.0' -ForegroundColor Cyan
        Write-Host " PowerShell $($PSVersionTable.PSVersion) | DIAGNOSE AND REPAIR"
        Write-Host '============================================' -ForegroundColor Cyan
        Write-Host ' [9] Health dashboard - start here'
        Write-Host ' [1] Network - connectivity, DNS, AD, routing, firewall'
        Write-Host ' [2] Power and device health - battery, plans, NIC sleep'
        Write-Host ' [3] Storage - drives and folder sizes'
        Write-Host ' [4] Printing - printers, queues, spooler and events'
        Write-Host ' [5] Group Policy - results, refresh and events'
        Write-Host ' [6] Event Logs - filtered CLI viewer'
        Write-Host ' [7] Registry tweaks - Outlook file limits and RDP warning'
        Write-Host ' [8] Toolkit cleanup - temporary files and download caches'
        Write-Host "`n [B / 0] Exit"
        Write-Host 'Repair options ask before making changes. M365 remains a separate toolkit.' -ForegroundColor DarkGray
        $answer = Read-Host 'Select'
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
            default { Write-Warning 'Choose a listed section.' }
        }
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'Windows PowerShell 5.0+ is required (5.1 recommended).' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This toolkit requires Windows.' }
if ($Check -like 'ad-*') { Invoke-AdCheck $Check $DomainController }
elseif ($Check) { Invoke-NetworkCheck $Check $Target $Port }
elseif (-not $NoMenu) { Start-WindowsMenu }
