[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath,[switch]$DuringReconstruction)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
$session=$null;$report=[ordered]@{Status='FAIL'}
try {
    $session=Start-DiskHelper (Join-Path $PSScriptRoot 'out/DiskHelper.exe') (Join-Path $PSScriptRoot 'out/manifest.json')
    $null=Invoke-DiskHelper $session @{command='scan';path=$Drive;engine='mft'}
    $timer=[Diagnostics.Stopwatch]::StartNew()
    do {
        $progress=Invoke-DiskHelper $session @{command='status'}
        if($progress.state -eq 'ready'){throw 'Volume finished before the mid-scan cancellation test.'}
        if($timer.Elapsed.TotalSeconds -gt 60){throw 'Target scan phase did not arrive within 60 seconds.'}
        $target=if($DuringReconstruction){$progress.phase -eq 'file paths and API verification'}else{$progress.records -ge 50000}
        if(-not $target){Start-Sleep -Milliseconds 50}
    } while(-not $target)
    $report.RecordsBeforeCancel=$progress.records
    $report.PhaseBeforeCancel=$progress.phase
    $null=Invoke-DiskHelper $session @{command='cancel'};$timer.Restart()
    do {
        $progress=Invoke-DiskHelper $session @{command='status'}
        if($progress.state -ne 'ready'){Start-Sleep -Milliseconds 50}
        if($timer.Elapsed.TotalSeconds -gt 60){throw 'Cancelled scan did not settle within 60 seconds.'}
    } while($progress.state -ne 'ready')
    $report.CancelMilliseconds=$timer.Elapsed.TotalMilliseconds
    if(-not $progress.summary.cancelled -or -not $progress.summary.partial){throw 'Cancelled results are not explicitly partial.'}
    $page=Invoke-DiskHelper $session @{command='list';limit=20}
    if(-not $page.partial -or @($page.rows).Count -gt 20){throw 'Partial navigation or page bound failed.'}
    if($DuringReconstruction){
        if(@($page.rows | Where-Object {-not $_.Partial}).Count){throw 'Late cancellation did not mark every root row partial.'}
        # Check a file-bearing folder too: directory flags alone do not prove packed file flags survived.
        $queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($progress.summary.root);$checkedFile=$false;$visited=0
        while($queue.Count -and -not $checkedFile -and $visited -lt 100){
            $folder=$queue.Dequeue();$visited++
            $listing=Invoke-DiskHelper $session @{command='list';path=$folder;limit=100;sort='name'}
            foreach($row in $listing.rows){if(-not $row.Partial){throw 'Late partial flag lost below root.'};if($row.Kind -eq 'DIR'){$queue.Enqueue($row.Path)}else{$checkedFile=$true}}
        }
        if(-not $checkedFile){throw 'No file row available to validate late cancellation.'}
        $report.FileRowsPartial=$true
    }
    $report.Status='PASS';$report.Summary=$progress.summary
} catch {$report.Error=$_.Exception.ToString()}
finally {Stop-DiskHelper $session;$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath}
if($report.Status -ne 'PASS'){exit 1}
