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
