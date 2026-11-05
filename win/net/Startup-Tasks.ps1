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
function Start-PcStartupTaskBrowser([ValidateSet('Startup','Task')][string]$Kind) {
    $state=@{};$reviewOnly=$false;$reload=$true;$all=@()
    while($true){
        if($reload){$all=if($Kind -eq 'Startup'){@(Get-PcStartupEntries)}else{@(Get-PcScheduledTaskEntries)};$reload=$false}
        $rows=@($all | Where-Object {-not $reviewOnly -or $_.Status -in @('REVIEW','UNAVAILABLE')} | Sort-Object @{Expression={if($_.Status -eq 'REVIEW'){0}elseif($_.Status -eq 'UNAVAILABLE'){1}else{2}}},Name)
        $menu=@(foreach($row in $rows){
            $detail=if($Kind -eq 'Startup'){@('Command: '+$row.Command; 'Source: '+$row.Location+' | Path: '+$row.PathStatus)}else{@($row.Location+' | '+$row.State;'Result: '+$row.Result+' | '+$row.ResultMeaning)}
            [pscustomobject]@{Id=($row.Location+'|'+$row.Name+'|'+$row.User+'|'+$row.Command);Label=($row.Status+' | '+$row.Name);Detail=$detail;SearchText=($row.Command+' '+$row.Executable);Data=$row}
        })
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
