# Optional: run manually in an elevated PowerShell. Reads the TEMP drive's full MFT.
# Creates an isolated fixture; no existing files are modified or deleted.
[CmdletBinding()]
param([switch]$CompareWholeVolume)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
$drive=[IO.Path]::GetPathRoot($env:TEMP)
$reason=Get-DiskMftUnavailableReason $drive
if ($reason) { throw "Live test cannot run: $reason" }
Initialize-DiskScanner
$fixture=Join-Path $env:TEMP ('toolkit-mft-live-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'nested') -Force
$small=Join-Path $fixture 'small.bin'; [IO.File]::WriteAllBytes($small,[byte[]]::new(17))
$null=New-Item -ItemType HardLink -Path (Join-Path $fixture 'nested/alias.bin') -Target $small
$sparse=Join-Path $fixture 'sparse.bin'; [IO.File]::WriteAllBytes($sparse,[byte[]]::new(0))
$null=& fsutil sparse setflag $sparse
if ($LASTEXITCODE -ne 0) { throw 'Could not create sparse test file' }
$stream=[IO.File]::OpenWrite($sparse);try { $stream.SetLength(1048576) } finally { $stream.Dispose() }
$compressed=Join-Path $fixture 'compressed.bin'; [IO.File]::WriteAllBytes($compressed,[byte[]]::new(65536))
$null=& compact /C /I /Q $compressed
if ($LASTEXITCODE -ne 0) { throw 'Could not compress test file' }
$unicode=Join-Path $fixture ('unicode-'+[char]0x00f1+'.bin'); [IO.File]::WriteAllBytes($unicode,[byte[]]::new(33))
$long=Join-Path $fixture (('x'*100)+'\'+('y'*100)+'\'+('z'*100))
$null=[IO.Directory]::CreateDirectory(('\\?\'+$long))
[IO.File]::WriteAllBytes(('\\?\'+$long+'\long.bin'),[byte[]]::new(11))
$timer=[Diagnostics.Stopwatch]::StartNew()
$scan=Measure-DiskTree $drive -Engine Mft
$mftSeconds=$timer.Elapsed.TotalSeconds
if ($scan.Engine -ne 'Experimental NTFS MFT records') { throw 'MFT engine fell back; this is not a live MFT pass' }
$expected=17+1048576+65536+33+11
if (-not $scan.Nodes.ContainsKey($fixture) -or $scan.Nodes[$fixture].Bytes -ne $expected -or $scan.Nodes[$fixture].Files -ne 5) { throw 'Live MFT fixture totals differ from expected unique-file logical sizes' }
$normal=Measure-DiskTree $fixture -Engine Native
if ($normal.Nodes[$fixture].Bytes -ne ($expected+17)) { throw 'Native comparison did not count the extra hard-link pathname as expected' }
$nativeSeconds=$null
if ($CompareWholeVolume) {
    $timer.Restart(); $native=Measure-DiskTree $drive -Engine Native; $nativeSeconds=$timer.Elapsed.TotalSeconds
    # Whole-volume totals need not match: hardlink accounting and permissions differ.
}
[pscustomobject]@{Result='PASS';PowerShell=[string]$PSVersionTable.PSVersion;Drive=$drive;Fixture=$fixture;UniqueLogicalBytes=$expected;MftSeconds=[math]::Round($mftSeconds,2);NativeWholeVolumeSeconds=$nativeSeconds;MftIssues=$scan.IssueCount;Note='Single warm-system trial; not a performance guarantee. Fixture retained.'} | Format-List
