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
    $all=@();$selected=0;$filter='';$reviewOnly=$false;$reload=$true;$keyboard=Test-PcEventKeyboard;$size=10
    while($true){
        if($reload){$all=if($Kind -eq 'Startup'){@(Get-PcStartupEntries)}else{@(Get-PcScheduledTaskEntries)};$reload=$false;$selected=0}
        $rows=@($all | Where-Object {(-not $reviewOnly -or $_.Status -in @('REVIEW','UNAVAILABLE')) -and (-not $filter -or ($_.Name+' '+$_.Location).IndexOf($filter,[StringComparison]::OrdinalIgnoreCase) -ge 0)} | Sort-Object @{Expression={if($_.Status -eq 'REVIEW'){0}elseif($_.Status -eq 'UNAVAILABLE'){1}else{2}}},Name)
        $selected=[math]::Max(0,[math]::Min($selected,$rows.Count-1));$page=[int][math]::Floor($selected/[double]$size)
        if($keyboard){Clear-Host}
        Write-Host ("`n{0} INSPECTION | {1}/{2} entries | READ ONLY" -f $Kind,$rows.Count,$all.Count) -ForegroundColor Cyan
        if($Kind -eq 'Startup'){Write-Host 'Win32 startup inventory is not exhaustive; packaged startup apps and disabled/approved state may be absent. No entry is executed.'}
        else{Write-Host 'Visible tasks only; permissions may limit inventory. Nonzero results are review items, not proof of current failure. No task is run or changed.'}
        Write-Host ("Filter: {0} | Review/unavailable only: {1}" -f $filter,$reviewOnly)
        for($i=$page*$size;$i -lt [math]::Min($rows.Count,($page+1)*$size);$i++){
            $marker=if($i -eq $selected){'>'}else{' '}
            Write-Host ('{0}[{1}] {2,-11} {3} | {4}' -f $marker,($i+1),$rows[$i].Status,$rows[$i].Name,$rows[$i].State)
        }
        Write-Host 'Up/Down: select | Enter: details | N/P: pages | F: name/path filter | C: review/all | R: refresh | B/Esc: back'
        $answer=Read-PcEventChoice $keyboard 'Number: details | N/P | F: filter | C: review/all | R: refresh | B / 0: back'
        $open=-1
        switch(([string]$answer).Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            '@UP'{$selected=[math]::Max(0,$selected-1)} '@DOWN'{$selected=[math]::Max(0,[math]::Min($rows.Count-1,$selected+1))}
            '@HOME'{$selected=0} '@END'{$selected=[math]::Max(0,$rows.Count-1)}
            'N'{if(($page+1)*$size -lt $rows.Count){$selected=($page+1)*$size}} 'P'{$selected=[math]::Max(0,($page-1)*$size)}
            'R'{$reload=$true} 'C'{$reviewOnly=-not $reviewOnly;$selected=0}
            'F'{try{$filter=Read-PcInput 'Name or location contains [blank: all]';$selected=0}catch [OperationCanceledException]{}}
            '@ENTER'{if($rows.Count){$open=$selected}}
            default{$n=0;if([int]::TryParse($answer,[ref]$n) -and $n -ge 1 -and $n -le $rows.Count){$open=$n-1}}
        }
        if($open -ge 0){$rows[$open] | Format-List * | Out-Host;$null=Read-Host 'Enter to return'}
    }
}
function Start-PcStartupTaskMenu {
    while($true){
        Write-Host "`nSTARTUP & SCHEDULED TASKS | READ ONLY" -ForegroundColor Cyan
        Write-Host ' [1] Startup entries   [2] Scheduled tasks   [3] Task Scheduler event log'
        Write-Host ' [4] Open Windows Startup Apps settings   [5] Open Task Scheduler'
        Write-Host ' [B / 0] Back'
        $answer=Read-Host 'Select'
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
        }catch [OperationCanceledException]{}catch{Write-Warning $_.Exception.Message}
    }
}
