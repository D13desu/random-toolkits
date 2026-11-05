$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Keys=New-Object 'Collections.Generic.Queue[string]'
$script:Calls=New-Object 'Collections.Generic.List[string]'
$script:Output=New-Object 'Collections.Generic.List[string]'
function Test-PcMenuKeyboard {$true}
function Clear-Host {}
function Write-Host {param($Object,$ForegroundColor) $script:Output.Add([string]$Object)}
function Read-PcMenuInput {param($Keyboard) if(-not $Keyboard){throw 'Expected keyboard mode'};if(-not $script:Keys.Count){throw 'Unexpected menu input'};$script:Keys.Dequeue()}
function Read-Host {param($Prompt) if($Prompt -notmatch 'Enter to return'){throw "Unexpected data/action prompt: $Prompt"};return ''}
function Get-NetworkAvailability {param($Entry) [pscustomobject]@{Available=$true;Reason=''}}
function Get-AdContext {[pscustomobject]@{Computer='Fixture';Role='Workgroup';Domain='WORKGROUP'}}
function Invoke-PcRegistryTweak {param($Id,$SizeGB,[switch]$Reset) $script:Calls.Add('Registry:'+ $Id)}
function Invoke-PcWindowsRepair {param($Action) $script:Calls.Add('Repair:'+ $Action)}
function Start-PcStartupTaskBrowser {param($Kind) $script:Calls.Add('Startup:'+ $Kind)}
function Start-PcEventBrowser {param($DefaultLog,[switch]$Quick) $script:Calls.Add('Events')}
function Invoke-InteractiveCheck {param($Item) $script:Calls.Add('Network:'+ $Item.Entry.Id)}
foreach($key in @('7','Down','Select','Down','Select','Back','Back','12','Last','Select','Back','10','Down','Select','Back','6','C','Back','1','Down','Select','Select','Back','Back','Back')){$script:Keys.Enqueue($key)}
Start-WindowsMenu
Assert (($script:Calls -join ',') -eq 'Registry:rdp,Repair:RepairFiles,Startup:Task,Events,Network:connectivity') 'Root/category arrows dispatch only the selected mocked actions'
Assert ($script:Keys.Count -eq 0) 'Nested Back returns exactly one level'
Assert (@($script:Output | Where-Object {$_ -match '^> \[7\] Registry tweaks'}).Count -gt 0) 'Root preserves Registry selection after returning'
$script:Calls.Clear()
function Invoke-PcServiceAction {param($Name,$Action) $script:Calls.Add($Name+':'+$Action)}
function Get-PcServiceInventory {[pscustomobject]@{Name='Fixture';DisplayName='Fixture';State='Running';StartMode='Auto'}}
foreach($key in @('Down','Select','Back')){$script:Keys.Enqueue($key)}
Show-PcServiceDetails (Get-PcServiceInventory)
Assert (($script:Calls -join ',') -eq 'Fixture:Start') 'Service action menu uses the same keyboard selection'
Assert ($script:Keys.Count -eq 0) 'Service action returns cleanly'
