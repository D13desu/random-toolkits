$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert-True($Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$categories = @(Get-NetworkCategories)
$items = @($categories | ForEach-Object { Get-NetworkMenuItems $_ })
foreach ($entry in @((Get-NetworkChecks)) + @((Get-AdChecks)) + @((Get-NetworkRepairs))) {
    Assert-True ($entry.Id -in $items.Entry.Id) "Existing action remains reachable: $($entry.Id)"
}
function Get-AdContext { [pscustomobject]@{Computer='TEST';Role='Workgroup';Domain='WORKGROUP'} }
function Get-NetworkAvailability { param($Entry) [pscustomobject]@{Available=$true;Reason=''} }
function Invoke-AdNative { throw 'A cancelled menu action must never run a native command' }
$script:Output = New-Object 'System.Collections.Generic.List[string]'
function Write-Host { param($Object,$ForegroundColor) $script:Output.Add([string]$Object) }
function Write-Warning { param($Message) $script:Output.Add([string]$Message) }
$script:Answers = New-Object 'System.Collections.Generic.Queue[string]'
function Read-Host { param($Prompt) if ($script:Answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:Output.Add($Prompt); $script:Answers.Dequeue() }
foreach ($category in @($categories | Where-Object { $_.Id -notin @('power','storage') })) { $script:Answers.Enqueue($category.Key); $script:Answers.Enqueue('0') }
$script:Answers.Enqueue('0')
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0) 'Every network category returns to the network menu'
foreach ($answer in @('1','0','2','0','3','0','0')) { $script:Answers.Enqueue($answer) }
Start-WindowsMenu
Assert-True ($script:Answers.Count -eq 0) 'Unified Windows menu navigates Network, Power and Storage and returns'
$script:Output.Clear()
foreach ($answer in @('3','2','n','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and 'Apply this change? [y/N]' -in $script:Output) 'DNS repair stays in DNS and preserves yes/no cancellation'
Assert-True (($script:Output -join '|') -match 'REPAIRS - require confirmation') 'Repair section is clearly identified'
$script:Output.Clear()
foreach ($answer in @('4','7','','0','0')) { $script:Answers.Enqueue($answer) }
Start-NetworkMenu
Assert-True ($script:Answers.Count -eq 0 -and ($script:Output -join '|') -match 'No AD domain trust exists') 'Unavailable AD repair displays its reason'
Assert-True ('DC hostname [automatic discovery]' -notin $script:Output) 'Unavailable repair is blocked before collecting inputs'
Write-Output "Menu tests passed on PowerShell $($PSVersionTable.PSVersion)."
