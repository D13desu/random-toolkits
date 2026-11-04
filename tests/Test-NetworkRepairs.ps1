$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
# Mock all system-changing operations. No real repair is performed by this suite.
$script:Role = 'Domain member'
$script:Elevated = $true
$script:Answer = 'REPAIR'
$script:Calls = New-Object 'System.Collections.Generic.List[string]'
function Get-AdContext { [pscustomobject]@{Computer='TEST';Domain='example.test';Role=$script:Role} }
function Get-NetworkAvailability {
    param($Entry)
    [pscustomobject]@{Available=$script:Elevated;Reason='Requires administrator'}
}
function Read-Host { param($Prompt) $script:Answer }
function Invoke-AdNative {
    param($Command,$Arguments)
    $script:Calls.Add($Command + ' ' + ($Arguments -join ' '))
    [pscustomobject]@{Status='PASS'}
}
$script:Adapter = [pscustomobject]@{InterfaceIndex=12;Description='Test adapter';SettingID='test-adapter-id';DHCPEnabled=$true;IPEnabled=$true}
function Get-CimInstance { param($ClassName,$Filter,$ErrorAction) $script:Adapter }
$script:DhcpCode = 0
function Invoke-CimMethod {
    param($InputObject,$MethodName,$ErrorAction)
    $script:Calls.Add("CIM $MethodName $($InputObject.InterfaceIndex)")
    [pscustomobject]@{ReturnValue=$script:DhcpCode}
}
$script:TrustHealthy = $false
$script:PostHealthy = $true
function Get-Credential {
    param($Message)
    $script:Calls.Add('Credential prompt')
    [pscredential]::new('EXAMPLE\test', (ConvertTo-SecureString 'test-only-not-a-real-password' -AsPlainText -Force))
}
function Test-ComputerSecureChannel {
    [CmdletBinding()] param([switch]$Repair, [string]$Server, [pscredential]$Credential)
    if ($Repair) {
        Assert-True ($null -ne $Credential -and $Server -eq 'dc.example.test') 'Repair receives credential and selected DC'
        $script:Calls.Add('Repair trust')
        $script:TrustHealthy = $script:PostHealthy
        return $true
    }
    $script:Calls.Add('Test trust')
    $script:TrustHealthy
}

$script:Elevated = $false
$blocked = $false
try { Invoke-NetworkRepair flush-dns -Confirm:$false } catch { $blocked = $_.Exception.Message -match 'administrator' }
Assert-True ($blocked -and $script:Calls.Count -eq 0) 'No repair without administrator rights'
$script:Elevated = $true
foreach ($role in @('Workgroup','Domain controller','Unknown')) {
    $script:Role = $role
    $blocked = $false
    try { Invoke-NetworkRepair repair-trust -Controller dc.example.test -Confirm:$false } catch { $blocked = $true }
    Assert-True ($blocked -and $script:Calls.Count -eq 0) "Trust repair blocked for $role"
}
$script:Role = 'Domain member'
foreach ($id in @('flush-dns','resync-time','renew-dhcp','repair-trust')) {
    $script:Answer = ''
    $result = Invoke-NetworkRepair $id -Controller dc.example.test -InterfaceIndex 12 -Confirm:$false
    Assert-True ($result.Status -eq 'CANCELLED' -and $script:Calls.Count -eq 0) "Cancellation leaves system untouched: $id"
    $null = Invoke-NetworkRepair $id -Controller dc.example.test -InterfaceIndex 12 -WhatIf
    Assert-True ($script:Calls.Count -eq 0) "WhatIf leaves system untouched: $id"
}
$script:Answer = 'REPAIR'
$null = Invoke-NetworkRepair flush-dns -Confirm:$false
$null = Invoke-NetworkRepair resync-time -Confirm:$false
Assert-True (($script:Calls -join '|') -eq 'ipconfig.exe /flushdns|w32tm.exe /resync') 'DNS and time execute only intended commands'
$script:Calls.Clear()
$script:Adapter.DHCPEnabled = $false
$blocked = $false
try { Invoke-NetworkRepair renew-dhcp -InterfaceIndex 12 -Confirm:$false } catch { $blocked = $true }
Assert-True ($blocked -and $script:Calls.Count -eq 0) 'Static-IP adapter cannot be renewed'
$script:Adapter.DHCPEnabled = $true
$result = Invoke-NetworkRepair renew-dhcp -InterfaceIndex 12 -Confirm:$false
Assert-True ($result.Status -eq 'PASS' -and $script:Calls[0] -eq 'CIM RenewDHCPLease 12') 'DHCP renew targets only selected adapter'
$script:DhcpCode = 82
$result = Invoke-NetworkRepair renew-dhcp -InterfaceIndex 12 -Confirm:$false
Assert-True ($result.Status -eq 'WARN' -and $result.ReturnCode -eq 82) 'DHCP failure is not reported as success'
$script:Calls.Clear()
$result = Invoke-NetworkRepair repair-trust -Controller dc.example.test -Confirm:$false
Assert-True ($result.Status -eq 'PASS' -and ($script:Calls -join '|') -eq 'Test trust|Credential prompt|Repair trust|Test trust') 'Trust repair prechecks, prompts, repairs, then verifies'
$script:Calls.Clear()
$result = Invoke-NetworkRepair repair-trust -Controller dc.example.test -Confirm:$false
Assert-True ($result.Status -eq 'SKIPPED' -and ($script:Calls -join '|') -eq 'Test trust') 'Healthy trust is never reset'
$script:Calls.Clear()
$script:TrustHealthy = $false
$script:PostHealthy = $false
$result = Invoke-NetworkRepair repair-trust -Controller dc.example.test -Confirm:$false
Assert-True ($result.Status -eq 'WARN') 'Failed post-repair verification is not reported as success'
$script:Calls.Clear()
function Read-Host { param($Prompt) $script:Role = 'Domain controller'; 'REPAIR' }
$blocked = $false
try { Invoke-NetworkRepair repair-trust -Controller dc.example.test -Confirm:$false } catch { $blocked = $true }
Assert-True ($blocked -and $script:Calls.Count -eq 0) 'Role changes during confirmation block repair'
Write-Host "Repair tests passed on PowerShell $($PSVersionTable.PSVersion); no actual system changes performed."
