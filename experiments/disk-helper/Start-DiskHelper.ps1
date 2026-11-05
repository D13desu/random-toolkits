[CmdletBinding()]
param([string]$Path,[ValidateSet('mft','native')][string]$Engine='mft',[string]$HelperDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
function Format-HelperBytes($Bytes) {
    if($null -eq $Bytes){return '-'}
    $value=[double]$Bytes
    foreach($unit in @('B','KiB','MiB','GiB','TiB','PiB')){if([math]::Abs($value) -lt 1024 -or $unit -eq 'PiB'){return ('{0:N1} {1}' -f $value,$unit)};$value/=1024}
}
$session=$null
try {
    $session=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') (Join-Path $HelperDirectory 'manifest.json')
    Write-Host ("`nDISK HELPER {0} | Engine {1} | {2} | READ ONLY" -f $session.Hello.version,$session.Hello.engineVersion,$session.Hello.architecture) -ForegroundColor Cyan
    if(-not $Path){
        $drives=@([IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.DriveType -eq 'Fixed'})
        for($i=0;$i -lt $drives.Count;$i++){Write-Host (' [{0}] {1} | Used {2} | Free {3}' -f ($i+1),$drives[$i].Name,(Format-HelperBytes ($drives[$i].TotalSize-$drives[$i].TotalFreeSpace)),(Format-HelperBytes $drives[$i].TotalFreeSpace))}
        $inputPath=Read-Host 'Drive number or path (Enter: first drive; 0: exit)'
        if($inputPath -eq '0'){return}
        $selection=0
        if([string]::IsNullOrWhiteSpace($inputPath) -and $drives.Count){$Path=$drives[0].Name}
        elseif([int]::TryParse($inputPath,[ref]$selection) -and $selection -ge 1 -and $selection -le $drives.Count){$Path=$drives[$selection-1].Name}
        else{$Path=$inputPath}
    }
    if($Path -match '^[A-Za-z]:$'){$Path+='\'}
    $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $null=Invoke-DiskHelper $session @{command='scan';path=$Path;engine=$Engine}
    Write-Host 'Q stops the scan and opens partial results. Ctrl+C exits.'
    do {
        $status=Invoke-DiskHelper $session @{command='status'}
        if($status.state -eq 'ready'){break}
        Write-Progress -Activity 'C# helper scanning' -Status ('{0} | {1:N0} records | {2:N0} files | {3:N1}s' -f $status.phase,$status.records,$status.files,$status.seconds)
        try {if(-not [Console]::IsInputRedirected -and [Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q'){$null=Invoke-DiskHelper $session @{command='cancel'}}} catch {}
        Start-Sleep -Milliseconds 200
    } while($true)
    Write-Progress -Activity 'C# helper scanning' -Completed
    $summary=$status.summary;$current=$summary.root;$offset=0;$sort=if($Engine -eq 'mft'){'allocated'}else{'logical'}
    while($true){
        $page=Invoke-DiskHelper $session @{command='list';path=$current;offset=$offset;limit=20;sort=$sort}
        Write-Host ("`nDISK HELPER {0} | {1}" -f $session.Hello.version,$page.path) -ForegroundColor Cyan
        Write-Host ('On disk: {0} | Logical: {1} | Files: {2:N0} | Scan: {3:N1}s' -f (Format-HelperBytes $page.allocated),(Format-HelperBytes $page.logical),$page.files,$summary.seconds)
        Write-Host ('Cache preparation: {0:N1}s | Ready: {1:N1}s' -f (($status.cleanupMilliseconds+$status.compactMilliseconds)/1000),$status.readySeconds)
        if($page.partial -or $page.allocationUnknown){Write-Host 'PARTIAL: displayed values may be lower bounds; E shows diagnostics.' -ForegroundColor Yellow}
        if($Engine -eq 'mft'){
            Write-Host ('Volume used: {0} | Accounted DATA: {1} | Difference: {2}' -f (Format-HelperBytes $summary.volumeUsed),(Format-HelperBytes $summary.allocated),(Format-HelperBytes ($summary.volumeUsed-$summary.allocated)))
            Write-Host ('API verified: {0:N0} | Unknown allocations: {1:N0} | Omitted files: {2:N0}' -f $summary.apiVerified,$summary.unknownAllocations,$summary.omittedFiles)
        }
        $rows=@($page.rows)
        for($i=0;$i -lt $rows.Count;$i++){
            $row=$rows[$i];$allocation=if($Engine -eq 'mft'){Format-HelperBytes $row.Allocated}else{'-'}
            if($row.AllocationUnknown){$allocation=if($row.Allocated -eq 0){'Unknown'}else{'>= '+$allocation}}
            Write-Host (' [{0,2}] {1,14} | {2,12} | {3,-4} {4}' -f ($i+1),$allocation,(Format-HelperBytes $row.Bytes),$row.Kind,$row.Name)
        }
        Write-Host ('Page {0}/{1} | Sort: {2} | Number: folder | U: up | N/P: pages | S: sort | E: diagnostics | T: timings | 0: exit' -f ([int]($offset/20)+1),([math]::Max(1,[math]::Ceiling($page.total/20))),$sort)
        $choice=Read-Host 'Select';$number=0
        switch($choice.ToUpperInvariant()){
            '0'{return}
            'U'{if($page.parent){$current=$page.parent;$offset=0}}
            'N'{if($offset+20 -lt $page.total){$offset+=20}}
            'P'{$offset=[math]::Max(0,$offset-20)}
            'S'{$sort=switch($sort){'allocated'{'logical'}'logical'{'name'}default{if($Engine -eq 'mft'){'allocated'}else{'logical'}}};$offset=0}
            'E'{
                $issues=Invoke-DiskHelper $session @{command='issues';limit=100}
                Write-Host 'Diagnostics include warnings on counted files; not every diagnostic is an omission.'
                $issues.causes.PSObject.Properties | ForEach-Object {[pscustomobject]@{Cause=$_.Name;Count=$_.Value}} | Format-Table | Out-Host
                $issues.rows | Format-List Path,Reason,Category | Out-Host
                $null=Read-Host 'Enter to return'
            }
            'T'{
                $profile=Invoke-DiskHelper $session @{command='profile'}
                if($null -eq $profile.scan){Write-Host 'Phase profiling is available for MFT scans.'}
                else {
                    Write-Host 'Samples mark phase boundaries. Managed memory includes objects awaiting collection.'
                    $profile.scan.samples | Select-Object @{n='Phase starting';e={$_.phase}},@{n='Elapsed s';e={[math]::Round($_.seconds,2)}},@{n='Managed GiB';e={[math]::Round($_.managedBytes/1GB,2)}},@{n='Working GiB';e={[math]::Round($_.workingSet/1GB,2)}} | Format-Table -AutoSize | Out-Host
                }
                $null=Read-Host 'Enter to return'
            }
            default{if([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $rows.Count -and $rows[$number-1].Kind -eq 'DIR'){$current=$rows[$number-1].Path;$offset=0}}
        }
    }
} finally {Write-Progress -Activity 'C# helper scanning' -Completed;Stop-DiskHelper $session}
