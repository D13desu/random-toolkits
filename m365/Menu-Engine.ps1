# Shared M365 menu input and incremental row rendering.
$script:M365MenuRows=@()

function Test-M365MenuKeyboard {
 try{return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected}catch{return $false}
}
function Test-M365MenuCursor {
 try{return (Test-M365MenuKeyboard) -and [Console]::CursorTop -ge 0}catch{return $false}
}
function Read-M365MenuKey { return [Console]::ReadKey($true) }
function Get-M365MenuCursorTop { return [Console]::CursorTop }
function Set-M365MenuCursorPosition([int]$Left,[int]$Top) { [Console]::SetCursorPosition($Left,$Top) }
function Reset-M365Menu {
 $script:M365MenuRows=@()
}
function Format-M365MenuText([AllowNull()][string]$Text,[int]$Width=100) {
 $clean=([string]$Text -replace '[\x00-\x1F\x7F]',' ')
 $Width=[math]::Max(12,$Width)
 if($clean.Length -le $Width){return $clean}
 $length=$Width-3
 if([char]::IsHighSurrogate($clean[$length-1])){$length--}
 return $clean.Substring(0,$length)+'...'
}
function Get-M365MenuWidth {
 try{return [math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{return 100}
}
function Write-M365MenuRow($Row,[bool]$Selected,[int]$Width) {
 $marker=if($Selected){'>'}else{' '}
 $color=if($Selected){'Cyan'}elseif($Row.Key -eq '0'){'DarkGray'}else{'White'}
 Write-Host (Format-M365MenuText ('{0} [{1}] {2}' -f $marker,$Row.Key,$Row.Label) $Width).PadRight($Width) -ForegroundColor $color
}
function Write-M365MenuOptions([string]$Options) {
 $width=Get-M365MenuWidth
 foreach($line in ($Options -split "`n")){
  if($line -match '^\[([^]]+)\]\s*(.*)$'){
   $top=if(Test-M365MenuCursor){Get-M365MenuCursorTop}else{-1}
   $row=[pscustomobject]@{Key=$Matches[1].Trim().ToUpperInvariant();Label=$Matches[2].Trim();Top=$top}
   $script:M365MenuRows+=,$row
   Write-M365MenuRow $row $false $width
  } elseif([string]::IsNullOrWhiteSpace($line)){Write-Host ''}
  else{Write-Host $line -ForegroundColor Cyan}
 }
}
function Set-M365MenuRow($Row,[bool]$Selected,[int]$ReturnTop,[int]$Width) {
 if($Row.Top -lt 0){return}
 Set-M365MenuCursorPosition 0 ([int]$Row.Top)
 Write-M365MenuRow $Row $Selected $Width
 Set-M365MenuCursorPosition 0 $ReturnTop
}
function Write-M365MenuSelection([string]$Digits) {
 Write-Host ("`rSelection: {0,-10}" -f ($Digits+'_')) -NoNewline -ForegroundColor Cyan
}
function Read-M365MenuChoice([string]$Prompt='Select') {
 $rows=@($script:M365MenuRows)
 try {
  if(-not $rows.Count -or -not (Test-M365MenuKeyboard)){return (Read-Host $Prompt).Trim()}
  $width=Get-M365MenuWidth;$selected=0;$digits=''
  Write-Host 'Arrows + Enter or shortcut + Enter | Esc/Backspace: back' -ForegroundColor DarkGray
  $promptTop=Get-M365MenuCursorTop
  Write-M365MenuSelection $digits
  Set-M365MenuRow $rows[$selected] $true $promptTop $width
  while($true){
   $key=Read-M365MenuKey
   if($key.Key -eq 'PageDown'){return 'N'}
   if($key.Key -eq 'PageUp'){return 'P'}
   if($key.Key -eq 'UpArrow' -or $key.Key -eq 'DownArrow' -or $key.Key -eq 'Home' -or $key.Key -eq 'End'){
    $old=$selected
    switch($key.Key){
     'UpArrow' {$selected=[math]::Max(0,$selected-1)}
     'DownArrow' {$selected=[math]::Min($rows.Count-1,$selected+1)}
     'Home' {$selected=0}
     'End' {$selected=$rows.Count-1}
    }
    if($selected -ne $old){Set-M365MenuRow $rows[$old] $false $promptTop $width;Set-M365MenuRow $rows[$selected] $true $promptTop $width}
    continue
   }
   if($key.Key -eq 'Escape' -or ($key.Key -eq 'Backspace' -and -not $digits)){return '0'}
   if($key.Key -eq 'Backspace'){$digits=$digits.Substring(0,$digits.Length-1);Write-M365MenuSelection $digits;continue}
   if($key.Key -eq 'Enter'){
    if($digits){$match=$rows|Where-Object Key -EQ $digits|Select-Object -First 1;if($match){return $match.Key};$digits='';Write-M365MenuSelection $digits;continue}
    return [string]$rows[$selected].Key
   }
   $char=[string]$key.KeyChar
   if($char -match '^\d$'){$digits+=$char;Write-M365MenuSelection $digits;continue}
   if($char -match '^[A-Za-z]$'){$match=$rows|Where-Object Key -EQ $char.ToUpperInvariant()|Select-Object -First 1;if($match){return $match.Key}}
  }
 } finally {Reset-M365Menu;Write-Host ''}
}

function Show-M365RecordMenu {
 param(
  [object[]]$Items,
  [string]$Title,
  [scriptblock]$Label,
  [string]$Commands='[0] Back',
  [scriptblock]$Header
 )
 $Items=@($Items);$page=0
 while($true){
  $height=30;try{$height=$Host.UI.RawUI.WindowSize.Height}catch{}
  $size=[math]::Max(1,[math]::Min(100,$height-10))
  $pages=[math]::Max(1,[math]::Ceiling($Items.Count/[double]$size))
  if($page -ge $pages){$page=$pages-1}
  Head $Title
  if($Header){& $Header}
  Write-Host ("Records: {0} | Page: {1}/{2}" -f $Items.Count,($page+1),$pages) -ForegroundColor DarkGray
  $start=$page*$size;$end=[math]::Min($Items.Count,$start+$size)
  for($i=$start;$i -lt $end;$i++){
   $text=& $Label $Items[$i] $i
   Write-M365MenuOptions ('[{0}] {1}' -f ($i+1),$text)
  }
  if($pages -gt 1){Write-M365MenuOptions "[N] Next page`n[P] Previous page"}
  Write-M365MenuOptions $Commands
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant();$number=0
  if([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $Items.Count){
   return [pscustomobject]@{Action='Select';Item=$Items[$number-1];Index=$number-1}
  }
  if($choice -eq 'N' -and $page+1 -lt $pages){$page++;continue}
  if($choice -eq 'P' -and $page -gt 0){$page--;continue}
  return [pscustomobject]@{Action=$choice;Item=$null;Index=-1}
 }
}
