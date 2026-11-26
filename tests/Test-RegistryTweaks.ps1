$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Registry-Tweaks.ps1')
function Assert-True($Value,$Message) { if (-not $Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$script:Allowed=$true
function Get-NetworkAvailability { param($Entry) [pscustomobject]@{Available=(!$Entry.Admin -or $script:Allowed);Reason='Requires administrator'} }
function Get-Process { [CmdletBinding()] param($Name) }
$script:State=@{}
$script:Policy=$false
function Get-PcRegistryValues {
    param($Tweak)
    foreach ($name in $Tweak.Names) {
        $exists=$script:State.ContainsKey($name)
        if ($Tweak.Path -like '*Policies*Office*') { $exists=$script:Policy }
        [pscustomobject]@{Name=$name;Exists=$exists;Value=$(if ($exists) { $script:State[$name] } else { $null })}
    }
}
$script:Answer='n'; $script:Writes=0; $script:Backup=''
function Read-Host { param($Prompt) $script:Answer }
function New-Item { [CmdletBinding()] param($Path,$ItemType,[switch]$Force) $script:Writes++ }
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process { $script:Backup += "$Value`n" } }
function New-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force) Assert-True ($PropertyType -eq 'DWord') 'Writes DWORD'; $script:State[$Name]=$Value }
function Remove-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name) $script:State.Remove($Name) }
Invoke-PcRegistryTweak outlook
Assert-True ($script:Writes -eq 0) 'Cancellation makes no writes'
$script:Answer='yes'
Invoke-PcRegistryTweak outlook -WhatIf
Assert-True ($script:Writes -eq 0) 'WhatIf makes no writes'
Invoke-PcRegistryTweak outlook
Assert-True ($script:State.MaxLargeFileSize -eq 102400 -and $script:State.WarnLargeFileSize -eq 97280) '100 GB with five percent headroom'
Assert-True ($script:Backup.Contains('[HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\PST]') -and $script:Backup.Contains('"MaxLargeFileSize"=-')) 'Undo deletes originally absent values under the exact key'
$script:Backup=''
Invoke-PcRegistryTweak outlook -Reset
Assert-True ($script:State.Count -eq 0 -and $script:Backup.Contains('"MaxLargeFileSize"=dword:00019000')) 'Reset removes overrides and backs up previous DWORD'
$script:Allowed=$false
$blocked=$false; try { Invoke-PcRegistryTweak rdp } catch { $blocked=$true }
Assert-True $blocked 'RDP requires elevation'
$script:Allowed=$true
Invoke-PcRegistryTweak rdp
Assert-True ($script:State.RedirectionWarningDialogVersion -eq 1) 'RDP compatibility value is one'
Invoke-PcRegistryTweak rdp -Reset
Assert-True (-not $script:State.ContainsKey('RedirectionWarningDialogVersion')) 'RDP reset deletes only override'
Invoke-PcRegistryTweak rdpclientudp
Assert-True ($script:State.fClientDisableUDP -eq 1) 'End-user RDP client can be forced to TCP only'
Invoke-PcRegistryTweak rdpclientudp -Reset
Assert-True (-not $script:State.ContainsKey('fClientDisableUDP')) 'Client transport reset restores automatic selection'
Invoke-PcRegistryTweak rdpservertransport
Assert-True ($script:State.SelectTransport -eq 1) 'RDP Session Host can be forced to TCP only'
Assert-True ((Get-PcRegistryTweak rdpservertransport).Path -eq 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services') 'Server transport uses the Session Host policy key'
Invoke-PcRegistryTweak rdpservertransport -Reset
Assert-True (-not $script:State.ContainsKey('SelectTransport')) 'Server transport reset restores automatic selection'
$script:Policy=$true
$blocked=$false; try { Invoke-PcRegistryTweak outlook } catch { $blocked=$true }
Assert-True $blocked 'Managed Outlook policy blocks preference change'
$script:Policy=$false
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process { throw 'Backup denied' } }
$blocked=$false; try { Invoke-PcRegistryTweak outlook } catch { $blocked=$true }
Assert-True ($blocked -and $script:State.Count -eq 0) 'Backup failure prevents registry writes'
$source=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN REGISTRY TWEAKS',2)[1] -split '# END REGISTRY TWEAKS',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Registry-Tweaks.ps1') -Raw
Assert-True ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded registry module matches source'
Write-Output 'Registry tests passed; all registry mutations mocked.'

# Windows Update presets: all changes remain mocked, including protected services.
$script:UpdateState=@{};$script:UpdateWrites=0;$script:Backup='';$script:Allowed=$true;$script:Answer='n'
function Get-PcUpdateRegistryValue($Entry){
 $id=$Entry.Path+'|'+$Entry.Name
 if($script:UpdateState.ContainsKey($id)){return $script:UpdateState[$id]}
 [pscustomobject]@{Exists=$false;Kind=$null;Value=$null}
}
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process {$script:Backup+="$Value`n"} }
function New-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force)
 $script:UpdateWrites++;$script:UpdateState[$LiteralPath+'|'+$Name]=[pscustomobject]@{Exists=$true;Kind=[string]$PropertyType;Value=$Value}
}
function Remove-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name) $script:UpdateWrites++;$script:UpdateState.Remove($LiteralPath+'|'+$Name) }
$pause=@(Get-PcUpdateRegistryPreset Pause);$resume=@(Get-PcUpdateRegistryPreset Resume)
Assert-True ($pause.Count -eq 23 -and $resume.Count -eq 26) 'Exact active-entry counts from release 1.6.0'
Assert-True (-not ($pause.Path -match '\\wuauserv$|\\UsoSvc$|TaskCache')) 'Commented service and task examples are not included'
Assert-True (@($pause | Where-Object {$_.Name -eq 'UseWUServer' -and $_.Value -eq 0}).Count -eq 1) 'WSUS-changing value is explicit in upstream pause preset'
Invoke-PcUpdateRegistryPreset Pause
Assert-True ($script:UpdateWrites -eq 0) 'Update preset cancellation makes no registry changes'
$script:Answer='yes'
Invoke-PcUpdateRegistryPreset Pause -WhatIf
Assert-True ($script:UpdateWrites -eq 0) 'Update preset WhatIf makes no registry changes'
$script:Allowed=$false;$blocked=$false
try{Invoke-PcUpdateRegistryPreset Pause}catch{$blocked=$true}
Assert-True ($blocked -and $script:UpdateWrites -eq 0) 'Update presets require administrator'
$script:Allowed=$true
$original=[pscustomobject]@{Exists=$true;Kind='String';Value='original pause date'}
$script:UpdateState[$pause[0].Path+'|'+$pause[0].Name]=$original
Invoke-PcUpdateRegistryPreset Pause
Assert-True ($script:UpdateWrites -eq 23 -and $script:UpdateState.Count -eq 23) 'Pause writes and verifies every upstream active value'
Assert-True ($script:Backup.Contains('original pause date') -and $script:Backup.Contains('"PauseFeatureUpdatesEndTime"=-')) 'Undo preserves existing strings and originally absent values'
$script:Backup=''
Invoke-PcUpdateRegistryPreset Resume
Assert-True (-not $script:UpdateState.ContainsKey($pause[0].Path+'|'+$pause[0].Name)) 'Resume removes the upstream pause timestamp'
Assert-True ($script:UpdateState['HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc|Start'].Value -eq 3) 'Resume uses upstream Medic startup value'
Assert-True ($script:Backup.Contains('"Start"=dword:00000004') -and $script:Backup.Contains('"FailureActions"=hex:00')) 'Undo backs up previous DWORD and binary service values'
$script:Backup='';$beforeWrites=$script:UpdateWrites
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process {throw 'Backup denied'} }
$blocked=$false;try{Invoke-PcUpdateRegistryPreset Pause}catch{$blocked=$true}
Assert-True ($blocked -and $script:UpdateWrites -eq $beforeWrites) 'Update backup failure prevents any registry mutation'
Assert-True ($pause[0].Value -is [string] -and $pause[0].Value -ceq '2025-01-01T00:00:00Z') 'Timestamp registry values remain exact strings on all PowerShell versions'
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process {$script:Backup+="$Value`n"} }
function New-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force) throw 'Protected service access denied' }
$blocked=$false;try{Invoke-PcUpdateRegistryPreset Pause}catch{$blocked=$_.Exception.Message -match 'partially applied.*Restore previous values'}
Assert-True ($blocked -and $script:Backup.Contains('Windows Registry Editor')) 'Registry write errors report the saved undo file and partial-application risk'
function New-ItemProperty { [CmdletBinding()] param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force) }
$blocked=$false;try{Invoke-PcUpdateRegistryPreset Pause}catch{$blocked=$_.Exception.Message -match 'Read-back mismatch'}
Assert-True $blocked 'Read-back detects an ignored registry write'
