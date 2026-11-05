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
    Write-Host 'Metadata figures are separate, non-additive observations: resident-file slots can overlap $MFT allocation. Non-DATA metadata is not fully measured; unknown values are lower bounds.' -ForegroundColor Yellow
    Write-Host '$BadClus allocation is unmeasured until its cluster mappings are validated; its header size is not counted as used space.'
    Write-Host 'The difference from volume-used bytes is not a measured NTFS-overhead total. Live scans and other tools may use different accounting rules.'
    $a.metadataSamples | Select-Object group,record,sequence,name,directory,knownDataAllocation,allocationUnknown | Format-Table -AutoSize | Out-Host
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
        Write-Host ('Page {0}/{1} | Sort: {2} | Number: folder | U: up | N/P: pages | S: sort | E: diagnostics | A: accounting | T: timings | 0: exit' -f ([int]($offset/20)+1),([math]::Max(1,[math]::Ceiling($page.total/20))),$sort)
        $choice=Read-Host 'Select';$number=0
        switch($choice.ToUpperInvariant()){
            '0'{return}
            'U'{if($page.parent){$current=$page.parent;$offset=0}}
            'N'{if($offset+20 -lt $page.total){$offset+=20}}
            'P'{$offset=[math]::Max(0,$offset-20)}
            'S'{$sort=switch($sort){'allocated'{'logical'}'logical'{'name'}default{if($Engine -eq 'mft'){'allocated'}else{'logical'}}};$offset=0}
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
} finally {Write-Progress -Activity 'C# helper scanning' -Completed;Stop-DiskHelper $session}
