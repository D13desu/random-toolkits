# Elevated read-only comparison on a live volume. Only an isolated TEMP fixture is created.
[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
$session=$null;$worker=$null;$report=[ordered]@{Status='Running';PowerShell=[string]$PSVersionTable.PSVersion}
function Save-Comparison {$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReportPath}
try {
    $fixture=Join-Path $env:TEMP ('toolkit-helper-compare-'+[guid]::NewGuid().ToString('N'))
    if([IO.Path]::GetPathRoot($fixture) -ne $Drive){throw 'TEMP fixture must be on the selected drive for this comparison.'}
    $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'nested'))
    [IO.File]::WriteAllBytes((Join-Path $fixture 'small.bin'),[byte[]]::new(17))
    [IO.File]::WriteAllBytes((Join-Path $fixture 'nested/large.bin'),[byte[]]::new(8193))
    $null=New-Item -ItemType HardLink -Path (Join-Path $fixture 'alias.bin') -Target (Join-Path $fixture 'nested/large.bin')
    $report.Fixture=$fixture;$startup=@()
    for($i=0;$i -lt 5;$i++){
        $timer=[Diagnostics.Stopwatch]::StartNew()
        $session=Start-DiskHelper (Join-Path $PSScriptRoot 'out/DiskHelper.exe') (Join-Path $PSScriptRoot 'out/manifest.json')
        $startup+=$timer.Elapsed.TotalMilliseconds
        if($i -lt 4){Stop-DiskHelper $session}
    }
    $report.HelperStartupMilliseconds=$startup;$report.Phase='Helper scan';Save-Comparison
    $null=Invoke-DiskHelper $session @{command='scan';path=$Drive;engine='mft'}
    $timer=[Diagnostics.Stopwatch]::StartNew();$last=0
    do {
        $status=Invoke-DiskHelper $session @{command='status'}
        if($status.state -eq 'ready'){break}
        if($timer.Elapsed.TotalSeconds -gt 600){throw 'Helper scan exceeded comparison time limit.'}
        if($timer.Elapsed.TotalSeconds-$last -gt 10){$report.Progress=$status;Save-Comparison;$last=$timer.Elapsed.TotalSeconds}
        Start-Sleep -Milliseconds 200
    } while($true)
    $report.Helper=$status.summary;$report.HelperWorkingSet=$status.workingSet
    $report.InterfaceWorkingSet=[Diagnostics.Process]::GetCurrentProcess().WorkingSet64
    $fixturePage=Invoke-DiskHelper $session @{command='list';path=$fixture;limit=20}
    $report.HelperFixture=$fixturePage;$report.FixturePageBytes=$session.LastResponseBytes
    $report.HelperRootPage=Invoke-DiskHelper $session @{command='list';limit=20}
    $report.RootPageBytes=$session.LastResponseBytes
    $null=Invoke-DiskHelper $session @{command='scan';path=$Drive;engine='mft'}
    $null=Invoke-DiskHelper $session @{command='cancel'}
    $cancelTimer=[Diagnostics.Stopwatch]::StartNew()
    do{$cancelled=Invoke-DiskHelper $session @{command='status'};if($cancelled.state -ne 'ready'){Start-Sleep -Milliseconds 100};if($cancelTimer.Elapsed.TotalSeconds -gt 60){throw 'Cancellation did not finish within 60 seconds.'}}while($cancelled.state -ne 'ready')
    if(-not $cancelled.summary.cancelled){throw 'MFT cancellation did not return partial results.'}
    $report.CancelMilliseconds=$cancelTimer.Elapsed.TotalMilliseconds
    Stop-DiskHelper $session
    # Release the helper process before allocating a second full-volume tree.
    $report.Phase='Embedded baseline';Save-Comparison
    . (Join-Path $PSScriptRoot '../../win/disk/Disk-Usage.ps1') -NoMenu
    $timer=[Diagnostics.Stopwatch]::StartNew();Initialize-DiskScanner
    $report.EmbeddedCompilationMilliseconds=$timer.Elapsed.TotalMilliseconds
    $worker=[RandomToolkits.DiskV10.MftScanner]::Start($Drive)
    $timer.Restart();$last=0
    while(-not $worker.Done){
        if($timer.Elapsed.TotalSeconds -gt 600){throw 'Embedded baseline exceeded comparison time limit.'}
        if($timer.Elapsed.TotalSeconds-$last -gt 10){$report.Progress=@{seconds=$timer.Elapsed.TotalSeconds;records=$worker.RecordsSeen};Save-Comparison;$last=$timer.Elapsed.TotalSeconds}
        Start-Sleep -Milliseconds 200
    }
    if($worker.Error){throw $worker.Error}
    $scan=$worker.Result;$node=$scan.Nodes[$scan.Root];$fixtureNode=$scan.Nodes[$fixture]
    $report.Baseline=[ordered]@{Seconds=$timer.Elapsed.TotalSeconds;Files=$scan.Files;Logical=$node.Bytes;Allocated=$node.Allocated;UnknownAllocations=$scan.MftUnknownAllocations;OmittedFiles=$scan.MftOmittedFiles;ApiVerified=$scan.MftApiVerified;ParseErrors=$scan.MftRecordErrors;Causes=$scan.IssueCounts}
    $report.BaselineWorkingSet=[Diagnostics.Process]::GetCurrentProcess().WorkingSet64
    $report.FixtureMatch=($fixturePage.logical -eq $fixtureNode.Bytes -and $fixturePage.allocated -eq $fixtureNode.Allocated -and $fixturePage.files -eq $fixtureNode.Files)
    if(-not $report.FixtureMatch -or $fixtureNode.Bytes -ne 8210 -or $fixtureNode.Files -ne 2){throw 'Fixture totals differ between helper and embedded engine.'}
    $baselineRows=@(Get-DiskChildren $scan $fixture | Select-Object Name,Kind,Bytes,Allocated)
    $helperRows=@($fixturePage.rows | Select-Object Name,Kind,Bytes,Allocated)
    if(($baselineRows | ConvertTo-Json -Compress) -ne ($helperRows | ConvertTo-Json -Compress)){throw 'Fixture cached rows differ between engines.'}
    $report.Status='PASS';$report.Phase='Complete';$report.Remove('Progress')
} catch {$report.Status='FAIL';$report.Error=$_.Exception.ToString()}
finally {if($worker){$worker.CancelRequested=$true};Stop-DiskHelper $session;Save-Comparison}
if($report.Status -ne 'PASS'){exit 1}
