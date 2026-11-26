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
        $menu=@(New-PcMenuItem '1' 'End-user devices' 'Menu' 'Outlook and Remote Desktop client';New-PcMenuItem '2' 'Servers' 'Menu' 'Remote Desktop Session Host';New-PcMenuItem '3' 'Windows Update pause/resume' 'Menu' 'Aetherinox 1.6.0 registry presets')
        $answer=Read-PcCategoryMenu 'Windows > Registry tweaks' $menu $state
        if ($null -eq $answer -or $answer.Trim() -in @('0','B')) { return }
        switch ($answer.Trim()) {
            '1' { Start-PcRegistryEndUserMenu }
            '2' { Start-PcRegistryServerMenu }
            '3' { Start-PcUpdateRegistryMenu }
            default { Write-Warning 'Choose a listed option.' }
        }
    }
}


# Active entries from Aetherinox/pause-windows-updates tag 1.6.0.
# Commented examples are excluded. Resume is an upstream preset, not a restore.
function Get-PcUpdateRegistryPreset {
    param([ValidateSet('Pause','Resume')][string]$Mode)
    switch($Mode){
        'Pause' { @(
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseFeatureUpdatesStartTime';Kind='String';Value='2025-01-01T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseFeatureUpdatesEndTime';Kind='String';Value='2051-12-31T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseQualityUpdatesStartTime';Kind='String';Value='2025-01-01T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseQualityUpdatesEndTime';Kind='String';Value='2051-12-31T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseUpdatesStartTime';Kind='String';Value='2025-01-01T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseUpdatesExpiryTime';Kind='String';Value='2051-12-31T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='ActiveHoursStart';Kind='DWord';Value=13}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='ActiveHoursEnd';Kind='DWord';Value=7}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='FlightSettingsMaxPauseDays';Kind='DWord';Value=10023}
            [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';RegPath='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';Name='Start';Kind='DWord';Value=4}
            [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';RegPath='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';Name='FailureActions';Kind='Binary';Value=@(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AUOptions';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAutoUpdate';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAUShutdownOption';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AlwaysAutoRebootAtScheduledTime';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAutoRebootWithLoggedOnUsers';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AutoInstallMinorUpdates';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='UseWUServer';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedFeatureStatus';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedQualityStatus';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedQualityDate';Kind='String';Value='2025-01-01T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedFeatureDate';Kind='String';Value='2025-01-01T00:00:00Z'}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device\Update';Name='ExcludeWUDriversInQualityUpdate';Kind='DWord';Value=1}
        ) }
        'Resume' { @(
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseFeatureUpdatesStartTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseFeatureUpdatesEndTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseQualityUpdatesStartTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseQualityUpdatesEndTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseUpdatesStartTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='PauseUpdatesExpiryTime';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='ActiveHoursStart';Kind='DWord';Value=13}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='ActiveHoursEnd';Kind='DWord';Value=7}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='FlightSettingsMaxPauseDays';Kind='DWord';Value=10023}
            [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';RegPath='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';Name='Start';Kind='DWord';Value=3}
            [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';RegPath='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc';Name='FailureActions';Kind='Binary';Value=@(132,3,0,0,0,0,0,0,0,0,0,0,3,0,0,0,20,0,0,0,1,0,0,0,192,212,1,0,1,0,0,0,224,147,4,0,0,0,0,0,0,0,0,0)}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AUOptions';Kind='DWord';Value=4}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAutoUpdate';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAUShutdownOption';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AlwaysAutoRebootAtScheduledTime';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='NoAutoRebootWithLoggedOnUsers';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU';Name='AutoInstallMinorUpdates';Kind='DWord';Value=1}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedFeatureStatus';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedQualityStatus';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedQualityDate';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings';Name='PausedFeatureDate';Kind='Delete';Value=$null}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device\Update';Name='ExcludeWUDriversInQualityUpdate';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Update';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\Update';Name='ExcludeWUDriversInQualityUpdate';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings';Name='ExcludeWUDriversInQualityUpdate';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';Name='ExcludeWUDriversInQualityUpdate';Kind='DWord';Value=0}
            [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Update\ExcludeWUDriversInQualityUpdate';RegPath='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\Update\ExcludeWUDriversInQualityUpdate';Name='value';Kind='DWord';Value=0}
        ) }
    }
}

function Get-PcUpdateRegistryValue($Entry) {
    $key=Get-Item -LiteralPath $Entry.Path -ErrorAction SilentlyContinue -ErrorVariable readError
    if($readError -and $readError[0].CategoryInfo.Category -ne 'ObjectNotFound'){throw $readError[0]}
    $exists=$null -ne $key -and $Entry.Name -in $key.GetValueNames()
    $kind=if($exists){[string]$key.GetValueKind($Entry.Name)}else{$null}
    if($exists -and $kind -notin @('DWord','String','Binary')){throw "Unsupported existing type $kind for $($Entry.Path)\$($Entry.Name); no changes made."}
    [pscustomobject]@{Exists=$exists;Kind=$kind;Value=$(if($exists){$key.GetValue($Entry.Name)}else{$null})}
}

function ConvertTo-PcUpdateUndoLine($Entry,$Before) {
    $name=$Entry.Name.Replace('\','\\').Replace('"','\"')
    if(-not $Before.Exists){return ('"'+$name+'"=-')}
    switch($Before.Kind){
        'String' {return ('"'+$name+'"="'+([string]$Before.Value).Replace('\','\\').Replace('"','\"')+'"')}
        'DWord' {return ('"'+$name+'"=dword:'+('{0:x8}' -f [int]$Before.Value))}
        'Binary' {return ('"'+$name+'"=hex:'+((@($Before.Value) | ForEach-Object {'{0:x2}' -f [byte]$_}) -join ','))}
        default {throw 'Unsupported registry backup type.'}
    }
}

function Invoke-PcUpdateRegistryPreset {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([ValidateSet('Pause','Resume')][string]$Mode)
    $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@();Admin=$true})
    if(-not $availability.Available){throw $availability.Reason}
    $entries=@(Get-PcUpdateRegistryPreset $Mode)
    Write-Host 'Source: Aetherinox/pause-windows-updates 1.6.0 (active .reg entries only).' -ForegroundColor Cyan
    Write-Host 'Pause delays quality/security and feature updates until 2051, disables Medic and changes automatic update, driver and WSUS settings.' -ForegroundColor Yellow
    Write-Host 'Resume applies upstream settings; it is NOT an undo. Both presets can override organization-managed settings. Windows may reject or reapply values.' -ForegroundColor Yellow
    Write-Host 'No services are stopped, permissions bypassed, tasks removed, or reboot initiated. Registry read-back does not prove effective update behavior.'
    $before=@(foreach($entry in $entries){Get-PcUpdateRegistryValue $entry})
    for($i=0;$i -lt $entries.Count;$i++){
        $entry=$entries[$i];$value=if($entry.Kind -eq 'Delete'){'<delete value>'}elseif($entry.Kind -eq 'Binary'){(@($entry.Value) -join ',')}else{$entry.Value}
        Write-Host ("{0}\{1} : {2} => {3} ({4})" -f $entry.Path,$entry.Name,$before[$i].Value,$value,$entry.Kind)
    }
    if(-not $PSCmdlet.ShouldProcess('Machine-wide Windows Update registry values',"Apply $Mode preset and save previous values")){return}
    if((Read-Host 'Apply this Windows Update preset? [y/N]') -notmatch '^(?i:y|yes)$'){Write-Host 'Cancelled.';return}
    $backupDir=Join-Path $env:LOCALAPPDATA 'Random-Toolkits\registry-backups'
    $null=New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop
    $backup=Join-Path $backupDir ('windows-update-'+$Mode+'-'+[guid]::NewGuid().ToString('N')+'.reg')
    $lines=@('Windows Registry Editor Version 5.00','')
    for($i=0;$i -lt $entries.Count;$i++){
        $lines+=('['+$entries[$i].RegPath+']')
        $lines+=ConvertTo-PcUpdateUndoLine $entries[$i] $before[$i]
        $lines+=''
    }
    $lines | Set-Content -LiteralPath $backup -Encoding Unicode -ErrorAction Stop
    Write-Host "Undo file: $backup (import as administrator to restore previous values)."
    try{
        for($i=0;$i -lt $entries.Count;$i++){
            $entry=$entries[$i]
            if($entry.Kind -eq 'Delete'){
                if($before[$i].Exists){Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction Stop}
            }else{
                $null=New-Item -Path $entry.Path -Force -ErrorAction Stop
                $value=if($entry.Kind -eq 'Binary'){[byte[]]$entry.Value}else{$entry.Value}
                $null=New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $value -PropertyType $entry.Kind -Force -ErrorAction Stop
            }
        }
        foreach($entry in $entries){
            $after=Get-PcUpdateRegistryValue $entry
            if($entry.Kind -eq 'Delete'){if($after.Exists){throw 'Deleted value still exists.'}}
            elseif(-not $after.Exists -or $after.Kind -ne $entry.Kind -or (@($after.Value) -join ',') -cne (@($entry.Value) -join ',')){throw "Read-back mismatch: $($entry.Path)\$($entry.Name)"}
        }
        Write-Host 'Registry values verified. Review Windows Update settings for actual status.' -ForegroundColor Green
    }catch{throw "Preset failed or was partially applied: $($_.Exception.Message) Restore previous values with $backup"}
}

function Start-PcUpdateRegistryMenu {
    $state=@{}
    while($true){
        $menu=@(New-PcMenuItem '1' 'Preview pause preset' 'Check';New-PcMenuItem '2' 'Apply pause preset' 'Change' 'Administrator; includes security updates, Medic and WSUS settings';New-PcMenuItem '3' 'Preview resume preset' 'Check';New-PcMenuItem '4' 'Apply resume preset' 'Change' 'Upstream settings; not a restore of prior values')
        $answer=Read-PcCategoryMenu 'Windows > Registry tweaks > Windows Update' $menu $state 'Aetherinox 1.6.0. Both apply actions preview values, require confirmation, and save an undo file.'
        if($null -eq $answer -or $answer.Trim() -in @('0','B')){return}
        try{
            switch($answer.Trim()){
                '1' {Get-PcUpdateRegistryPreset Pause | Format-List | Out-Host}
                '2' {Invoke-PcUpdateRegistryPreset Pause}
                '3' {Get-PcUpdateRegistryPreset Resume | Format-List | Out-Host}
                '4' {Invoke-PcUpdateRegistryPreset Resume}
            }
        }catch [OperationCanceledException]{continue}catch{Write-Warning $_.Exception.Message}
        Wait-PcMenuReturn
    }
}
