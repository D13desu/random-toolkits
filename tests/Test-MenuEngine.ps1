$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Menu-Engine.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
$script:Output=New-Object 'Collections.Generic.List[string]'
function Write-Host {param($Object,$ForegroundColor) $script:Output.Add([string]$Object)}
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
Assert ($script:Answers.Count -eq 0) 'All expected prompts consumed'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN MENU ENGINE',2)[1] -split '# END MENU ENGINE',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/Menu-Engine.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded menu engine matches source'
