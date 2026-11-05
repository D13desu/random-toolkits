[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath)
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
        if($timer.Elapsed.TotalSeconds -gt 30){throw 'No bounded scan progress within 30 seconds.'}
        if($progress.records -lt 50000){Start-Sleep -Milliseconds 50}
    } while($progress.records -lt 50000)
    $report.RecordsBeforeCancel=$progress.records
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
    $report.Status='PASS';$report.Summary=$progress.summary
} catch {$report.Error=$_.Exception.ToString()}
finally {Stop-DiskHelper $session;$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath}
if($report.Status -ne 'PASS'){exit 1}
