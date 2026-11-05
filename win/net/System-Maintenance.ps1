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
    while($true){
        $Row | Format-List * | Out-Host
        try{
            $service=Get-Service -Name $Row.Name -ErrorAction Stop | Where-Object Name -EQ $Row.Name
            Write-Host ('Requires: '+($service.ServicesDependedOn.Name -join ', '))
            Write-Host ('Dependents: '+($service.DependentServices.Name -join ', '))
        }catch{Write-Warning $_.Exception.Message}
        Write-Host '[1] Start  [2] Stop  [3] Restart (changes require administrator and confirmation)'
        Write-Host '[E] Related Service Control Manager events (last 24h; message match)  [B/0] Back'
        $answer=Read-Host 'Select'
        if($null -eq $answer -or $answer.Trim() -in @('B','0')){return}
        try{
            switch($answer.Trim()){
                '1'{Invoke-PcServiceAction $Row.Name Start}
                '2'{Invoke-PcServiceAction $Row.Name Stop}
                '3'{Invoke-PcServiceAction $Row.Name Restart}
                'E'{Start-PcEventBrowser -DefaultLog System -Quick -InitialProvider 'Service Control Manager' -InitialText $Row.DisplayName}
                default{Write-Warning 'Choose a listed option.'}
            }
            $updated=@(Get-PcServiceInventory | Where-Object Name -EQ $Row.Name)
            if(-not $updated.Count){Write-Warning 'Service no longer exists.';return};$Row=$updated[0]
        }catch{Write-Warning $_.Exception.Message}
    }
}
function Start-PcServices {
    $selected=0;$filter='';$reload=$true;$keyboard=Test-PcEventKeyboard;$size=10
    while($true){
        try{if($reload){$all=@(Get-PcServiceInventory);$reload=$false}}catch{Write-Warning $_.Exception.Message;return}
        $rows=@($all | Where-Object {(-not $filter) -or (($_.Name+' '+$_.DisplayName+' '+$_.PathName).IndexOf($filter,[StringComparison]::OrdinalIgnoreCase) -ge 0)})
        $selected=[math]::Max(0,[math]::Min($selected,$rows.Count-1));$page=[int][math]::Floor($selected/[double]$size)
        if($keyboard){Clear-Host}
        Write-Host ("`nSERVICES | {0} matches | Filter: {1}" -f $rows.Count,$filter) -ForegroundColor Cyan
        for($i=$page*$size;$i -lt [math]::Min($rows.Count,($page+1)*$size);$i++){
            $row=$rows[$i];$marker=if($i -eq $selected){'>'}else{' '}
            Write-Host ('{0}[{1}] {2} | {3} | {4} ({5})' -f $marker,($i+1),$row.State,$row.StartMode,$row.DisplayName,$row.Name)
            Write-Host ('    '+($row.PathName -replace '[\x00-\x1F\x7F]',' '))
        }
        Write-Host 'Arrows: select | Enter: details/actions | N/P: pages | F: filter | R: refresh | B/Esc: back'
        $answer=Read-PcEventChoice $keyboard 'Select';$open=-1
        if($null -eq $answer){return}
        switch($answer.Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            '@UP'{$selected=[math]::Max(0,$selected-1)} '@DOWN'{$selected=[math]::Min($rows.Count-1,$selected+1)}
            '@HOME'{$selected=0} '@END'{$selected=$rows.Count-1}
            'N'{if(($page+1)*$size -lt $rows.Count){$selected=($page+1)*$size}} 'P'{$selected=[math]::Max(0,($page-1)*$size)}
            'F'{try{$filter=Read-PcInput 'Name or executable path contains [blank: all]';$selected=0}catch [OperationCanceledException]{}}
            'R'{$reload=$true}
            '@ENTER'{if($rows.Count){$open=$selected}}
            default{$n=0;if([int]::TryParse($answer,[ref]$n) -and $n -ge 1 -and $n -le $rows.Count){$open=$n-1}}
        }
        if($open -ge 0){Show-PcServiceDetails $rows[$open];$reload=$true}
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
    while($true){
        Write-Host "`nWINDOWS REPAIR CENTRE | Administrator required for checks and repairs" -ForegroundColor Cyan
        Write-Host '[1] DISM CheckHealth - previously recorded corruption (quick)'
        Write-Host '[2] DISM ScanHealth - scan component store, no repair'
        Write-Host '[3] SFC verify-only - check protected system files, no repair'
        Write-Host '[4] DISM RestoreHealth - REPAIR component store'
        Write-Host '[5] SFC scannow - REPAIR protected system files'
        Write-Host 'Suggested repair order: RestoreHealth, review result, then SFC scannow. Each repair is selected separately.'
        Write-Host '[B/0] Back'
        $answer=Read-Host 'Select'
        if($null -eq $answer -or $answer.Trim() -in @('B','0')){return}
        $action=switch($answer.Trim()){'1'{'CheckHealth'} '2'{'ScanHealth'} '3'{'VerifyFiles'} '4'{'RestoreHealth'} '5'{'RepairFiles'}}
        if(-not $action){Write-Warning 'Choose a listed option.';continue}
        try{Invoke-PcWindowsRepair $action}catch{Write-Warning $_.Exception.Message}
        $null=Read-Host 'Enter to return'
    }
}
