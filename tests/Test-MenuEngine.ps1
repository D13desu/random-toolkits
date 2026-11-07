$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Menu-Engine.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
$script:Output=New-Object 'Collections.Generic.List[string]'
function Write-Host {param($Object,$ForegroundColor,[switch]$NoNewline) $script:Output.Add([string]$Object);if(([string]$Object).StartsWith('    ')){$script:DetailColors.Add([string]$ForegroundColor)}}
$script:DetailColors=New-Object 'Collections.Generic.List[string]'
function Write-Warning {param($Message) $script:Output.Add([string]$Message)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
function Feed($Answers){foreach($answer in $Answers){$script:Answers.Enqueue($answer)}}
$items=@(1..25 | ForEach-Object {[pscustomobject]@{Id="item$_";Label="Entry $_";Kind='Check';Detail="Path $_";DisabledReason=$(if($_ -eq 2){'Requires administrator'}else{''})}})
Feed @('2','3');$state=@{};$result=Show-PcMenu -Title Test -Items $items -State $state -Plain
Assert ($result.Action -eq 'Select' -and $result.Item.Id -eq 'item3') 'Unavailable numbered item cannot be selected'
Assert ($script:Output -contains 'Requires administrator') 'Unavailable reason is displayed'
Feed @('');$result=Show-PcMenu -Title Test -Items $items -State $state -Plain
Assert ($result.Item.Id -eq 'item3') 'Returning to menu preserves selection'
Feed @('Last','Previous','Select');$result=Show-PcMenu -Title Test -Items $items -PageSize 10 -Plain
Assert ($result.Item.Id -eq 'item15') 'Last and page navigation use bounded positions'
Feed @('First','Up','Down','Down','Select');$result=Show-PcMenu -Title Test -Items $items -Plain
Assert ($result.Item.Id -eq 'item3') 'Arrow movement clamps and selects correctly'
Feed @('F','Path 24','');$state=@{};$result=Show-PcMenu -Title Test -Items $items -State $state -Filterable -Plain
Assert ($result.Item.Id -eq 'item24' -and $state.Filter -eq 'Path 24') 'Filter matches detail and persists in state'
Feed @('F','B','R');$result=Show-PcMenu -Title Test -Items $items -State $state -Filterable -Refreshable -Plain
Assert ($result.Action -eq 'Refresh' -and $state.Filter -eq 'Path 24' -and $state.SelectedId -eq 'item24') 'Cancelled filtering and refresh preserve state'
Feed @('F','missing','Select','Last','Next','B');$result=Show-PcMenu -Title Test -Items $items -Filterable -Plain
Assert ($result.Action -eq 'Back') 'Empty filtered view handles selection and movement'
Feed @('','0');$result=Show-PcMenu -Title Test -Items @() -Plain
Assert ($result.Action -eq 'Back') 'Empty inventory returns safely'
Feed @('F','R','999','B');$result=Show-PcMenu -Title Test -Items $items -Plain
Assert ($result.Action -eq 'Back') 'Unsupported controls and out-of-range input do not select'
$state=@{SelectedId='removed';Filter=''};Feed @('');$result=Show-PcMenu -Title Test -Items $items -State $state -Plain
Assert ($result.Item.Id -eq 'item1') 'Removed selection falls back to first item'
$blocked=$false;try{Show-PcMenu -Title Test -Items @($items[0],$items[0]) -Plain}catch{$blocked=$true}
Assert $blocked 'Duplicate IDs are rejected'
Feed @('','yes');Assert (-not (Confirm-PcMenuChange 'Fixture')) 'Changes default to No';Assert (Confirm-PcMenuChange 'Fixture') 'Explicit yes confirms'
Assert ((Format-PcMenuText ("a`nb"+[char]27) 20) -eq 'a b ') 'Control characters cannot inject terminal commands'
Assert ((Format-PcMenuText ('x'*80) 20).Length -eq 20) 'Long rows are bounded'
Assert ((Get-PcMenuHeading Windows) -eq 'WINDOWS TOOLKIT 0.20.0') 'Root menu uses the toolkit product heading without a redundant breadcrumb'
Assert ((Get-PcMenuHeading 'Windows > Network') -eq 'WINDOWS 0.20.0 | Windows > Network') 'Submenus retain their navigation breadcrumb'
Assert ((Get-PcMenuPageSize 29 1 12) -eq 10) 'A 29-row two-line browser uses ten items'
Assert ((Get-PcMenuPageSize 49 1 100) -eq 20) 'Tall terminals are not artificially capped at twelve items'
Assert ((Get-PcMenuPageSize 29 3 20) -eq 5) 'Expanded previews account for all detail lines'
Assert ((Get-PcMenuPageSize 12 1 12) -eq 1) 'Very short terminals retain at least one item'
$script:Output.Clear()
Write-PcMenuSegments @([pscustomobject]@{Text='binary.exe';Color='Cyan'},[pscustomobject]@{Text=' C:\long\path';Color='Gray'}) '> [1] ' 18 'White'
Assert ((($script:Output -join '').Length -eq 18) -and (($script:Output -join '') -match '\.\.\.$')) 'Segmented coloured rows remain bounded'
foreach($pair in @(@('UpArrow','Up'),@('DownArrow','Down'),@('Enter','Select'),@('Escape','Back'),@('Backspace','Back'),@('PageUp','Previous'),@('PageDown','Next'),@('Home','First'),@('End','Last'))){
 $key=[ConsoleKeyInfo]::new([char]0,[ConsoleKey]$pair[0],$false,$false,$false)
 Assert ((ConvertFrom-PcMenuKey $key) -eq $pair[1]) "Key maps: $($pair[0])"
}
$shortcuts=@(New-PcMenuItem '9' 'Health';New-PcMenuItem '1' 'Network';New-PcMenuItem 'C' 'Custom')
Feed @('1');$result=Show-PcMenu -Title Test -Items $shortcuts -Plain
Assert ($result.Item.Id -eq '1') 'Stable numeric shortcut is independent of row position'
Feed @('c');$result=Show-PcMenu -Title Test -Items $shortcuts -Plain
Assert ($result.Item.Id -eq 'C') 'Letter shortcut is case insensitive'
$blocked=$false;try{Show-PcMenu -Title Test -Items @((New-PcMenuItem '0' 'Reserved')) -Plain}catch{$blocked=$true}
Assert $blocked 'Reserved back key cannot be assigned to an action'
Feed @('C');$state=@{SelectedId='item3';Filter=''};$result=Show-PcMenu -Title Test -Items $items -State $state -Commands @{C='Review toggle'} -Plain
Assert ($result.Action -eq 'Command' -and $result.Command -eq 'C' -and $state.SelectedId -eq 'item3') 'List command returns without losing selection'
$script:Output.Clear();Feed @('B')
$null=Show-PcMenu -Title Test -Items @([pscustomobject]@{Id='event';Label='Event';Detail='short';SelectedDetail=@('first','second','third')}) -ExpandedPreview -Plain
Assert ($script:Output -contains '    third') 'Selected event renders three preview lines'
$script:Output.Clear();Feed @('B')
$null=Show-PcMenu -Title Test -Items @([pscustomobject]@{Id='startup';Label='Startup';Detail=@('command','source')}) -DetailLines 2 -Plain
Assert ($script:Output -contains '    source') 'Startup source stays visible beside command'
$blocked=$false;try{Show-PcMenu -Title Test -Items $items -Filterable -Commands @{F='conflict'} -Plain}catch{$blocked=$true}
Assert $blocked 'Custom command cannot override filter control'
Assert ($script:Answers.Count -eq 0) 'All expected prompts consumed'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN MENU ENGINE',2)[1] -split '# END MENU ENGINE',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/Menu-Engine.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded menu engine matches source'

$script:DetailColors.Clear();Feed @('B')
$null=Show-PcMenu -Title Colors -Items @([pscustomobject]@{Id='one';Label='Selected';Detail=@('path','source')}) -DetailLines 2 -Plain
Assert (($script:DetailColors -join ',') -eq 'Cyan,Cyan') 'Both description lines share the selected highlight'

$script:RawKeys=New-Object 'Collections.Generic.Queue[ConsoleKeyInfo]'
function Read-PcMenuKey {if(-not $script:RawKeys.Count){throw 'Unexpected key read'};$script:RawKeys.Dequeue()}
foreach($pair in @(@('D1','1'),@('D2','2'),@('Backspace',[char]8),@('D0','0'),@('Enter',[char]13))){$script:RawKeys.Enqueue([ConsoleKeyInfo]::new([char]$pair[1],[ConsoleKey]$pair[0],$false,$false,$false))}
$script:Output.Clear()
Assert ((Read-PcMenuInput $true) -eq '10') 'Visible input supports multidigit selection and Backspace editing'
Assert (($script:Output -join '|') -match 'Selection: 12_' -and ($script:Output -join '|') -match 'Selection: 10_') 'Typed digits are displayed before submission'
$script:RawKeys.Enqueue([ConsoleKeyInfo]::new('3',[ConsoleKey]::D3,$false,$false,$false))
$script:RawKeys.Enqueue([ConsoleKeyInfo]::new([char]27,[ConsoleKey]::Escape,$false,$false,$false))
Assert ((Read-PcMenuInput $true) -eq 'Back') 'Escape cancels pending numeric input'
$script:RawKeys.Enqueue([ConsoleKeyInfo]::new([char]13,[ConsoleKey]::Enter,$false,$false,$false))
Assert ((Read-PcMenuInput $true) -eq 'Select') 'Pending digits do not leak into subsequent prompts'

$script:IncrementalAnswers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('Down','Up','B')){$script:IncrementalAnswers.Enqueue($answer)}
$script:IncrementalClears=0;$script:IncrementalMoves=0
function Test-PcMenuKeyboard {$true}
function Test-PcMenuCursorControl {$true}
function Get-PcMenuCursorTop {0}
function Set-PcMenuCursorPosition {param($Left,$Top) $script:IncrementalMoves++}
function Clear-Host {$script:IncrementalClears++}
function Read-PcMenuInput {param($Keyboard) if(-not $script:IncrementalAnswers.Count){throw 'Unexpected incremental input'};$script:IncrementalAnswers.Dequeue()}
$incrementalState=@{}
$incrementalResult=Show-PcMenu -Title Incremental -Items @([pscustomobject]@{Id='one';Label='One';Detail='First'},[pscustomobject]@{Id='two';Label='Two';Detail='Second'}) -State $incrementalState
Assert ($incrementalResult.Action -eq 'Back' -and $incrementalState.SelectedId -eq 'one') 'Incremental navigation preserves selection behavior'
Assert ($script:IncrementalClears -eq 1 -and $script:IncrementalMoves -gt 0) 'Same-page arrow navigation repaints rows without clearing the screen'
