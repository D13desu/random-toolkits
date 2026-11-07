$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert-True($Value,$Message) { if (-not $Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$script:CurrentPlan='381b4222-f694-41f0-9685-ff5bb260df2e'
$script:HighAvailable=$true
function powercfg.exe {
    $script:LASTEXITCODE=0
    if ($args[0] -ne '/list') { throw 'Unexpected real powercfg operation' }
    $marker=''; if ($script:CurrentPlan -eq '381b4222-f694-41f0-9685-ff5bb260df2e') { $marker='*' }
    "GUID de esquema de energia: 381b4222-f694-41f0-9685-ff5bb260df2e (Equilibrado) $marker"
    if ($script:HighAvailable) {
        $marker=''; if ($script:CurrentPlan -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') { $marker='*' }
        "GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c (Alto rendimiento) $marker"
    }
}
$script:Portable=$true
function Get-CimInstance {
    param($ClassName,$ErrorAction)
    switch ($ClassName) {
        'Win32_SystemEnclosure' { $code=3; if ($script:Portable) { $code=10 }; [pscustomobject]@{ChassisTypes=@($code)} }
        'Win32_Battery' { if ($script:Portable) { [pscustomobject]@{Name='Test battery';EstimatedChargeRemaining=60;BatteryStatus=2} } }
        default { throw "Unexpected CIM class: $ClassName" }
    }
}
$plans=@(Get-PcPowerPlans)
Assert-True ($plans.Count -eq 2 -and $plans[0].Active -and -not $plans[1].Active) 'Power plans parsed without English-dependent labels'
$overview=@(Get-PcPowerOverview)
Assert-True ($overview[0].Device -like 'Laptop*' -and $overview[0].Assessment -match 'not using standard High performance') 'Portable chassis and non-high-performance plan detected'
$script:HighAvailable=$false
$overview=@(Get-PcPowerOverview)
Assert-True ($overview[0].Assessment -match 'not exposed') 'Missing High performance plan is reported without creating one'
$script:Portable=$false
Assert-True (@(Get-PcPowerOverview)[0].Device -like 'Desktop*') 'Desktop does not get classified as a laptop'
function Get-AdContext { [pscustomobject]@{Role='Workgroup';Computer='TEST';Domain='WORKGROUP'} }
function Get-NetworkAvailability { param($Entry) [pscustomobject]@{Available=$true;Reason=''} }
$script:Answer='n'
function Read-Host { param($Prompt) $script:Answer }
$script:Changes=New-Object 'System.Collections.Generic.List[string]'
function Invoke-AdNative {
    param($Command,$Arguments)
    $script:Changes.Add($Command+' '+($Arguments -join ' '))
    if ($Command -eq 'powercfg.exe' -and $Arguments[0] -eq '/setactive') { $script:CurrentPlan=$Arguments[1] }
    [pscustomobject]@{ExitCode=0;Status='PASS'}
}
$blocked=$false
try { Invoke-NetworkRepair set-power-plan -PlanGuid '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -Confirm:$false } catch { $blocked=$true }
Assert-True ($blocked -and $script:Changes.Count -eq 0) 'Unavailable plan cannot be forced'
$script:HighAvailable=$true
$null=Invoke-NetworkRepair set-power-plan -PlanGuid '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -Confirm:$false
Assert-True ($script:Changes.Count -eq 0) 'Power plan cancellation makes no changes'
$script:Answer='yes'
$null=Invoke-NetworkRepair set-power-plan -PlanGuid '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -Confirm:$false
Assert-True ($script:Changes.Count -eq 1 -and $script:CurrentPlan -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') 'Selected plan is activated and verified'
$script:Changes.Clear()
function Get-NetAdapter { param([switch]$Physical,$ErrorAction) [pscustomobject]@{Name='NIC[1]';InterfaceIndex=7;InterfaceGuid='test-nic-guid';Status='Up'} }
$script:Pm=[pscustomobject]@{AllowComputerToTurnOffDevice='Enabled';SelectiveSuspend='Enabled';DeviceSleepOnDisconnect='Unsupported';WakeOnMagicPacket='Enabled'}
function Get-NetAdapterPowerManagement { param($Name,$ErrorAction) $script:Pm }
function Set-NetAdapterPowerManagement {
    param($InputObject,$SelectiveSuspend,$DeviceSleepOnDisconnect,[switch]$NoRestart,$ErrorAction)
    Assert-True ($NoRestart -and $null -eq $DeviceSleepOnDisconnect) 'NIC change requests no restart and omits unsupported features'
    Assert-True ($InputObject.AllowComputerToTurnOffDevice -eq 'Disabled') 'NIC turn-off setting passed as modified input object'
    $script:Changes.Add('NIC')
    $script:Pm.SelectiveSuspend=$SelectiveSuspend
}
$script:Answer='n'
$null=Invoke-NetworkRepair nic-awake -InterfaceIndex 7 -Confirm:$false
Assert-True ($script:Changes.Count -eq 0 -and $script:Pm.AllowComputerToTurnOffDevice -eq 'Enabled') 'NIC cancellation leaves settings untouched'
$null=Invoke-NetworkRepair nic-awake -InterfaceIndex 7 -WhatIf
Assert-True ($script:Changes.Count -eq 0 -and $script:Pm.AllowComputerToTurnOffDevice -eq 'Enabled') 'NIC WhatIf leaves settings untouched'
$script:Answer='yes'
$result=@(Invoke-NetworkRepair nic-awake -InterfaceIndex 7 -Confirm:$false)
Assert-True ($script:Changes.Count -eq 1 -and $script:Pm.WakeOnMagicPacket -eq 'Enabled') 'NIC repair preserves Wake-on-LAN'
Assert-True (@($result | Where-Object { $_.Status -eq 'PASS' }).Count -eq 2) 'Supported NIC features verified after write'
$script:Pm=[pscustomobject]@{AllowComputerToTurnOffDevice='Unsupported';SelectiveSuspend='Unsupported';DeviceSleepOnDisconnect='Unsupported'}
$blocked=$false
try { Invoke-NetworkRepair nic-awake -InterfaceIndex 7 -Confirm:$false } catch { $blocked=$true }
Assert-True ($blocked -and $script:Changes.Count -eq 1) 'Unsupported NIC power management is blocked'
Write-Output "Power tests passed on PowerShell $($PSVersionTable.PSVersion); no actual system changes."
