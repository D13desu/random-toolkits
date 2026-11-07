[CmdletBinding()]
param([string]$ReportPath,[string]$HelperDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
if(-not $HelperDirectory){$HelperDirectory=Join-Path $PSScriptRoot 'out'}
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output ('PASS: '+$message)}
$session=$null;$report=[ordered]@{Status='FAIL';PowerShell=[string]$PSVersionTable.PSVersion}
try {
    $fixture=Join-Path $env:TEMP ('toolkit-helper-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'nested'))
    [IO.File]::WriteAllBytes((Join-Path $fixture 'nested/large.bin'),[byte[]]::new(20000))
    (Get-Item -LiteralPath (Join-Path $fixture 'nested')).LastWriteTime=[datetime]'2020-02-03T12:00:00'
    $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'second'))
    [IO.File]::WriteAllBytes((Join-Path $fixture 'second/other.bin'),[byte[]]::new(5000))
    $unicodeName='caf'+[char]0xE9+'-'+[char]0x6F22+[char]0x5B57+'.bin'
    [IO.File]::WriteAllBytes((Join-Path $fixture $unicodeName),[byte[]]::new(123))
    for($i=0;$i -lt 45;$i++){[IO.File]::WriteAllBytes((Join-Path $fixture ('file-{0:D2}.bin' -f $i)),[byte[]]::new($i+1))}
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $session=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') (Join-Path $HelperDirectory 'manifest.json')
    $report.StartupMilliseconds=$timer.Elapsed.TotalMilliseconds
    Assert ($session.Hello.protocol -eq 1 -and $session.Hello.architecture -eq 'x64') 'Versioned helper starts as a separate x64 process'
    $profile=Invoke-DiskHelper $session @{command='profile'}
    Assert ($profile.type -eq 'profile' -and $null -eq $profile.scan) 'Idle session has no stale MFT profile'
    $null=Invoke-DiskHelper $session @{command='scan';path=$fixture;engine='native'}
    do{$status=Invoke-DiskHelper $session @{command='status'};if($status.state -ne 'ready'){Start-Sleep -Milliseconds 20}}while($status.state -ne 'ready')
    $report.Summary=$status.summary
    Assert ($status.summary.files -eq 48 -and $status.summary.logical -eq 26158) 'Native helper counts the fixture exactly'
    Assert ($null -eq (Invoke-DiskHelper $session @{command='profile'}).scan) 'Native scans do not fabricate MFT phase measurements'
    $first=Invoke-DiskHelper $session @{command='list';limit=20}
    Assert ($first.total -eq 48 -and @($first.rows).Count -eq 20 -and $first.rows[0].Name -eq 'nested') 'Paged listing sorts largest entries first'
    Assert ($first.rows[0].Modified -eq '2020-02-03') 'Paged listing includes the current modified date'
    $report.PageResponseBytes=$session.LastResponseBytes
    $second=Invoke-DiskHelper $session @{command='list';offset=20;limit=20}
    Assert ($first.rows[-1].Path -ne $second.rows[0].Path) 'Paging advances without duplicating the boundary row'
    $all=Invoke-DiskHelper $session @{command='list';limit=100;sort='name'}
    Assert (@($all.rows | Where-Object Name -eq $unicodeName).Count -eq 1) 'UTF-8 filenames survive the protocol'
    $nested=Invoke-DiskHelper $session @{command='list';path=(Join-Path $fixture 'nested')}
    Assert ($nested.rows[0].Bytes -eq 20000 -and $nested.parent -eq $fixture) 'Cached folder navigation returns the parent and file size'
    $nestedPath=Join-Path $fixture 'nested';$nestedFile=Join-Path $nestedPath 'large.bin'
    $secondPath=Join-Path $fixture 'second';$secondFile=Join-Path $secondPath 'other.bin'
    $null=Invoke-DiskHelper $session @{command='live';enabled=$true}
    $timer=[Diagnostics.Stopwatch]::StartNew()
    do{$live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true;watchPath=$nestedPath};$liveDirectory=@($live.rows | Where-Object Path -eq $nestedPath)[0];if($liveDirectory.LiveState -ne 'checking'){break};Start-Sleep -Milliseconds 40}while($timer.ElapsedMilliseconds -lt 5000)
    Assert ($liveDirectory.LiveState -eq 'same' -and $liveDirectory.Bytes -eq 20000) 'Selected-directory live probe establishes a nonblocking logical baseline'
    $timer.Restart()
    do{$live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true;watchPath=$nestedPath};$secondDirectory=@($live.rows | Where-Object Path -eq $secondPath)[0];if($secondDirectory.LiveState -ne 'checking'){break};Start-Sleep -Milliseconds 40}while($timer.ElapsedMilliseconds -lt 5000)
    Assert ($secondDirectory.LiveState -eq 'same' -and $secondDirectory.Bytes -eq 5000) 'Round-robin live probe establishes a baseline for an unselected visible directory'
    [IO.File]::WriteAllBytes($secondFile,[byte[]]::new(15000))
    $timer.Restart()
    do{$live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true;watchPath=$nestedPath};$secondDirectory=@($live.rows | Where-Object Path -eq $secondPath)[0];if($secondDirectory.LiveState -eq 'grown'){break};Start-Sleep -Milliseconds 40}while($timer.ElapsedMilliseconds -lt 7000)
    Assert ($secondDirectory.LiveState -eq 'grown' -and $secondDirectory.Bytes -eq 15000 -and $secondDirectory.LogicalDelta -eq 10000) 'Round-robin live probe detects growth inside an unselected visible directory'
    [IO.File]::WriteAllBytes($secondFile,[byte[]]::new(5000))
    $null=Invoke-DiskHelper $session @{command='live';enabled=$false}
    $livePath=Join-Path $fixture 'file-44.bin'
    $null=Invoke-DiskHelper $session @{command='live';enabled=$true}
    $null=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true}
    [IO.File]::WriteAllBytes($livePath,[byte[]]::new(10045))
    $live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true}
    $grown=@($live.rows | Where-Object Path -eq $livePath)[0]
    Assert ($grown.LiveState -eq 'grown' -and $grown.Bytes -eq 10045 -and $grown.LogicalDelta -eq 10000 -and $grown.AllocatedDelta -gt 0) 'Live listing detects a growing visible file and reports logical/allocation deltas'
    [IO.File]::WriteAllBytes($livePath,[byte[]]::new(10))
    $live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true}
    $shrunk=@($live.rows | Where-Object Path -eq $livePath)[0]
    Assert ($shrunk.LiveState -in @('shrunk','changed') -and $shrunk.Bytes -eq 10 -and $shrunk.LogicalDelta -eq -35) 'Live listing detects a shrinking visible file even when allocation is retained'
    Remove-Item -LiteralPath $livePath
    $live=Invoke-DiskHelper $session @{command='list';limit=100;sort='name';live=$true}
    Assert (@($live.rows | Where-Object Path -eq $livePath)[0].LiveState -eq 'deleted') 'Live listing keeps a deleted file visible and marks it deleted'
    [IO.File]::WriteAllBytes($livePath,[byte[]]::new(45))
    $null=Invoke-DiskHelper $session @{command='live';enabled=$false}
    $bad=$false;try{$null=Invoke-DiskHelper $session @{command='list';path='Z:\outside'}}catch{$bad=$true}
    Assert $bad 'Out-of-scan paths are rejected'
    $bad=$false;try{$null=Invoke-DiskHelper $session @{command='list';limit=101}}catch{$bad=$true}
    Assert $bad 'Response page size is bounded'
    Assert ((Invoke-DiskHelper $session @{command='status'}).state -eq 'ready') 'Protocol errors do not kill the session'
    # Restart/cancel exercises process-owned lifetime and partial-result handling.
    $null=Invoke-DiskHelper $session @{command='scan';path=$fixture;engine='native'}
    $null=Invoke-DiskHelper $session @{command='cancel'}
    do{$status=Invoke-DiskHelper $session @{command='status'};if($status.state -ne 'ready'){Start-Sleep -Milliseconds 20}}while($status.state -ne 'ready')
    Assert ($status.summary.cancelled -or $status.summary.files -eq 48) 'Cancel yields partial results or an already-completed scan'
    $id=$session.Hello.processId;Stop-DiskHelper $session
    Assert (-not (Get-Process -Id $id -ErrorAction SilentlyContinue)) 'Closing the session terminates the helper'
    # Manifest mismatch is rejected before starting executable code.
    $badManifest=Join-Path $fixture 'manifest.json'
    @{Protocol=1;File='DiskHelper.exe';Sha256='BAD'} | ConvertTo-Json | Set-Content $badManifest
    $bad=$false;try{$null=Start-DiskHelper (Join-Path $HelperDirectory 'DiskHelper.exe') $badManifest}catch{$bad=$true}
    Assert $bad 'Checksum mismatch blocks execution'
    $report.Status='PASS';$report.Fixture=$fixture
} catch {$report.Error=$_.Exception.ToString();throw}
finally {Stop-DiskHelper $session;if($ReportPath){$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath}}
