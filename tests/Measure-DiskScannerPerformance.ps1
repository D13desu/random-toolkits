# Optional benchmark: creates an isolated 20,000-file fixture in TEMP. No drive-wide scan.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
$ProgressPreference='SilentlyContinue'
$root=Join-Path $env:TEMP ('toolkit-disk-benchmark-'+[guid]::NewGuid().ToString('N'))
Write-Output 'Creating benchmark fixture (40 folders, 20,000 small files)...'
for ($d=0; $d -lt 40; $d++) {
    $folder=Join-Path $root ('folder-'+$d)
    $null=[IO.Directory]::CreateDirectory($folder)
    for ($f=0; $f -lt 500; $f++) { [IO.File]::WriteAllBytes((Join-Path $folder ('file-'+$f+'.bin')),[byte[]]::new(128)) }
}
$timer=[Diagnostics.Stopwatch]::StartNew()
Initialize-DiskScanner
$compileMs=$timer.Elapsed.TotalMilliseconds
# Warm both engines once, then alternate order across measured passes.
$null=Measure-DiskTree -LiteralPath $root -Engine Native
$null=Measure-DiskTree -LiteralPath $root -Engine PowerShell
$measurements=New-Object 'System.Collections.Generic.List[object]'
foreach ($engine in @('Native','PowerShell','PowerShell','Native','Native','PowerShell')) {
    $timer.Restart()
    $result=Measure-DiskTree -LiteralPath $root -Engine $engine
    $elapsed=$timer.Elapsed.TotalMilliseconds
    if ($result.Files -ne 20000 -or $result.Nodes[$root].Bytes -ne 2560000 -or $result.IssueCount -ne 0) { throw 'Benchmark produced incorrect totals' }
    $measurements.Add([pscustomobject]@{Engine=$engine;Milliseconds=$elapsed})
}
$native=@($measurements | Where-Object Engine -eq Native | Sort-Object Milliseconds)[1].Milliseconds
$fallback=@($measurements | Where-Object Engine -eq PowerShell | Sort-Object Milliseconds)[1].Milliseconds
$worker=[RandomToolkits.DiskV3.Scanner]::Start($root)
$worker.CancelRequested=$true
while (-not $worker.Done) { Start-Sleep -Milliseconds 10 }
if ($worker.Error -or -not $worker.Result.Cancelled -or -not $worker.Result.Nodes[$root].Partial) { throw 'Cancellation did not produce marked partial results' }
[pscustomobject]@{PowerShell=[string]$PSVersionTable.PSVersion;Files=20000;Folders=41;CompilationMs=[math]::Round($compileMs,1);NativeMedianMs=[math]::Round($native,1);OldMedianMs=[math]::Round($fallback,1);Speedup=[math]::Round($fallback/$native,1);Cancellation='PASS';Fixture=$root;Method='Warm filesystem cache, 3 samples per engine, alternating order; includes UI polling overhead'} | Format-List
