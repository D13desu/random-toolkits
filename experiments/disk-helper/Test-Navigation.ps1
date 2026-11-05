$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('helper-navigation-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory((Join-Path $root 'child'))
[IO.File]::WriteAllText((Join-Path $root 'child/file.txt'),'fixture')
$global:HelperNavigationAnswers=New-Object 'System.Collections.Generic.Queue[string]'
# First scan: enter child, back to root, inspect views, back to drives.
# Second scan: select the same fixture, return to drives, then caller.
foreach($answer in @('1','b','A','','E','','T','','b',$root,'0','b')){$global:HelperNavigationAnswers.Enqueue($answer)}
$global:HelperNavigationDrivePrompts=0
function Read-Host {
 param($Prompt)
 if($Prompt -like 'Drive number*'){$global:HelperNavigationDrivePrompts++}
 if($global:HelperNavigationAnswers.Count -eq 0){throw 'Unexpected navigation prompt'}
 return $global:HelperNavigationAnswers.Dequeue()
}
$before=@(Get-Process DiskHelper -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
& (Join-Path $PSScriptRoot 'Start-DiskHelper.ps1') -Path $root -Engine native
if($global:HelperNavigationAnswers.Count -ne 0 -or $global:HelperNavigationDrivePrompts -ne 2){throw 'Back did not preserve the menu hierarchy'}
$leaked=@(Get-Process DiskHelper -ErrorAction SilentlyContinue | Where-Object {$_.Id -notin $before})
if($leaked.Count){throw 'Helper process survived navigation exit'}
'PASS: Folder, reports, drive reselection and caller return; no helper processes leaked.'
