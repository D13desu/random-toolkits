$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../m365/Menu-Engine.ps1')
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message};Write-Output "PASS: $Message"}

$script:Written=[Collections.Generic.List[string]]::new()
function Write-Host {param([Parameter(ValueFromRemainingArguments=$true)]$Object,$ForegroundColor,[switch]$NoNewline);$script:Written.Add([string]($Object -join ' '))}
function Test-M365MenuKeyboard {$false}
function Read-Host {param($Prompt) 'm'}
Reset-M365Menu
Write-M365MenuOptions "[1] First`n[M] Mail flow`n[0] Back"
Assert ($script:M365MenuRows.Count -eq 3) 'Option writer registers numbered, letter and back choices'
Assert ((Read-M365MenuChoice) -eq 'm') 'Unsupported consoles retain Read-Host selection'
Assert ($script:M365MenuRows.Count -eq 0) 'Selection clears the pending menu'

$script:Keys=New-Object 'Collections.Generic.Queue[object]'
function Test-M365MenuKeyboard {$true}
function Test-M365MenuCursor {$true}
function Get-M365MenuCursorTop {20}
$script:Moves=[Collections.Generic.List[int]]::new()
function Set-M365MenuCursorPosition {param($Left,$Top);$script:Moves.Add([int]$Top)}
function Read-M365MenuKey {if(-not $script:Keys.Count){throw 'Unexpected key read'};$script:Keys.Dequeue()}
function Key($Name,[char]$Char=[char]0){[pscustomobject]@{Key=$Name;KeyChar=$Char}}

Reset-M365Menu
$script:Keys.Enqueue((Key 'DownArrow'))
$script:Keys.Enqueue((Key 'Enter' "`r"))
Write-M365MenuOptions "[1] First`n[2] Second`n[0] Back"
Assert ((Read-M365MenuChoice) -eq '2') 'Arrow navigation selects the highlighted item'
Assert ($script:Moves.Count -ge 6) 'Arrow navigation repaints rows through cursor positioning'

Reset-M365Menu
$script:Keys.Enqueue((Key 'D1' '1'))
$script:Keys.Enqueue((Key 'D2' '2'))
$script:Keys.Enqueue((Key 'Backspace' "`b"))
$script:Keys.Enqueue((Key 'Enter' "`r"))
$options=(1..12|ForEach-Object{"[$_] Item $_"}) -join "`n"
Write-M365MenuOptions $options
Assert ((Read-M365MenuChoice) -eq '1') 'Visible numeric input supports multidigit entry and editing'

Reset-M365Menu
$script:Keys.Enqueue((Key 'Escape' ([char]27)))
Write-M365MenuOptions "[1] First`n[0] Back"
Assert ((Read-M365MenuChoice) -eq '0') 'Escape returns to the caller'

function Head {param($Title);Reset-M365Menu}
Reset-M365Menu
$script:Keys.Enqueue((Key 'DownArrow'))
$script:Keys.Enqueue((Key 'Enter' "`r"))
$records=@([pscustomobject]@{Name='One'},[pscustomobject]@{Name='Two'},[pscustomobject]@{Name='Three'})
$result=Show-M365RecordMenu $records 'Records' {param($row,$index)$row.Name}
Assert ($result.Action -eq 'Select' -and $result.Item.Name -eq 'Two') 'Record browsers use the same arrow-selection engine'

$toolkit=Get-Content (Join-Path $PSScriptRoot '../m365/M365-Toolkit.ps1') -Raw
$module=Get-Content (Join-Path $PSScriptRoot '../m365/Menu-Engine.ps1') -Raw
$embedded=($toolkit -split '# BEGIN M365 MENU ENGINE',2)[1] -split '# END M365 MENU ENGINE',2
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded M365 menu engine matches maintained source'
