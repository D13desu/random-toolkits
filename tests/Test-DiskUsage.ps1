$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
function Assert-True($Value,$Message) { if (-not $Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$root=Join-Path $env:TEMP ('toolkit-disk-test-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path (Join-Path $root 'large/nested') -Force
$null=New-Item -ItemType Directory -Path (Join-Path $root 'empty')
[IO.File]::WriteAllBytes((Join-Path $root 'small.bin'),[byte[]]::new(17))
[IO.File]::WriteAllBytes((Join-Path $root 'large/big.bin'),[byte[]]::new(2048))
[IO.File]::WriteAllBytes((Join-Path $root 'large/nested/more.bin'),[byte[]]::new(1024))
# Include hidden/system-style metadata and a junction back to the root (must not recurse).
[IO.File]::SetAttributes((Join-Path $root 'small.bin'),[IO.FileAttributes]::Hidden)
$null=New-Item -ItemType Junction -Path (Join-Path $root 'large/loop') -Target $root
$scan=Measure-DiskTree $root
Assert-True ($scan.Nodes[$scan.Root].Bytes -eq 3089 -and $scan.Files -eq 3) 'Nested totals include hidden files exactly once'
Assert-True ($scan.Nodes.Count -eq 4 -and $scan.IssueCount -eq 1) 'Junction loop is skipped and reported'
Assert-True $scan.Nodes[$scan.Root].Partial 'Exclusions propagate partial totals to parents'
$rows=@(Get-DiskChildren $scan $scan.Root)
Assert-True ($rows.Count -eq 3 -and $rows[0].Name -eq 'large' -and $rows[0].Bytes -eq 3072 -and $rows[2].Bytes -eq 0) 'Folders and files sorted largest first with empty folders retained'
Assert-True ((Format-DiskSize 1024) -match 'KiB') 'Human-readable binary size units'
$failed=$false
try { Measure-DiskTree (Join-Path $root 'small.bin') } catch { $failed=$true }
Assert-True $failed 'File cannot be used as scan root'
$script:Answers=New-Object 'System.Collections.Generic.Queue[string]'
foreach ($answer in @('1','U','N','P','R','0')) { $script:Answers.Enqueue($answer) }
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw 'Unexpected prompt' }; $script:Answers.Dequeue() }
Show-DiskScan $scan
Assert-True ($script:Answers.Count -eq 0) 'Drill-down, parent, paging, rescan and exit navigation'
foreach ($answer in @('1','b','b')) { $script:Answers.Enqueue($answer) }
Show-DiskScan $scan
Assert-True ($script:Answers.Count -eq 0) 'B returns from a folder to its parent, then to drives'
foreach ($answer in @('F','B','M','B','B')) { $script:Answers.Enqueue($answer) }
Start-DiskUsage
Assert-True ($script:Answers.Count -eq 0) 'B cancels folder and MFT root input and returns to launcher'
Assert-True ([IO.File]::ReadAllBytes((Join-Path $root 'small.bin')).Length -eq 17) 'Explorer does not modify files'
$script:Answers.Enqueue('0')
Get-Content -Raw (Join-Path $PSScriptRoot '../win/disk/index.html') | Invoke-Expression
Assert-True ($script:Answers.Count -eq 0) 'Standalone IEX launcher opens and exits'
$fallback=Measure-DiskTree -LiteralPath $root -Engine PowerShell
Assert-True ($fallback.Files -eq $scan.Files -and $fallback.Nodes[$root].Bytes -eq $scan.Nodes[$root].Bytes -and $fallback.IssueCount -eq $scan.IssueCount) 'Native and fallback agree on totals and exclusions'
$longRoot=Join-Path $env:TEMP ('toolkit-long-test-'+[guid]::NewGuid().ToString('N'))
$longPath=$longRoot
for ($i=0; $i -lt 5; $i++) { $longPath=Join-Path $longPath ('directory-'+('x'*50)) }
$null=[IO.Directory]::CreateDirectory(('\\?\'+$longPath))
[IO.File]::WriteAllBytes(('\\?\'+$longPath+'\unicode-'+[char]0x00f1+'.bin'),[byte[]]::new(33))
$longScan=Measure-DiskTree -LiteralPath $longRoot -Engine Native
$longRootBytes=if($longScan.Nodes.ContainsKey($longRoot)){$longScan.Nodes[$longRoot].Bytes}else{-1}
$longIssues=($longScan.Issues | ForEach-Object {"$($_.Path): $($_.Reason)"}) -join ' | '
Assert-True ($longScan.Files -eq 1 -and $longRootBytes -eq 33) "Native scanner supports Unicode and paths beyond MAX_PATH (files=$($longScan.Files), bytes=$longRootBytes, issues=$longIssues)"
Assert-True (@(Get-DiskChildren $longScan $longPath)[0].Bytes -eq 33) 'Long-path file listing uses native metadata'
function Initialize-DiskScanner { throw 'Simulated Add-Type restriction' }
$auto=Measure-DiskTree -LiteralPath $root
Assert-True ($auto.Nodes[$root].Bytes -eq 3089 -and @(Get-DiskChildren $auto $root).Count -eq 3) 'Restricted compilation falls back to working PowerShell scanner'
# Leave this small isolated fixture in TEMP; no recursive deletion through a junction.
Write-Output "Disk tests passed on PowerShell $($PSVersionTable.PSVersion). Fixture: $root"
