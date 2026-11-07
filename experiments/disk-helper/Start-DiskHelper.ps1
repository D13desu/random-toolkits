[CmdletBinding()]
param([string]$Path,[ValidateSet('auto','mft','native')][string]$Engine='auto',[string]$HelperDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
. (Join-Path $PSScriptRoot 'Helper-Ui.ps1')
$keyboard=Test-HelperConsole
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
function Format-HelperBytes($Bytes) {
    if($null -eq $Bytes){return '-'}
    $value=[double]$Bytes
    foreach($unit in @('B','KiB','MiB','GiB','TiB','PiB')){if([math]::Abs($value) -lt 1024 -or $unit -eq 'PiB'){return ('{0:N1} {1}' -f $value,$unit)};$value/=1024}
}
function Format-HelperSignedBytes($Bytes) {
    $value=[long]$Bytes
    if($value -eq 0){return '0 B'}
    return $(if($value -gt 0){'+'}else{'-'})+(Format-HelperBytes ([math]::Abs($value)))
}
function Show-HelperAccounting($Summary) {
    $a=$Summary.accounting
    if($null -eq $a){Write-Host 'Accounting comparison is available for MFT scans.';return}
    Write-Host ("`nVOLUME ACCOUNTING | {0}" -f $Summary.root) -ForegroundColor Cyan
    Write-Host ('Unique included files: {0:N0} | Additional hard-link paths: {1:N0} | Included file entries: {2:N0}' -f $a.uniqueFiles,$a.additionalLinks,$a.fileEntries)
    Write-Host ('Unique logical bytes: {0:N0} ({1})' -f $a.uniqueLogical,(Format-HelperBytes $a.uniqueLogical))
    Write-Host ('Logical bytes across all included file paths: {0:N0} ({1})' -f $a.logicalAcrossLinks,(Format-HelperBytes $a.logicalAcrossLinks))
    Write-Host 'LINK rows remain zero charged bytes. The path total above repeats each linked file size; it is not physical disk usage.'
    Write-Host ('Included-file information: {0:N0} | Metadata exclusion diagnostics: {1:N0} | Other problems/uncertainties: {2:N0}' -f $a.informationalDiagnostics,$a.metadataExclusionDiagnostics,$a.problemDiagnostics)
    Write-Host ('Observed core NTFS records (<16): {0:N0} | Known DATA allocation: {1:N0} bytes ({2}) | Unknown/incomplete: {3:N0}' -f $a.coreMetadataRecords,$a.coreKnownDataAllocation,(Format-HelperBytes $a.coreKnownDataAllocation),$a.coreUnknownAllocations)
    Write-Host ('Excluded metadata tree: {0:N0} files, {1:N0} directories | Known DATA allocation: {2:N0} bytes ({3}) | Unknown/incomplete: {4:N0}' -f $a.excludedMetadataFiles,$a.excludedMetadataDirectories,$a.excludedKnownDataAllocation,(Format-HelperBytes $a.excludedKnownDataAllocation),$a.excludedUnknownAllocations)
    $r=$Summary.reconciliation;$n=$Summary.nonDataAllocation
    if($r){
        Write-Host ('Resident DATA overlap inside $MFT: {0} | Metadata DATA outside resident slots: {1}' -f (Format-HelperBytes $r.includedResidentOverlap),(Format-HelperBytes $r.metadataDataPhysical))
        Write-Host ('Non-DATA NTFS allocation: {0} | Directory indexes: {1} | Reparse/other streams: {2}' -f (Format-HelperBytes $r.nonDataPhysical),(Format-HelperBytes $n.indexAllocation),(Format-HelperBytes $n.other))
        Write-Host ('Windows used clusters: {0} | Reserved: {1} (volume storage reserve: {2})' -f (Format-HelperBytes $r.windowsUsed),(Format-HelperBytes $r.reserved),(Format-HelperBytes $r.volumeStorageReserve))
        Write-Host ('Reconciled unavailable space: {0} | Live residual: {1} ({2:N0} bytes)' -f (Format-HelperBytes $r.reconciled),(Format-HelperBytes $r.residual),$r.residual) -ForegroundColor $(if([math]::Abs($r.residual) -le 1MB){'Green'}else{'Yellow'})
        Write-Host 'Folder rows remain attributable allocation. NTFS metadata and Windows reservations are volume-wide and are not assigned to folders.'
    }else{Write-Host 'Extended volume reconciliation is unavailable on this Windows version.' -ForegroundColor Yellow}
    Write-Host '$BadClus allocation is unmeasured until its cluster mappings are validated; its header size is not counted as used space.'
    $a.metadataSamples | Select-Object group,record,sequence,name,directory,knownDataAllocation,allocationUnknown | Format-Table -AutoSize | Out-Host
}
:drives while ($true) {
$session=$null
try {
    $session=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') (Join-Path $HelperDirectory 'manifest.json')
    Write-Host ("`nDISK USAGE {0} | Engine {1} | {2} | READ ONLY" -f $session.Hello.version,$session.Hello.engineVersion,$session.Hello.architecture) -ForegroundColor Cyan
    if(-not $Path){
        $drives=@([IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.DriveType -eq 'Fixed'})
        for($i=0;$i -lt $drives.Count;$i++){Write-Host (' [{0}] {1} | Used {2} | Free {3}' -f ($i+1),$drives[$i].Name,(Format-HelperBytes ($drives[$i].TotalSize-$drives[$i].TotalFreeSpace)),(Format-HelperBytes $drives[$i].TotalFreeSpace))}
        $inputPath=Read-Host 'Drive number or path (Enter: first drive; B / 0: back to launcher)'
        if($null -eq $inputPath -or $inputPath.Trim() -in @('0','B')){return}
        $selection=0
        if([string]::IsNullOrWhiteSpace($inputPath) -and $drives.Count){$Path=$drives[0].Name}
        elseif([int]::TryParse($inputPath,[ref]$selection) -and $selection -ge 1 -and $selection -le $drives.Count){$Path=$drives[$selection-1].Name}
        else{$Path=$inputPath}
    }
    try {
        if($Path -match '^[A-Za-z]:$'){$Path+='\'}
        $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $scanEngine=Get-HelperScanEngine -Path $Path -Requested $Engine
        Write-Host ('Scan mode: '+$scanEngine+' | '+$Path)
        if($scanEngine -eq 'native'){Write-Host 'Native scan: logical sizes; inaccessible entries and reparse points may be excluded. Elevated local NTFS drive roots use MFT in Auto mode.'}
        $null=Invoke-DiskHelper $session @{command='scan';path=$Path;engine=$scanEngine}
    } catch {Write-Warning $_.Exception.Message;continue drives}
    Write-Host 'Q: stop and browse partial results | B: cancel and return to drives'
    do {
        $status=Invoke-DiskHelper $session @{command='status'}
        if($status.state -eq 'ready'){break}
        Write-Progress -Activity 'C# helper scanning' -Status ('{0} | {1:N0} records | {2:N0} files | {3:N1}s' -f $status.phase,$status.records,$status.files,$status.seconds)
        $key=$null
        try {if(-not [Console]::IsInputRedirected -and [Console]::KeyAvailable){$key=[Console]::ReadKey($true).Key}} catch {}
        if($key -eq 'B'){continue drives}
        if($key -eq 'Q'){$null=Invoke-DiskHelper $session @{command='cancel'}}
        Start-Sleep -Milliseconds 200
    } while($true)
    Write-Progress -Activity 'C# helper scanning' -Completed
    $summary=$status.summary;$current=$summary.root;$offset=0;$selected=0;$lastView='';$sort=if($scanEngine -eq 'mft'){'allocated'}else{'logical'}
    $live=$false;$liveTick=$false;$lastLiveSignature=$null
    while($true){
        $requestedView=$current+'|'+$offset+'|'+$sort
        $watchPath=$null
        if($live -and $requestedView -eq $lastView -and $rows.Count -and $selected -lt $rows.Count -and $rows[$selected].Kind -eq 'DIR'){$watchPath=$rows[$selected].Path}
        $page=Invoke-DiskHelper $session @{command='list';path=$current;offset=$offset;limit=20;sort=$sort;live=$live;watchPath=$watchPath}
        $view=$current+'|'+$offset+'|'+$sort
        if($view -ne $lastView){$selected=0;$lastView=$view}
        $rows=@($page.rows)
        $liveSignature=if($live){($rows | ForEach-Object {'{0}|{1}|{2}|{3}|{4}' -f $_.Path,$_.Bytes,$_.Allocated,$_.LiveState,$_.Modified}) -join "`n"}else{$null}
        $redraw=-not ($liveTick -and $liveSignature -eq $lastLiveSignature)
        $liveTick=$false
        if($redraw){
            $lastLiveSignature=$liveSignature
            if($keyboard){Clear-Host}
            Write-Host ("`nDISK USAGE {0} | {1} | {2}" -f $session.Hello.version,$scanEngine.ToUpperInvariant(),$page.path) -ForegroundColor Cyan
            $available=Get-HelperAvailableBytes $page.path
            $availableText=if($null -eq $available){'Unavailable'}else{Format-HelperBytes $available}
            Write-Host ('On disk: {0} | Logical: {1} | Available: {2} | Files: {3:N0} | Scan: {4:N1}s' -f (Format-HelperBytes $page.allocated),(Format-HelperBytes $page.logical),$availableText,$page.files,$summary.seconds)
            if($scanEngine -eq 'native'){Write-Host 'Native scan: logical sizes only; physical allocation is not measured.'}
            Write-Host ('Cache preparation: {0:N1}s | Ready: {1:N1}s' -f (($status.cleanupMilliseconds+$status.compactMilliseconds)/1000),$status.readySeconds)
            if($page.partial -or $page.allocationUnknown){Write-Host 'PARTIAL: displayed values may be lower bounds; see Reports > Scan diagnostics.' -ForegroundColor Yellow}
            if($scanEngine -eq 'mft'){
                if($current -eq $summary.root){
                    if($summary.reconciliation){Write-Host ('Volume unavailable: {0} | Reconciled: {1} | Live residual: {2} (see Reports)' -f (Format-HelperBytes $summary.reconciliation.windowsUnavailable),(Format-HelperBytes $summary.reconciliation.reconciled),(Format-HelperBytes $summary.reconciliation.residual))}
                    else{Write-Host ('Volume used: {0} | Included allocation: {1} | Unreconciled: {2} (see Reports)' -f (Format-HelperBytes $summary.volumeUsed),(Format-HelperBytes $summary.allocated),(Format-HelperBytes ($summary.volumeUsed-$summary.allocated)))}
                }
                Write-Host ('API verified: {0:N0} | Unknown allocations: {1:N0} | Omitted files: {2:N0}' -f $summary.apiVerified,$summary.unknownAllocations,$summary.omittedFiles)
            }
            if($live){Write-Host 'LIVE: visible files and directories are checked in turn; page totals, sorting and reconciliation remain cached until R.' -ForegroundColor Green}
            Write-Host '     ON DISK       | LOGICAL      | MODIFIED         | TYPE NAME' -ForegroundColor DarkGray
            for($i=0;$i -lt $rows.Count;$i++){
                $row=$rows[$i];$allocation=if($scanEngine -eq 'mft'){Format-HelperBytes $row.Allocated}else{'-'}
                if($row.AllocationUnknown){$allocation=if($row.Allocated -eq 0){'Unknown'}else{'>= '+$allocation}}
                $marker=if($i -eq $selected){'>'}else{' '}
                $liveColor=switch([string]$row.LiveState){'grown'{'Green'}'shrunk'{'Yellow'}'changed'{'Yellow'}'replaced'{'Yellow'}'deleted'{'Red'}'unavailable'{'DarkYellow'}'checking'{'DarkCyan'}default{$null}}
                $color=if($liveColor){$liveColor}elseif($i -eq $selected){'Cyan'}else{'Gray'}
                $modified=if($row.Modified){[string]$row.Modified}else{'-'}
                $change=''
                if($row.LiveState -eq 'deleted'){$change=' [DELETED]'}
                elseif($row.LiveState -eq 'unavailable'){$change=' [UNAVAILABLE]'}
                elseif($row.LiveState -eq 'checking'){$change=' [CHECKING]'}
                elseif($row.LiveState -eq 'replaced'){$change=' [REPLACED]'}
                elseif($row.LiveState -in @('grown','shrunk','changed')){
                    $parts=@();if($row.LogicalDelta -ne 0){$parts+='logical '+(Format-HelperSignedBytes $row.LogicalDelta)}
                    if($scanEngine -eq 'mft' -and $row.AllocatedDelta -ne 0){$parts+='disk '+(Format-HelperSignedBytes $row.AllocatedDelta)}
                    $change=' ['+($parts -join ', ')+']'
                }
                Write-Host ('{0}[{1,2}] {2,14} | {3,12} | {4,-16} | {5,-4} {6}{7}' -f $marker,($i+1),$allocation,(Format-HelperBytes $row.Bytes),$modified,$row.Kind,$row.Name,$change) -ForegroundColor $color
            }
            Write-Host ('Page {0}/{1} | Sort: {2}' -f ([int]($offset/20)+1),([math]::Max(1,[math]::Ceiling($page.total/20))),$sort)
            if($keyboard){
                Write-Host 'Up/Down: select | Enter: open | Left/Esc: back | Ctrl+Enter: Explorer'
                Write-Host ('PgUp/PgDn: pages | S: sort | L: live {0} | R: refresh | F1: reports' -f $(if($live){'ON'}else{'off'}))
            }else{Write-Host 'Number: folder | B: back | N/P: pages | S: sort | L: live | R: refresh | O: Explorer | H: reports | 0: drives'}
        }
        $choice=Read-HelperChoice $keyboard $live;$number=0
        if($choice -in @('@REPORTS','H')){$choice=Read-HelperReport $keyboard}
        switch(([string]$choice).Trim().ToUpperInvariant()){
            '@LIVE_TICK'{$liveTick=$true}
            '@UP'{if($selected -gt 0){$selected--}elseif($offset -gt 0){$offset=[math]::Max(0,$offset-20)}}
            '@DOWN'{if($selected+1 -lt $rows.Count){$selected++}elseif($offset+20 -lt $page.total){$offset+=20}}
            '@ENTER'{if($rows.Count -and $rows[$selected].Kind -eq 'DIR'){$current=$rows[$selected].Path;$offset=0}}
            {$_ -in @('@EXPLORER','O')}{
                $openPath=$current
                if($rows.Count -and $rows[$selected].Kind -eq 'DIR'){$openPath=$rows[$selected].Path}
                try {Open-HelperDirectory $openPath} catch {Write-Warning $_.Exception.Message;$null=Read-Host 'Enter to return'}
            }
            '0'{continue drives}
            'B'{if($page.parent){$current=$page.parent;$offset=0}else{continue drives}}
            'U'{if($page.parent){$current=$page.parent;$offset=0}}
            'N'{if($offset+20 -lt $page.total){$offset+=20}}
            'P'{$offset=[math]::Max(0,$offset-20)}
            'S'{$sort=switch($sort){'allocated'{'logical'}'logical'{'name'}default{if($scanEngine -eq 'mft'){'allocated'}else{'logical'}}};$offset=0}
            'L'{
                if(-not $keyboard){Write-Host 'Live polling requires an interactive ConsoleHost. Use R for an updated snapshot.' -ForegroundColor Yellow;$null=Read-Host 'Enter to return'}
                else{$live=-not $live;$null=Invoke-DiskHelper $session @{command='live';enabled=$live};$lastLiveSignature=$null}
            }
            'R'{
                $live=$false;$liveTick=$false;$lastLiveSignature=$null
                $refreshRoot=$summary.root;$returnPath=$current
                $newSession=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') (Join-Path $HelperDirectory 'manifest.json')
                Stop-DiskHelper $session;$session=$newSession
                $null=Invoke-DiskHelper $session @{command='scan';path=$refreshRoot;engine=$scanEngine}
                Write-Host ('Refreshing {0} with {1} scan. Q opens partial results.' -f $refreshRoot,$scanEngine) -ForegroundColor Cyan
                do{
                    $status=Invoke-DiskHelper $session @{command='status'}
                    if($status.state -eq 'ready'){break}
                    Write-Progress -Activity 'Refreshing disk snapshot' -Status ('{0} | {1:N0} records | {2:N0} files | {3:N1}s' -f $status.phase,$status.records,$status.files,$status.seconds)
                    $refreshKey=$null;try{if(-not [Console]::IsInputRedirected -and [Console]::KeyAvailable){$refreshKey=[Console]::ReadKey($true).Key}}catch{}
                    if($refreshKey -eq 'Q'){$null=Invoke-DiskHelper $session @{command='cancel'}}
                    Start-Sleep -Milliseconds 200
                }while($true)
                Write-Progress -Activity 'Refreshing disk snapshot' -Completed
                $summary=$status.summary
                try{$null=Invoke-DiskHelper $session @{command='list';path=$returnPath;limit=1};$current=$returnPath}catch{$current=$summary.root}
                $offset=0;$selected=0;$lastView=''
            }
            'E'{
                $issues=Invoke-DiskHelper $session @{command='issues';limit=100}
                Write-Host 'Included-file information does not mark totals PARTIAL. Metadata exclusions and other incomplete results remain flagged. A shows volume accounting.'
                if($summary.accounting -and $summary.accounting.problemDiagnostics -eq 0 -and $summary.accounting.metadataExclusionDiagnostics -gt 0){Write-Host 'The remaining PARTIAL flag is from intentional metadata exclusions.'}
                if($summary.accounting){$summary.accounting.categories | Select-Object cause,count,kind | Format-Table -AutoSize | Out-Host}
                else {$issues.causes.PSObject.Properties | ForEach-Object {[pscustomobject]@{Cause=$_.Name;Count=$_.Value}} | Format-Table | Out-Host}
                $issues.rows | Format-List Path,Reason,Category | Out-Host
                $null=Read-Host 'Enter to return'
            }
            'A'{Show-HelperAccounting $summary;$null=Read-Host 'Enter to return'}
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
} finally {Write-Progress -Activity 'C# helper scanning' -Completed;Stop-DiskHelper $session;$Path=$null}
}
