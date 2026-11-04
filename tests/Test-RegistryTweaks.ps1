$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
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
$script:Policy=$true
$blocked=$false; try { Invoke-PcRegistryTweak outlook } catch { $blocked=$true }
Assert-True $blocked 'Managed Outlook policy blocks preference change'
$script:Policy=$false
function Set-Content { [CmdletBinding()] param($LiteralPath,$Encoding,[Parameter(ValueFromPipeline=$true)]$Value) process { throw 'Backup denied' } }
$blocked=$false; try { Invoke-PcRegistryTweak outlook } catch { $blocked=$true }
Assert-True ($blocked -and $script:State.Count -eq 0) 'Backup failure prevents registry writes'
Write-Output 'Registry tests passed; all registry mutations mocked.'
