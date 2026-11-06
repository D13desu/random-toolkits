[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath,[string]$HelperDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
$session=$null;$report=[ordered]@{Status='Running'}
try {
    $session=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') (Join-Path $HelperDirectory 'manifest.json')
    $null=Invoke-DiskHelper $session @{command='scan';engine='mft';path=$Drive}
    $timer=[Diagnostics.Stopwatch]::StartNew();$last=0
    do {
        $state=Invoke-DiskHelper $session @{command='status'}
        if($state.state -eq 'ready'){break}
        if($timer.Elapsed.TotalSeconds -gt 600){throw 'Scan timeout.'}
        if($timer.Elapsed.TotalSeconds-$last -ge 10){$report.Progress=$state;$report | ConvertTo-Json -Depth 5 | Set-Content $ReportPath;$last=$timer.Elapsed.TotalSeconds}
        Start-Sleep -Milliseconds 200
    }while($true)
    $report.Summary=$state.summary
    $report.Profile=Invoke-DiskHelper $session @{command='profile'}
    if($report.Profile.scan.phase -ne 'ready'){throw 'Profile did not reach ready.'}
    $previous=-1
    foreach($sample in $report.Profile.scan.samples){
        if($sample.seconds -lt $previous -or $sample.managedBytes -lt 0 -or $sample.workingSet -lt 0){throw 'Invalid phase measurements.'}
        $previous=$sample.seconds
    }
    $report.ReadySeconds=$state.readySeconds
    $report.CleanupMilliseconds=$state.cleanupMilliseconds
    $report.PreCompactCleanupMilliseconds=$state.preCompactCleanupMilliseconds
    $report.FinalCleanupMilliseconds=$state.finalCleanupMilliseconds
    $report.CompactMilliseconds=$state.compactMilliseconds
    $before=Invoke-DiskHelper $session @{command='list';limit=20}
    $report.Memory=Invoke-DiskHelper $session @{command='memory';collect=$true}
    $after=Invoke-DiskHelper $session @{command='list';limit=20}
    if(($before | ConvertTo-Json -Depth 5 -Compress) -ne ($after | ConvertTo-Json -Depth 5 -Compress)){throw 'Memory collection changed results.'}
    $report.Status='PASS';$report.Remove('Progress')
}catch{$report.Status='FAIL';$report.Error=$_.Exception.ToString()}
finally{Stop-DiskHelper $session;$report | ConvertTo-Json -Depth 6 | Set-Content $ReportPath}
if($report.Status -ne 'PASS'){exit 1}
