param([switch]$KeyboardMode)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
Assert ((@(Format-PcEventPreview "first`r`nsecond`tthird" 40) -join '') -eq 'first second third') 'Multiline body preview is readable without opening event'
$preview=@(Format-PcEventPreview ('word '*100) 40)
Assert ($preview.Count -eq 3 -and $preview[-1].EndsWith(' ...')) 'Long messages have a bounded three-line preview and truncation marker'
Assert ((Format-PcEventPreview '') -like '*XML*') 'Missing message points to raw XML'
$script:Queries=0
function Get-WinEvent {
 [CmdletBinding()]param($FilterHashtable,$MaxEvents)
 $script:Queries++
 foreach($i in 1..8){
  $row=[pscustomobject]@{TimeCreated=(Get-Date);Id=42;LevelDisplayName='Information';ProviderName='Fixture';LogName='Application';RecordId=$i;MachineName='TEST';Message="Body $i`r`nSecond line $i"}
  $row | Add-Member ScriptMethod ToXml {return ('<Event><RecordID>'+$this.RecordId+'</RecordID></Event>')}
  $row
 }
}
$script:Output=New-Object 'Collections.Generic.List[string]'
function Write-Host {param($Object,$ForegroundColor) $script:Output.Add([string]$Object)}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('Last','First','Down','Down','Down','Down','Down','Up','Down','Select','X','M','B','P','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
if($KeyboardMode){
 function Test-PcMenuKeyboard {$true}
 function Clear-Host {}
 function Read-PcMenuInput {param($Keyboard,$Prompt) Read-Host $Prompt}
}
Start-PcEventBrowser -DefaultLog Application -Quick
Assert ($script:Answers.Count -eq 0) 'Preview paging and detail return preserve browser navigation'
$eventColorItem=New-PcEventMenuItem ([pscustomobject]@{Time='now';Level='Error';Id=42;Provider='Fixture';Log='Application';RecordId=99;Message='Failure'})
Assert (($eventColorItem.LabelParts | Where-Object Text -EQ Error).Color -eq 'Red') 'Event errors use failure colour'
Assert (($eventColorItem.LabelParts | Where-Object Text -EQ 42).Color -eq 'Magenta') 'Event IDs use numeric identifier colour'
Assert (($script:Output -join '|') -match 'Body 1 Second line 1') 'List renders message bodies'
Assert ($script:Output -contains "Body 6`r`nSecond line 6") 'Detail retains complete original multiline message'
Assert ($script:Output -contains '<Event><RecordID>6</RecordID></Event>' -and $script:Queries -eq 1) 'XML comes from the same cached event, without a second log query'
foreach($pair in @(@('UpArrow','@UP'),@('DownArrow','@DOWN'),@('Enter','@ENTER'),@('RightArrow','@ENTER'),@('LeftArrow','B'),@('Escape','B'),@('PageUp','P'),@('PageDown','N'),@('Home','@HOME'),@('End','@END'))){
 $key=[ConsoleKeyInfo]::new([char]0,[ConsoleKey]$pair[0],$false,$false,$false)
 Assert ((ConvertFrom-PcEventKey $key) -eq $pair[1]) "Keyboard mapping: $($pair[0])"
}
