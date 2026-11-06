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
