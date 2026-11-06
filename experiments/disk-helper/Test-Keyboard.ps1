$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Helper-Ui.ps1')
foreach($pair in @(@('UpArrow','@UP'),@('DownArrow','@DOWN'),@('RightArrow','@ENTER'),@('LeftArrow','B'),@('Backspace','B'),@('Escape','B'),@('PageDown','N'),@('PageUp','P'),@('Enter','@ENTER'))){
 $key=[ConsoleKeyInfo]::new([char]0,[ConsoleKey]$pair[0],$false,$false,$false)
 if((ConvertFrom-HelperKey $key) -ne $pair[1]){throw "Incorrect key mapping: $($pair[0])"}
}
$key=[ConsoleKeyInfo]::new([char]13,[ConsoleKey]::Enter,$false,$false,$true)
if((ConvertFrom-HelperKey $key) -ne '@EXPLORER'){throw 'Ctrl+Enter mapping failed'}
function Start-Process {param($FilePath,$ArgumentList,$ErrorAction) $script:Launch=@($FilePath,$ArgumentList)}
$fixture=Join-Path $env:TEMP ('helper keyboard '+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($fixture)
Open-HelperDirectory $fixture
if($script:Launch[0] -ne (Join-Path $env:WINDIR 'explorer.exe') -or $script:Launch[1] -ne ('"'+$fixture+'\."')){throw 'Explorer path quoting failed'}
$script:Launch=$null
$failed=$false
try {Open-HelperDirectory (Join-Path $fixture 'missing')}catch{$failed=$true}
if(-not $failed -or $script:Launch){throw 'Missing directory launched'}
function Get-HelperVolumeInfo {param($Root)[pscustomobject]@{IsReady=$true;AvailableFreeSpace=25GB}}
if((Get-HelperAvailableBytes $fixture) -ne 25GB){throw 'Available bytes were not read from the containing volume'}
'PASS: Arrow/navigation keys, Ctrl+Enter, quoted Explorer directory argument and missing-path rejection.'
