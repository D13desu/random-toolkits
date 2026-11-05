[CmdletBinding()]
param([string]$ReportPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Client.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output ('PASS: '+$message)}
$session=$null;$report=[ordered]@{Status='FAIL';PowerShell=[string]$PSVersionTable.PSVersion}
try {
    $fixture=Join-Path $env:TEMP ('toolkit-helper-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'nested'))
    [IO.File]::WriteAllBytes((Join-Path $fixture 'nested/large.bin'),[byte[]]::new(20000))
    $unicodeName='caf'+[char]0xE9+'-'+[char]0x6F22+[char]0x5B57+'.bin'
    [IO.File]::WriteAllBytes((Join-Path $fixture $unicodeName),[byte[]]::new(123))
    for($i=0;$i -lt 45;$i++){[IO.File]::WriteAllBytes((Join-Path $fixture ('file-{0:D2}.bin' -f $i)),[byte[]]::new($i+1))}
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $session=Start-DiskHelper (Join-Path $PSScriptRoot 'out/DiskHelper.exe') (Join-Path $PSScriptRoot 'out/manifest.json')
    $report.StartupMilliseconds=$timer.Elapsed.TotalMilliseconds
    Assert ($session.Hello.protocol -eq 1 -and $session.Hello.architecture -eq 'x64') 'Versioned helper starts as a separate x64 process'
    $null=Invoke-DiskHelper $session @{command='scan';path=$fixture;engine='native'}
    do{$status=Invoke-DiskHelper $session @{command='status'};if($status.state -ne 'ready'){Start-Sleep -Milliseconds 20}}while($status.state -ne 'ready')
    $report.Summary=$status.summary
    Assert ($status.summary.files -eq 47 -and $status.summary.logical -eq 21158) 'Native helper counts the fixture exactly'
    $first=Invoke-DiskHelper $session @{command='list';limit=20}
    Assert ($first.total -eq 47 -and @($first.rows).Count -eq 20 -and $first.rows[0].Name -eq 'nested') 'Paged listing sorts largest entries first'
    $report.PageResponseBytes=$session.LastResponseBytes
    $second=Invoke-DiskHelper $session @{command='list';offset=20;limit=20}
    Assert ($first.rows[-1].Path -ne $second.rows[0].Path) 'Paging advances without duplicating the boundary row'
    $all=Invoke-DiskHelper $session @{command='list';limit=100;sort='name'}
    Assert (@($all.rows | Where-Object Name -eq $unicodeName).Count -eq 1) 'UTF-8 filenames survive the protocol'
    $nested=Invoke-DiskHelper $session @{command='list';path=(Join-Path $fixture 'nested')}
    Assert ($nested.rows[0].Bytes -eq 20000 -and $nested.parent -eq $fixture) 'Cached folder navigation returns the parent and file size'
    $bad=$false;try{$null=Invoke-DiskHelper $session @{command='list';path='Z:\outside'}}catch{$bad=$true}
    Assert $bad 'Out-of-scan paths are rejected'
    $bad=$false;try{$null=Invoke-DiskHelper $session @{command='list';limit=101}}catch{$bad=$true}
    Assert $bad 'Response page size is bounded'
    Assert ((Invoke-DiskHelper $session @{command='status'}).state -eq 'ready') 'Protocol errors do not kill the session'
    # Restart/cancel exercises process-owned lifetime and partial-result handling.
    $null=Invoke-DiskHelper $session @{command='scan';path=$fixture;engine='native'}
    $null=Invoke-DiskHelper $session @{command='cancel'}
    do{$status=Invoke-DiskHelper $session @{command='status'};if($status.state -ne 'ready'){Start-Sleep -Milliseconds 20}}while($status.state -ne 'ready')
    Assert ($status.summary.cancelled -or $status.summary.files -eq 47) 'Cancel yields partial results or an already-completed scan'
    $id=$session.Hello.processId;Stop-DiskHelper $session
    Assert (-not (Get-Process -Id $id -ErrorAction SilentlyContinue)) 'Closing the session terminates the helper'
    # Manifest mismatch is rejected before starting executable code.
    $badManifest=Join-Path $fixture 'manifest.json'
    @{Protocol=1;File='DiskHelper.exe';Sha256='BAD'} | ConvertTo-Json | Set-Content $badManifest
    $bad=$false;try{$null=Start-DiskHelper (Join-Path $PSScriptRoot 'out/DiskHelper.exe') $badManifest}catch{$bad=$true}
    Assert $bad 'Checksum mismatch blocks execution'
    $report.Status='PASS';$report.Fixture=$fixture
} catch {$report.Error=$_.Exception.ToString();throw}
finally {Stop-DiskHelper $session;if($ReportPath){$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath}}
