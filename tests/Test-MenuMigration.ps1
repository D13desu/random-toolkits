$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Keys=New-Object 'Collections.Generic.Queue[string]'
$script:Calls=New-Object 'Collections.Generic.List[string]'
$script:Output=New-Object 'Collections.Generic.List[string]'
function Test-PcMenuKeyboard {$true}
function Clear-Host {}
function Write-Host {param($Object,$ForegroundColor) $script:Output.Add([string]$Object)}
function Read-PcMenuInput {param($Keyboard) if(-not $Keyboard){throw 'Expected keyboard mode'};if(-not $script:Keys.Count){throw 'Unexpected menu input'};$script:Keys.Dequeue()}
function Read-Host {param($Prompt) if($Prompt -match 'Enter to return'){return ''};if($Prompt -ne 'Select number' -or -not $script:Keys.Count){throw "Unexpected prompt: $Prompt"};$script:Keys.Dequeue()}
function Get-NetworkAvailability {param($Entry) [pscustomobject]@{Available=$true;Reason=''}}
function Get-AdContext {[pscustomobject]@{Computer='Fixture';Role='Workgroup';Domain='WORKGROUP'}}
function Invoke-PcRegistryTweak {param($Id,$SizeGB,[switch]$Reset) $script:Calls.Add('Registry:'+ $Id)}
function Invoke-PcWindowsRepair {param($Action) $script:Calls.Add('Repair:'+ $Action)}
function Start-PcStartupTaskBrowser {param($Kind) $script:Calls.Add('Startup:'+ $Kind)}
function Start-PcEventBrowser {param($DefaultLog,[switch]$Quick) $script:Calls.Add('Events')}
function Invoke-InteractiveCheck {param($Item) $script:Calls.Add('Network:'+ $Item.Entry.Id)}
foreach($key in @('8','1','2','2','2','B','B','B','B','12','5','B','10','2','B','7','C','B','2','2','1','B','B','B')){$script:Keys.Enqueue($key)}
Start-WindowsMenu -AllowCallerReturn
Assert (($script:Calls -join ',') -eq 'Registry:rdp,Repair:RepairFiles,Startup:Task,Events,Network:connectivity') 'Root/category numbers dispatch only the selected mocked actions'
Assert ($script:Keys.Count -eq 0) 'Nested Back returns exactly one level'
Assert (@($script:Output | Where-Object {$_ -match '^[> ] \[12\] Windows repair centre'}).Count -gt 0 -and @($script:Output | Where-Object {$_ -match '^[> ] \[99\] Toolkit cleanup'}).Count -gt 0) 'Root shows every section including cleanup 99 without paging'
$script:Calls.Clear()
function Invoke-PcServiceAction {param($Name,$Action) $script:Calls.Add($Name+':'+$Action)}
function Get-PcServiceInventory {[pscustomobject]@{Name='Fixture';DisplayName='Fixture';State='Running';StartMode='Auto'}}
foreach($key in @('1','B')){$script:Keys.Enqueue($key)}
Show-PcServiceDetails (Get-PcServiceInventory)
Assert (($script:Calls -join ',') -eq 'Fixture:Start') 'Service action menu uses the numbered selection'
Assert ($script:Keys.Count -eq 0) 'Service action returns cleanly'

$script:Keys.Enqueue('Down');$script:Keys.Enqueue('Select')
$state=@{}
$items=@(New-PcMenuItem '9' 'First';New-PcMenuItem '1' 'Second')
Assert ((Read-PcCategoryMenu 'Hybrid' $items $state) -eq '1') 'Arrows select by row independently of numeric shortcut'
$script:Keys.Enqueue('Select')
Assert ((Read-PcCategoryMenu 'Hybrid' $items $state) -eq '1') 'Hybrid menu preserves selection on return'
$script:Keys.Enqueue('9')
Assert ((Read-PcCategoryMenu 'Hybrid' $items $state) -eq '9') 'Number shortcut remains available alongside arrows'
