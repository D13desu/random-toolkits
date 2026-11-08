$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Menu-Engine.ps1')
. (Join-Path $PSScriptRoot '../win/modules/Toolkit-Cleanup.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Fixture=Join-Path $env:TEMP ('cleanup-safety-test-'+[guid]::NewGuid().ToString('N'))
$script:CleanupRoots=[pscustomobject]@{Temp=(Join-Path $script:Fixture 'temp');Data=(Join-Path $script:Fixture 'data')}
foreach($root in @($script:CleanupRoots.Temp,$script:CleanupRoots.Data)){ $null=[IO.Directory]::CreateDirectory($root) }
function Get-ToolkitCleanupRoots {$script:CleanupRoots}
function Get-Process {param($Name,$ErrorAction)}
function Write-OldFile($path,$text='fixture'){
 $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent));[IO.File]::WriteAllText($path,$text)
 (Get-Item -LiteralPath $path).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
}
$package=Join-Path $script:CleanupRoots.Temp ('toolkit-helper-'+[guid]::NewGuid().ToString('N'))
Write-OldFile (Join-Path $package 'nested/file.txt')
(Get-Item (Join-Path $package 'nested')).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
(Get-Item $package).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
$report=Join-Path $script:CleanupRoots.Temp 'toolkit-helper-test-report.json';Write-OldFile $report
$unrelated=Join-Path $script:CleanupRoots.Temp 'my-report.json';Write-OldFile $unrelated
$backup=Join-Path $script:CleanupRoots.Data 'registry-backups/undo.reg';Write-OldFile $backup
$saved=Join-Path $script:CleanupRoots.Data 'm365/0.3.7/reports/saved.json';Write-OldFile $saved
$cache=Join-Path $script:CleanupRoots.Data 'oui';Write-OldFile (Join-Path $cache 'assignments.csv');(Get-Item $cache).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
$items=@(Get-ToolkitCleanupCandidates Both)
Assert (@($items | Where-Object Eligible).Count -eq 3) 'Only recognized temporary data and cache are eligible'
$item=$items | Where-Object Kind -eq 'Helper package / fixture'
$currentPackage=Get-ToolkitCleanupCandidates Both | Where-Object Path -eq $item.Path
Assert ($currentPackage.Eligible) "Package remains eligible for removal after preview: $($currentPackage.Reason)"
Remove-ToolkitCleanupCandidate $item Both
Assert (-not (Test-Path $package)) 'Validated tree removed without recursive filesystem deletion'
Assert ((Test-Path $unrelated) -and (Test-Path $backup) -and (Test-Path $saved)) 'Unrelated files, undo files and M365 reports preserved'
$failed=$false;try{Remove-ToolkitCleanupCandidate ([pscustomobject]@{Path=$unrelated;Entries=@()}) Both}catch{$failed=$true}
Assert ($failed -and (Test-Path $unrelated)) 'Forged candidate cannot delete an unrecognized file'
$item=$items | Where-Object Kind -like 'Diagnostic report*'
Write-OldFile $report 'modified after preview'
$failed=$false;try{Remove-ToolkitCleanupCandidate $item Both}catch{$failed=$true}
Assert ($failed -and (Test-Path $report)) 'Modified contents rejected after preview'
(Get-Item $report).LastWriteTimeUtc=[datetime]::UtcNow
Assert (-not (Get-ToolkitCleanupCandidates Both | Where-Object {$_.Path -eq $item.Path}).Eligible) 'Recent files are retained'
$linked=Join-Path $script:CleanupRoots.Temp ('toolkit-disk-test-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($linked)
$null=New-Item -ItemType Junction -Path (Join-Path $linked 'link') -Target $script:CleanupRoots.Data
(Get-Item $linked).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
$linkedName=Split-Path $linked -Leaf
Assert (-not (Get-ToolkitCleanupCandidates Both | Where-Object {(Split-Path $_.Path -Leaf) -eq $linkedName}).Eligible) 'Trees containing junctions are not followed or deleted'
$failed=$false;try{Assert-ToolkitCleanupPath $script:CleanupRoots.Data $script:CleanupRoots.Temp}catch{$failed=$true}
Assert $failed 'Sibling directory outside boundary rejected'
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('2','n','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw 'Unexpected prompt'};$script:Answers.Dequeue()}
Start-ToolkitCleanup
Assert ((Test-Path $cache) -and $script:Answers.Count -eq 0) 'No confirmation leaves candidates intact and returns to caller'
$active=Join-Path $script:CleanupRoots.Temp ('toolkit-helper-'+[guid]::NewGuid().ToString('N'))
Write-OldFile (Join-Path $active 'helper.zip');(Get-Item $active).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(-1)
function Get-Process {param($Name,$ErrorAction) [pscustomobject]@{Id=123}}
$activeName=Split-Path $active -Leaf
Assert (-not (Get-ToolkitCleanupCandidates Temp | Where-Object {(Split-Path $_.Path -Leaf) -eq $activeName}).Eligible) 'Running helpers prevent package cleanup'
$source=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN TOOLKIT CLEANUP',2)[1] -split '# END TOOLKIT CLEANUP',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Toolkit-Cleanup.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded cleanup matches maintained source'
