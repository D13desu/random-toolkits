#requires -Version 7.4
# M365 Toolkit 0.4.0 - LIVE ONLY - read-only investigation
$ErrorActionPreference = 'Stop'
$script:OutDir = Join-Path $PSScriptRoot 'reports'
# BEGIN M365 MENU ENGINE
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
# END M365 MENU ENGINE
# Shared console theme: labels are muted, values bright; state colors are semantic.
function Write-Field([string]$Label, $Value, [string]$Kind='Normal') {
 $display=if($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)){'—'}else{[string]$Value}
 $color=switch($Kind){
  'Good' {'Green'}
  'Bad' {'Red'}
  'Warning' {'Yellow'}
  'Info' {'Cyan'}
  default {'White'}
 }
 Write-Host ("{0,-22}: " -f $Label) -ForegroundColor Cyan -NoNewline
 Write-Host $display -ForegroundColor $color
}
function Write-Section([string]$Title) {
 Write-Host ''
 Write-Host ("  {0}" -f $Title.ToUpperInvariant()) -ForegroundColor Cyan
 Write-Host ('  ' + ('-' * [math]::Min(46,[math]::Max(12,$Title.Length+8)))) -ForegroundColor DarkGray
}
function Write-Menu([string]$Options,[ConsoleColor]$ForegroundColor=[ConsoleColor]::White) {
 Write-M365MenuOptions $Options
}
function Write-ColorTable([object[]]$Rows,[string[]]$Columns,[int[]]$Widths) {
 if(-not $Rows -or $Rows.Count -eq 0){Write-Host 'No records returned.' -ForegroundColor Yellow;return}
 for($i=0;$i -lt $Columns.Count;$i++){
  Write-Host $Columns[$i].PadRight($Widths[$i]) -ForegroundColor Cyan -NoNewline
  Write-Host '  ' -NoNewline
 }
 Write-Host ''
 foreach($row in $Rows){
  for($i=0;$i -lt $Columns.Count;$i++){
   $v=[string]$row.($Columns[$i]); if($v.Length -gt $Widths[$i]){$v=$v.Substring(0,[math]::Max(1,$Widths[$i]-1))+'…'}
   $color='White'
   if($Columns[$i] -in @('Enabled','MFA','State')) {
    $color=switch -Regex ($v.ToLowerInvariant()) {'^(yes|true|enabled)$' {'Green';break} '^(no|false|disabled)$' {'Red';break} default {'Yellow'}}
   } elseif($Columns[$i] -in @('No','Lic','LastSuccess','Id')) {$color='DarkGray'}
   elseif($Columns[$i] -eq 'UPN'){$color='Cyan'}
   Write-Host $v.PadRight($Widths[$i]) -ForegroundColor $color -NoNewline
   Write-Host '  ' -NoNewline
  }
  Write-Host ''
 }
}
function Wait-Key { [void](Read-Host 'Press Enter to continue') }
function Head([string]$title) { Reset-M365Menu; Clear-Host; Write-Host ('=' * 54) -ForegroundColor Cyan; Write-Host " M365 TOOLKIT 0.4.0 | $title" -ForegroundColor Cyan; Write-Host ('=' * 54) -ForegroundColor Cyan; Write-Host ' READ ONLY' -ForegroundColor Yellow; Write-Host '' }
function Need([string]$module) {
 if (-not (Get-Module -ListAvailable -Name $module)) {
  throw "Missing $module. Run: Install-Module -Name $module -Scope CurrentUser"
 }
 Import-Module $module -ErrorAction Stop
}
function Graph-Context {
 if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) { return $null }
 Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
 return Get-MgContext
}
function EXO-Connections {
 if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) { return @() }
 Import-Module ExchangeOnlineManagement -ErrorAction Stop
 return @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object State -eq 'Connected')
}
function Graph-Connect {
 Need 'Microsoft.Graph.Authentication'
 $scopes=@('User.Read.All','Directory.Read.All','AuditLog.Read.All','Reports.Read.All','Policy.Read.All','IdentityRiskyUser.Read.All','IdentityRiskEvent.Read.All')
 $defaultChoice=if($IsWindows){'1'}else{'2'}
 Write-Section 'Microsoft Graph authentication'
 Write-Menu "[1] Browser authentication`n[2] Device-code authentication"
 $choice=(Read-Host "Select (default $defaultChoice)").Trim()
 if(-not $choice){$choice=$defaultChoice}
 if($choice -notin @('1','2')){throw "Invalid authentication choice: $choice"}
 Write-Field 'Connection' 'Starting...' 'Info'
 Write-Field 'Mode' $(if($choice -eq '2'){'Device code'}else{'Browser'})
 Write-Field 'Requested scopes' ($scopes -join ', ')
 if($choice -eq '2'){Write-Host 'Waiting for device-code instructions...' -ForegroundColor Yellow}
 if($choice -eq '2'){
  Connect-MgGraph -Scopes $scopes -UseDeviceCode -NoWelcome -ContextScope Process -ErrorAction Stop
 }else{
  Connect-MgGraph -Scopes $scopes -NoWelcome -ContextScope Process -ErrorAction Stop
 }
 $ctx=Get-MgContext
 if(-not $ctx){throw 'No Microsoft Graph context after authentication.'}
 Write-Field 'Connected account' $ctx.Account 'Good'
}

function Graph-Ready { Need 'Microsoft.Graph.Authentication'; if (-not (Get-MgContext)) { Graph-Connect }; if (-not (Get-MgContext)) {throw 'Microsoft Graph is not connected'} }
function EXO-Connect {
 Need 'ExchangeOnlineManagement'
 Write-Section 'Exchange Online authentication'
 $defaultChoice=if($IsWindows){'1'}else{'2'}
 Write-Menu "[1] Browser authentication`n[2] Device-code authentication"
 $choice=(Read-Host "Select (default $defaultChoice)").Trim()
 if(-not $choice){$choice=$defaultChoice}
 if($choice -notin @('1','2')){throw "Invalid authentication choice: $choice"}
 $params=@{ShowBanner=$false;ErrorAction='Stop'}
 if($choice -eq '2'){
  $cmd=Get-Command Connect-ExchangeOnline -ErrorAction Stop
  if(-not $cmd.Parameters.ContainsKey('Device')){throw 'Installed ExchangeOnlineManagement does not support -Device. Update the module and retry.'}
  $params.Device=$true
  Write-Field 'Authentication' 'Device code' 'Info'
  Write-Host 'Follow the device-code instructions displayed below.' -ForegroundColor Yellow
 } else {
  Write-Field 'Authentication' 'Interactive browser' 'Info'
 }
 Connect-ExchangeOnline @params
 $connections=@(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object State -eq 'Connected')
 if(-not $connections.Count){throw 'Exchange Online authentication completed without an active connection.'}
 Write-Field 'Connected account' $connections[0].UserPrincipalName 'Good'
}
function EXO-Ready {
 Need 'ExchangeOnlineManagement'
 if(-not @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object State -eq 'Connected').Count){EXO-Connect}
 if(-not @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object State -eq 'Connected').Count){throw 'Exchange Online is not connected'}
}

function Convert-EvidenceJson($record) {
 # Serialize Graph SDK objects through their JSON representation rather than
 # walking deeply nested .NET object graphs. Preserve the original object for
 # property inspection even if the JSON serializer cannot handle a value.
 try {
  $json = ConvertTo-Json -InputObject $record -Depth 100 -WarningAction Stop -ErrorAction Stop
  return $json
 } catch {
  Write-Warning "Full JSON serialization failed: $($_.Exception.Message)"
  throw
 }
}
function Save-Evidence($items,[string]$label) {
 New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
 $name=($label -replace '[^a-zA-Z0-9_-]','_')
 $path=Join-Path $script:OutDir "$name-$(Get-Date -Format yyyyMMdd-HHmmss).json"
 Convert-EvidenceJson @($items) | Set-Content -Path $path -Encoding utf8
 Write-Host "Saved: $path" -ForegroundColor Green
}
function Raw-Record($record) {
 if($null -eq $record) { Write-Host 'No record'; return }
 if($record.PSObject.Properties.Name -contains 'User' -and $record.PSObject.Properties.Name -contains 'ResolvedObjectId') {
  Write-Host "Resolved object ID: $($record.ResolvedObjectId)" -ForegroundColor Cyan
  Write-Host 'User properties:' -ForegroundColor Cyan
  $record.User | Format-List * -Force | Out-Host
  Write-Host 'Sign-in activity:' -ForegroundColor Cyan
  if($record.SignInActivity) {$record.SignInActivity | Format-List * -Force | Out-Host}
  else { Write-Host "Unavailable: $($record.SignInActivityError)" }
 } else { $record | Format-List * -Force | Out-Host }
 Write-Host 'Nested JSON:' -ForegroundColor Cyan
 try { Convert-EvidenceJson $record | Out-Host }
 catch { Write-Warning 'JSON unavailable; full PowerShell properties are shown above.' }
}
function Value-OrUnknown($value) {
 if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return 'Not provided' }
 return [string]$value
}
function Get-MfaSignInSummary($event) {
 $requirement=Value-OrUnknown $event.AuthenticationRequirement
 $methods=@($event.AuthenticationMethodsUsed | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
 $details=@($event.AuthenticationDetails | Where-Object { $null -ne $_ })
 $mfaSteps=@($details | Where-Object { ([string]$_.AuthenticationMethod -match 'authenticator|fido|sms|phone|oath|certificate|passkey|multi.factor|push') -or ([string]$_.AuthenticationStepRequirement -match 'multiFactor') })
 $methodText=if($methods.Count){$methods -join ', '}elseif($mfaSteps.Count){(@($mfaSteps | ForEach-Object {$_.AuthenticationMethod} | Where-Object {$_} | Select-Object -Unique) -join ', ')}else{'Not provided'}
 $stepResult=if($mfaSteps.Count){
  (@($mfaSteps | ForEach-Object { if($_.Succeeded -eq $true){'Succeeded'}elseif($_.Succeeded -eq $false){'Failed'}else{'Unknown'} } | Select-Object -Unique) -join ', ')
 }else{'Not recorded'}
 # Do not infer MFA success from overall sign-in success or requirement alone.
 return [pscustomobject]@{ Requirement=$requirement; Methods=$methodText; MfaStepResult=$stepResult; ConditionalAccess=(Value-OrUnknown $event.ConditionalAccessStatus) }
}
function Get-MfaRegistration([string]$id) {
 $uri="https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails/$id"
 try {
  $raw=Get-GraphRaw $uri
  return [pscustomobject]@{Data=(ConvertFrom-Json -InputObject $raw -Depth 100);Raw=$raw;Error=$null}
 } catch {
  return [pscustomobject]@{Data=$null;Raw=$null;Error=$_.Exception.Message}
 }
}
function Show-MfaRegistration($registration) {
 Head 'MFA registration details'
 if($registration.Error){Write-Warning "Registration data unavailable: $($registration.Error)"}
 elseif($registration.Data){
  $r=$registration.Data
  Write-Host "MFA registered       : $(Value-OrUnknown $r.isMfaRegistered)"
  Write-Host "MFA capable          : $(Value-OrUnknown $r.isMfaCapable)"
  Write-Host "Passwordless capable : $(Value-OrUnknown $r.isPasswordlessCapable)"
  Write-Host "Methods registered   : $(@($r.methodsRegistered) -join ', ')"
  Write-Host "Preferred method     : $(Value-OrUnknown $r.userPreferredMethodForSecondaryAuthentication)"
  Write-Host "System preferred MFA : $(Value-OrUnknown $r.isSystemPreferredAuthenticationMethodEnabled)"
  Write-Menu "[1] All returned properties`n[2] Original Graph JSON`n[3] Export original Graph JSON`n[0] Back"
  while($true){
   $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
   switch($choice){
    '1' {$r | Format-List * | Out-Host; Wait-Key}
    '2' {$registration.Raw | Out-Host; Wait-Key}
    '3' {
     New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
     $path=Join-Path $script:OutDir "mfa-registration-$(Get-Date -Format yyyyMMdd-HHmmss).json"
     [System.IO.File]::WriteAllText($path,$registration.Raw,[System.Text.UTF8Encoding]::new($false))
     Write-Host "Saved: $path"; Wait-Key
    }
    '0' {return}
   }
  }
 } else {Write-Host 'No registration data returned.'}
 Wait-Key
}
function Browse($items,[string]$title,[string]$kind) {
 $items=@($items)
 while($true){
  $commands="[A] All raw`n[E] Export JSON`n[0] Back"
  if($kind -eq 'sign'){$commands="[I] Investigate an event IP`n"+$commands}
  $result=Show-M365RecordMenu $items $title {
   param($r,$index)
   if($kind -eq 'sign'){
    $status=if($r.Status.ErrorCode -eq 0){'SUCCESS'}else{'FAILURE'}
    return "$($r.CreatedDateTime) | $status | $($r.UserPrincipalName) | $($r.IpAddress) | $($r.AppDisplayName)"
   }
   if($kind -eq 'audit'){
    $ip=try{($r.AuditData|ConvertFrom-Json).ClientIP}catch{'Not recorded'}
    return "$($r.CreationDate) | $($r.Operations) | $($r.UserIds) | $ip"
   }
   return "$($r.Name) | Enabled: $($r.Enabled) | Priority: $($r.Priority)"
  } $commands
  if($result.Action -eq '0'){return}
  if($result.Action -eq 'E'){Save-Evidence $items $title;Wait-Key;continue}
  if($result.Action -eq 'A'){foreach($r in $items){Raw-Record $r;Wait-Key};continue}
  if($result.Action -eq 'I' -and $kind -eq 'sign'){
   $n=0
   if([int]::TryParse((Read-Host 'Event number'),[ref]$n) -and $n -ge 1 -and $n -le $items.Count){Investigate-IP $items[$n-1].IpAddress}
   continue
  }
  if($result.Action -eq 'Select'){Raw-Record $result.Item;Wait-Key}
 }
}
$script:DefaultUPN = $null
$script:SavedTargets = [System.Collections.Generic.List[string]]::new()
function Add-Target([string]$upn) {
 $upn=$upn.Trim()
 if ($upn -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Enter a valid UPN in user@domain format.' }
 if (-not @($script:SavedTargets | Where-Object { $_ -ieq $upn }).Count) { $script:SavedTargets.Add($upn) }
 return $upn
}
function Set-DefaultUPN {
 $value=(Read-Host 'Target UPN (leave blank to cancel)').Trim()
 if (-not $value) { return }
 $script:DefaultUPN=Add-Target $value
 Write-Host "Active target: $script:DefaultUPN" -ForegroundColor Green
}
function Choose-Target {
 if ($script:SavedTargets.Count -eq 0) { Write-Host 'No saved targets in this session.'; return }
 Write-Host 'Saved investigation targets:'
 for($i=0;$i -lt $script:SavedTargets.Count;$i++) {
  $mark=if($script:SavedTargets[$i] -ieq $script:DefaultUPN){' (active)'}else{''}
  Write-Host "[$($i+1)] $($script:SavedTargets[$i])$mark"
 }
 $answer=(Read-Host 'Target number (blank cancels)').Trim()
 if (-not $answer) { return }
 $number=0
 if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $script:SavedTargets.Count) { throw 'Invalid target number.' }
 $script:DefaultUPN=$script:SavedTargets[$number-1]
 Write-Host "Active target: $script:DefaultUPN" -ForegroundColor Green
}
function Remove-Target {
 if ($script:SavedTargets.Count -eq 0) { Write-Host 'No saved targets in this session.'; return }
 for($i=0;$i -lt $script:SavedTargets.Count;$i++){Write-Host "[$($i+1)] $($script:SavedTargets[$i])"}
 $answer=(Read-Host 'Remove target number (blank cancels)').Trim()
 if (-not $answer) { return }
 $number=0
 if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $script:SavedTargets.Count) { throw 'Invalid target number.' }
 $removed=$script:SavedTargets[$number-1]
 $script:SavedTargets.RemoveAt($number-1)
 if ($script:DefaultUPN -ieq $removed) { $script:DefaultUPN=if($script:SavedTargets.Count){$script:SavedTargets[0]}else{$null} }
 Write-Host "Removed: $removed"
}
function Ask-UPN {
 if ($script:DefaultUPN) { return $script:DefaultUPN }
 $u=(Read-Host 'User principal name').Trim()
 if(-not $u){throw 'User principal name required'}
 $script:DefaultUPN=Add-Target $u
 return $script:DefaultUPN
}
function Date-Window { $days=Read-Host 'Lookback days (default 7)'; if(-not $days){$days='7'}; $n=0; if(-not [int]::TryParse($days,[ref]$n) -or $n -lt 1 -or $n -gt 180){throw 'Lookback must be 1-180 days (subject to tenant retention)'}; return (Get-Date).ToUniversalTime().AddDays(-$n).ToString('yyyy-MM-ddTHH:mm:ssZ') }
function Resolve-GraphUser([string]$upn) {
 Need 'Microsoft.Graph.Users'
 $escaped=$upn.Replace("'", "''")
 $matches=@(Get-MgUser -Filter "userPrincipalName eq '$escaped'" -Property @('id','displayName','userPrincipalName') -All -ErrorAction Stop)
 if($matches.Count -eq 0) { throw "No user found for UPN: $upn" }
 if($matches.Count -gt 1) { throw "Multiple users matched UPN: $upn" }
 if(-not $matches[0].Id) { throw 'Graph returned a user without an object ID' }
 return $matches[0]
}
function Get-GraphRaw([string]$uri) {
 # The raw HTTP response avoids serializing deeply nested Graph SDK objects.
 $response=Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType HttpResponseMessage -ErrorAction Stop
 if(-not $response.IsSuccessStatusCode){throw "Graph HTTP $([int]$response.StatusCode): $($response.ReasonPhrase)"}
 return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
}
function Get-GraphPaged([string]$uri) {
 $items=[System.Collections.Generic.List[object]]::new()
 $page=0
 while($uri) {
  $page++
  if($page -gt 100){throw 'Graph pagination exceeded 100 pages; results incomplete.'}
  $json=Get-GraphRaw $uri
  $obj=ConvertFrom-Json -InputObject $json -Depth 100
  foreach($item in @($obj.value)){if($null -ne $item){$items.Add($item)}}
  $uri=$obj.'@odata.nextLink'
 }
 return $items.ToArray()
}
function Get-LicenseInventory([string]$id) {
 $skuById=@{}
 $skuError=$null
 try {
  foreach($sku in @(Get-GraphPaged 'https://graph.microsoft.com/v1.0/subscribedSkus?$select=skuId,skuPartNumber,servicePlans')) {
   $skuById[[string]$sku.skuId]=$sku
  }
 } catch { $skuError=$_.Exception.Message; Write-Warning "Tenant SKU mapping unavailable: $skuError" }
 $details=@()
 $detailError=$null
 try { $details=@(Get-GraphPaged "https://graph.microsoft.com/v1.0/users/$id/licenseDetails") }
 catch { $detailError=$_.Exception.Message; Write-Warning "License details unavailable: $detailError" }
 return [pscustomobject]@{SkuById=$skuById;Details=$details;SkuError=$skuError;DetailError=$detailError}
}
function Show-LicenseDetails($user,$inventory) {
 Head 'Detailed license information'
 $assignments=@($user.licenseAssignmentStates | Where-Object { $null -ne $_ })
 if($assignments.Count -eq 0){Write-Host 'No assignment paths returned.'}
 foreach($state in $assignments){
  $sku=$inventory.SkuById[[string]$state.skuId]
  $product=if($sku){$sku.skuPartNumber}else{[string]$state.skuId}
  $source=if($state.assignedByGroup){"Group: $($state.assignedByGroup)"}else{'Direct'}
  Write-Host "`nProduct: $product | Assignment: $source | State: $($state.state)" -ForegroundColor Cyan
  Write-Host "SKU ID: $($state.skuId)"
  if($state.error){Write-Host "Assignment error: $($state.error)" -ForegroundColor Yellow}
  if($state.disabledPlans){Write-Host "Disabled plan IDs: $($state.disabledPlans -join ', ')"}
 }
 foreach($detail in $inventory.Details){
  $sku=$inventory.SkuById[[string]$detail.skuId]
  $product=if($sku){$sku.skuPartNumber}else{$detail.skuPartNumber}
  Write-Host "`nService plans for $product" -ForegroundColor Cyan
  @($detail.servicePlans) | Select-Object servicePlanName,provisioningStatus,appliesTo,servicePlanId | Format-Table -AutoSize -Wrap | Out-Host
 }
 if($inventory.SkuError){Write-Warning "SKU lookup: $($inventory.SkuError)"}
 if($inventory.DetailError){Write-Warning "Service plan lookup: $($inventory.DetailError)"}
 Wait-Key
}
function User-Overview {
 Graph-Ready
 $upn=Ask-UPN
 $identity=Resolve-GraphUser $upn
 $id=$identity.Id
 # Request only actual API properties, including license assignment paths.
 $select='id,displayName,userPrincipalName,accountEnabled,createdDateTime,assignedLicenses,licenseAssignmentStates'
 $uri="https://graph.microsoft.com/v1.0/users/$id"+'?$select='+$select
 $raw=Get-GraphRaw $uri
 $user=ConvertFrom-Json -InputObject $raw -Depth 100
 $signInError=$null
 try {
  $activityRaw=Get-GraphRaw ("https://graph.microsoft.com/v1.0/users/$id"+'?$select=id,signInActivity')
  $activityResponse=ConvertFrom-Json -InputObject $activityRaw -Depth 100
  $user | Add-Member -NotePropertyName signInActivity -NotePropertyValue $activityResponse.signInActivity -Force
 } catch { $signInError=$_.Exception.Message; Write-Warning "Sign-in activity unavailable: $signInError" }
 $inventory=Get-LicenseInventory $id
 $mfaRegistration=Get-MfaRegistration $id
 $record=[pscustomobject]@{User=$user;LicenseDetails=$inventory.Details;TenantSkuMapping=@($inventory.SkuById.Values);SkuError=$inventory.SkuError;LicenseDetailsError=$inventory.DetailError}
 while($true){
  Head 'User overview'
  Write-Host "Display name       : $($user.displayName)"
  Write-Host "UPN                : $($user.userPrincipalName)"
  Write-Host "Account enabled    : $($user.accountEnabled)"
  Write-Host "Created            : $($user.createdDateTime)"
  Write-Host "Object ID          : $id"
  Write-Section 'Sign-in activity'
  Write-Host "Last interactive   : $($user.signInActivity.lastSignInDateTime)"
  Write-Host "Last noninteractive: $($user.signInActivity.lastNonInteractiveSignInDateTime)"
  Write-Host "Last successful    : $($user.signInActivity.lastSuccessfulSignInDateTime)"
  if($signInError){Write-Warning "Sign-in activity request failed: $signInError"}
  Write-Section 'Multifactor authentication (registration)'
  if($mfaRegistration.Data){
   Write-Field 'Registered' (Value-OrUnknown $mfaRegistration.Data.isMfaRegistered) $(if($mfaRegistration.Data.isMfaRegistered){'Good'}else{'Warning'})
   Write-Field 'MFA capable' (Value-OrUnknown $mfaRegistration.Data.isMfaCapable) $(if($mfaRegistration.Data.isMfaCapable){'Good'}else{'Warning'})
   Write-Field 'Passwordless capable' (Value-OrUnknown $mfaRegistration.Data.isPasswordlessCapable)
   Write-Field 'Registered methods' (@($mfaRegistration.Data.methodsRegistered) -join ', ')
  } else {Write-Host 'Unavailable (permissions, licensing, or API response).'}
  Write-Section 'Assigned licenses'
  $licenses=@($user.assignedLicenses | Where-Object {$null -ne $_})
  if($licenses.Count -eq 0){Write-Host 'No assigned licenses returned.'}
  foreach($license in $licenses){
   $sku=$inventory.SkuById[[string]$license.skuId]
   $name=if($sku){$sku.skuPartNumber}else{"SKU $($license.skuId)"}
   $paths=@($user.licenseAssignmentStates | Where-Object { $_.skuId -eq $license.skuId })
   $sources=@($paths | ForEach-Object {if($_.assignedByGroup){'Group'}else{'Direct'}} | Select-Object -Unique)
   $states=@($paths | ForEach-Object {$_.state} | Select-Object -Unique)
   Write-Host '  • ' -ForegroundColor DarkGray -NoNewline
   Write-Host $name -ForegroundColor White -NoNewline
   Write-Host (" | {0} | {1}" -f $(if($sources){$sources -join ', '}else{'Not returned'}), $(if($states){$states -join ', '}else{'Not returned'})) -ForegroundColor DarkGray
  }
  if($inventory.SkuError){Write-Warning 'Product SKU names could not be resolved; identifiers are displayed.'}
  Write-Menu "[1] All returned user properties`n[2] Detailed licenses and service plans`n[3] Raw Graph JSON`n[4] Export raw Graph JSON`n[5] Investigate sign-ins`n[6] Detailed MFA registration`n[0] Back"
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  switch($choice){
   '1' {$user | Format-List * -Force | Out-Host; Wait-Key}
   '2' {Show-LicenseDetails $user $inventory}
   '3' {Head 'Raw Microsoft Graph JSON'; $raw | Out-Host; Wait-Key}
   '4' {
    New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
    $path=Join-Path $script:OutDir "user-$id-$(Get-Date -Format yyyyMMdd-HHmmss).json"
    [System.IO.File]::WriteAllText($path,$raw,[System.Text.UTF8Encoding]::new($false))
    Write-Host "Saved original Graph response: $path" -ForegroundColor Green
    Wait-Key
   }
   '5' {Signins-ForUser $user.userPrincipalName}
   '6' {Show-MfaRegistration $mfaRegistration}
   '0' {return}
  }
 }
}

function ConditionalAccess-Policies {
 Graph-Ready
 while($true){
  Head 'Conditional Access policies'
  Write-Host 'Retrieving configured Conditional Access policies...'
  try {
   $policies=@(Get-GraphPaged 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$top=100')
  } catch {
   Write-Host "Unable to retrieve policies: $($_.Exception.Message)" -ForegroundColor Red
   Write-Host 'Verify Policy.Read.All permission and an appropriate Entra role.'
   Wait-Key
   return
  }
  :PolicyList while($true){
   Head 'Conditional Access policies'
   $enabled=@($policies | Where-Object state -eq 'enabled').Count
   $reportOnly=@($policies | Where-Object state -eq 'enabledForReportingButNotEnforced').Count
   $disabled=@($policies | Where-Object state -eq 'disabled').Count
   Write-Host "Total: $($policies.Count) | Enabled: $enabled | Report-only: $reportOnly | Disabled: $disabled"
   Write-Host 'Policy state is tenant-wide, not a per-user applicability result.'
   Write-Host ''
   $rows=@(for($i=0;$i -lt $policies.Count;$i++){
    $policy=$policies[$i]
    [pscustomobject]@{No=$i+1;Name=$policy.displayName;State=$policy.state;Id=$policy.id}
   })
   if($rows.Count){Write-ColorTable $rows @('No','Name','State','Id') @(3,38,15,36)}
   else{Write-Host 'No Conditional Access policies returned.'}
   Write-Menu '[R] Refresh  [E] Export all policy JSON  [0] Back'
   Write-Host 'Select a policy number for its complete returned configuration.'
   $choice=(Read-M365MenuChoice).Trim()
   $number=0
   if([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $policies.Count){
    $policy=$policies[$number-1]
    :PolicyDetail while($true){
     Head "Conditional Access: $($policy.displayName)"
     Write-Field 'Policy state' $policy.state $(if($policy.state -eq 'enabled'){'Good'}elseif($policy.state -eq 'disabled'){'Bad'}else{'Warning'}); Write-Field 'Policy ID' $policy.id
     Write-Menu '[1] Full policy properties (JSON)'
     Write-Menu '[2] Export this policy'
     Write-Menu '[0] Back'
     switch((Read-M365MenuChoice).Trim()){
      '1' {$policy | ConvertTo-Json -Depth 100 | Out-Host;Wait-Key}
      '2' {Save-Evidence $policy 'conditional-access-policy';Wait-Key}
      '0' {break PolicyDetail}
     }
    }
    continue
   }
   switch($choice.ToUpperInvariant()){
    'R' {break PolicyList}
    'E' {Save-Evidence $policies 'conditional-access-policies';Wait-Key}
    '0' {return}
   }
  }
 }
}

function Tenant-Users {
 Graph-Ready
 Head 'Tenant user directory'
 Write-Host 'Loading tenant users, MFA registration and Conditional Access policies...'
 $users=@(Get-GraphPaged 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,accountEnabled,assignedLicenses,signInActivity&$top=100')
 $registration=@{}; $mfaError=$null
 try {
  foreach($entry in @(Get-GraphPaged 'https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?$top=100')) {
   if($entry.id){$registration[[string]$entry.id]=$entry}
  }
 } catch {$mfaError=$_.Exception.Message}
 $policies=@();$caError=$null
 try {$policies=@(Get-GraphPaged 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$select=id,displayName,state&$top=100')}
 catch {$caError=$_.Exception.Message}
 $filter=''
 while($true){
  $matched=@($users | Where-Object {-not $filter -or $_.displayName -like "*$filter*" -or $_.userPrincipalName -like "*$filter*"})
  $result=Show-M365RecordMenu -Items $matched -Title 'Tenant user directory' -Label {
   param($u,$index)
   $r=$registration[[string]$u.id]
   $mfa=if($null -ne $r -and $null -ne $r.isMfaRegistered){if($r.isMfaRegistered){'MFA: Yes'}else{'MFA: No'}}else{'MFA: ?'}
   $enabled=if($u.accountEnabled){'Enabled'}else{'Disabled'}
   $last=if($u.signInActivity.lastSuccessfulSignInDateTime){try{([datetime]$u.signInActivity.lastSuccessfulSignInDateTime).ToString('yyyy-MM-dd')}catch{'Unknown'}}else{'-'}
   "$($u.userPrincipalName) | $enabled | $mfa | Lic: $(@($u.assignedLicenses).Count) | Last: $last"
  } -Commands "[F] Filter`n[C] View tenant CA policies`n[E] Export summary`n[0] Back" -Header {
   Write-Host "Users: $($users.Count) | Matches: $($matched.Count) | Filter: $filter"
   Write-Host "Conditional Access policies: $($policies.Count) | Enabled: $(@($policies | Where-Object state -eq 'enabled').Count) | Report-only: $(@($policies | Where-Object state -eq 'enabledForReportingButNotEnforced').Count) | Disabled: $(@($policies | Where-Object state -eq 'disabled').Count)"
   if($caError){Write-Warning "Policy inventory unavailable: $caError"}
   if($mfaError){Write-Warning "MFA registration unavailable: $mfaError"}
  }
  if($result.Action -eq 'Select'){
   $script:DefaultUPN=Add-Target ([string]$result.Item.userPrincipalName)
   User-Overview
   continue
  }
  switch($result.Action){
   'F' {$filter=(Read-Host 'Name or UPN contains (blank = all)').Trim()}
   'C' {
    Head 'Tenant Conditional Access policies'
    if($caError){Write-Warning $caError}
    elseif(-not $policies.Count){Write-Host 'No policies returned.'}
    else{$policies | Select-Object displayName,state,id | Format-Table -AutoSize | Out-Host}
    Write-Host 'Policy state is tenant-wide. This does not establish whether a policy applies to a specific user.'
    Wait-Key
   }
   'E' {
    $export=@(foreach($u in $users){
     $r=$registration[[string]$u.id]
     [pscustomobject]@{Id=$u.id;UPN=$u.userPrincipalName;DisplayName=$u.displayName;Enabled=$u.accountEnabled
      LicenseCount=@($u.assignedLicenses).Count;MFARegistered=if($r){$r.isMfaRegistered}else{$null}
      MFACapable=if($r){$r.isMfaCapable}else{$null}
      LastSuccessfulSignIn=$u.signInActivity.lastSuccessfulSignInDateTime

     }
    })
    Save-Evidence ([pscustomobject]@{Users=$export;ConditionalAccessPolicies=$policies;MFAReportError=$mfaError;CAPolicyError=$caError}) 'tenant-directory';Wait-Key
   }
   '0' {return}
  }
 }
}

function Signins-ForUser([string]$u) {
 Graph-Ready; Need 'Microsoft.Graph.Reports'; $since=Date-Window
 $safe=$u.Replace("'","''")
 $data=@(Get-MgAuditLogSignIn -Filter "userPrincipalName eq '$safe' and createdDateTime ge $since" -All -ErrorAction Stop)
 Browse $data 'User sign-ins' 'sign'
}

# Exchange cmdlets return rich .NET objects. Produce a bounded evidence projection
# rather than recursively serializing implementation details of those objects.
function Convert-ExchangeEvidence($inputRecord) {
 $fields=[ordered]@{}
 foreach($prop in $inputRecord.PSObject.Properties) {
  if(-not $prop.IsGettable){continue}
  try {
   $value=$prop.Value
   if($null -eq $value){$fields[$prop.Name]=$null;continue}
   if($value -is [string] -or $value -is [ValueType]){$fields[$prop.Name]=$value;continue}
   if($value -is [System.Collections.IDictionary]) {
    $mapped=[ordered]@{}
    foreach($key in $value.Keys){$mapped[[string]$key]=[string]$value[$key]}
    $fields[$prop.Name]=$mapped;continue
   }
   if($value -is [System.Collections.IEnumerable]) {
    $fields[$prop.Name]=@($value | ForEach-Object {[string]$_});continue
   }
   $fields[$prop.Name]=[string]$value
  } catch { $fields[$prop.Name]="<property unavailable: $($_.Exception.Message)>" }
 }
 return [pscustomobject]$fields
}
function Save-ExchangeEvidence($records,[string]$label) {
 $projection=@($records | ForEach-Object {Convert-ExchangeEvidence $_})
 Save-Evidence $projection $label
}
function Show-ExchangeDetail($record,[string]$title,[string]$label) {
 while($true) {
  Head $title
  Write-Menu '[1] All returned PowerShell properties'
  Write-Menu '[2] Evidence JSON (flattened Exchange properties)'
  Write-Menu '[3] Export evidence JSON'
  Write-Host ''
  Write-Menu '[0] Back'
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  switch($choice){
   '1' {Head "$title - Properties"; $record | Format-List * -Force | Out-Host; Wait-Key}
   '2' {Head "$title - Evidence JSON"; Convert-ExchangeEvidence $record | ConvertTo-Json -Depth 10 | Out-Host; Wait-Key}
   '3' {Save-ExchangeEvidence @($record) $label; Wait-Key}
   '0' {return}
  }
 }
}
function Mailbox {
 EXO-Ready
 $u=Ask-UPN
 $mb=Get-Mailbox -Identity $u -ErrorAction Stop
 while($true) {
  Head 'Mailbox configuration'
  Write-Field 'Identity' $($mb.Identity)
  Write-Field 'Primary SMTP' $($mb.PrimarySmtpAddress)
  Write-Field 'Recipient type' $($mb.RecipientTypeDetails)
  Write-Field 'Display name' $($mb.DisplayName)
  Write-Field 'Exchange GUID' $($mb.ExchangeGuid)
  Write-Field 'Hidden from GAL' $($mb.HiddenFromAddressListsEnabled)
  Write-Field 'Audit enabled' $($mb.AuditEnabled)
  Write-Field 'Forwarding address' $($mb.ForwardingAddress)
  Write-Field 'Forwarding SMTP' $($mb.ForwardingSmtpAddress)
  Write-Field 'Keep local copy' $($mb.DeliverToMailboxAndForward)
  Write-Menu "[1] All returned mailbox properties`n[2] Evidence JSON`n[3] Export evidence JSON`n[0] Back"
  switch((Read-M365MenuChoice).Trim().ToUpperInvariant()) {
   '1' {Head 'Mailbox raw properties'; $mb | Format-List * -Force | Out-Host; Wait-Key}
   '2' {Head 'Mailbox evidence JSON'; Convert-ExchangeEvidence $mb | ConvertTo-Json -Depth 10 | Out-Host; Wait-Key}
   '3' {Save-ExchangeEvidence @($mb) 'mailbox'; Wait-Key}
   '0' {return}
  }
 }
}
function Show-Rules($rules,[string]$upn) {
 while($true) {
  Head 'Inbox rules (including hidden)'
  Write-Field 'Mailbox' $upn 'Info'; Write-Field 'Rules' $rules.Count
  for($i=0;$i -lt $rules.Count;$i++) {
   $r=$rules[$i]
   Write-Host "[$($i+1)] $($r.Name) | Enabled: $($r.Enabled) | Priority: $($r.Priority)"
   if($r.ForwardTo){Write-Host "    ForwardTo: $($r.ForwardTo -join ', ')"}
   if($r.RedirectTo){Write-Host "    RedirectTo: $($r.RedirectTo -join ', ')"}
   if($r.DeleteMessage){Write-Host '    Deletes messages: True'}
  }
  Write-Menu "[A] All rules and properties`n[E] Export all rule evidence`n[0] Back"
  $c=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  if($c -eq '0'){return}
  if($c -eq 'E'){Save-ExchangeEvidence $rules 'inbox-rules';Wait-Key;continue}
  if($c -eq 'A'){foreach($r in $rules){$r | Format-List * -Force | Out-Host;Wait-Key};continue}
  $n=0
  if([int]::TryParse($c,[ref]$n) -and $n -ge 1 -and $n -le $rules.Count){Show-ExchangeDetail $rules[$n-1] 'Inbox rule' 'inbox-rule'}
 }
}
function Rules {
 EXO-Ready
 $u=Ask-UPN
 $mb=Get-Mailbox -Identity $u -ErrorAction Stop
 $rules=@(Get-InboxRule -Mailbox $u -IncludeHidden -ErrorAction Stop)
 while($true) {
  Head 'Forwarding and inbox rules'
  Write-Field 'Mailbox' $($mb.PrimarySmtpAddress)
  Write-Field 'Forwarding address' $($mb.ForwardingAddress)
  Write-Field 'Forwarding SMTP' $($mb.ForwardingSmtpAddress)
  Write-Field 'Keep local copy' $($mb.DeliverToMailboxAndForward)
  Write-Host "Inbox rules        : $($rules.Count) (including hidden)"
  Write-Menu "[1] Browse inbox rules`n[2] Full mailbox forwarding properties`n[3] Export mailbox forwarding and rules`n[0] Back"
  switch((Read-M365MenuChoice).Trim().ToUpperInvariant()) {
   '1' {Show-Rules $rules $u}
   '2' {Head 'Mailbox forwarding properties'; $mb | Format-List Identity,ForwardingAddress,ForwardingSmtpAddress,DeliverToMailboxAndForward | Out-Host;Wait-Key}
   '3' {
    $payload=[pscustomobject]@{
     Mailbox=$u
     ForwardingAddress=[string]$mb.ForwardingAddress
     ForwardingSmtpAddress=[string]$mb.ForwardingSmtpAddress
     DeliverToMailboxAndForward=$mb.DeliverToMailboxAndForward
     Rules=@($rules | ForEach-Object {Convert-ExchangeEvidence $_})
    }
    Save-Evidence $payload 'forwarding-and-rules';Wait-Key
   }
   '0' {return}
  }
 }
}
function Permissions {
 EXO-Ready
 $u=Ask-UPN
 $mb=Get-Mailbox -Identity $u -ErrorAction Stop
 $full=@(Get-MailboxPermission -Identity $u -ErrorAction Stop)
 $sendAs=@(Get-RecipientPermission -Identity $u -ErrorAction Stop)
 $onBehalf=@($mb.GrantSendOnBehalfTo)
 while($true) {
  Head 'Mailbox permissions'
  Write-Field 'Mailbox' $u 'Info'
  Write-Host "Full access entries: $($full.Count)"
  Write-Field 'Send As entries' $($sendAs.Count)
  Write-Field 'Send on Behalf' $($onBehalf.Count)
  Write-Menu "[1] Full access permissions`n[2] Send As permissions`n[3] Send on Behalf delegates`n[4] All raw returned properties`n[5] Export all permission evidence`n[0] Back"
  switch((Read-M365MenuChoice).Trim().ToUpperInvariant()) {
   '1' {Head 'Full access'; $full | Select-Object Identity,User,AccessRights,Deny,IsInherited | Format-Table -AutoSize -Wrap | Out-Host;Wait-Key}
   '2' {Head 'Send As'; $sendAs | Select-Object Identity,Trustee,AccessRights,IsInherited | Format-Table -AutoSize -Wrap | Out-Host;Wait-Key}
   '3' {Head 'Send on Behalf'; $onBehalf | Format-List * | Out-Host;Wait-Key}
   '4' {Head 'All permissions'; $full | Format-List * -Force | Out-Host; $sendAs | Format-List * -Force | Out-Host; $mb | Format-List GrantSendOnBehalfTo | Out-Host;Wait-Key}
   '5' {
    $payload=[pscustomobject]@{
     Mailbox=$u
     FullAccess=@($full | ForEach-Object {Convert-ExchangeEvidence $_})
     SendAs=@($sendAs | ForEach-Object {Convert-ExchangeEvidence $_})
     SendOnBehalf=@($onBehalf | ForEach-Object {[string]$_})
    }
    Save-Evidence $payload 'mailbox-permissions';Wait-Key
   }
   '0' {return}
  }
 }
}
# Microsoft Entra ID Protection: risk detections are service findings, not proof of compromise.
function Assert-RiskScopes {
 Graph-Ready
 $granted=@((Get-MgContext).Scopes)
 $required=@('IdentityRiskyUser.Read.All','IdentityRiskEvent.Read.All')
 $missing=@($required | Where-Object {$_ -notin $granted})
 if($missing.Count){throw "Missing Graph delegated scopes: $($missing -join ', '). Disconnect Graph and reconnect from Connections to consent to these permissions."}
}
function Get-RiskPaged([string]$uri) {
 $records=[System.Collections.Generic.List[object]]::new()
 while($uri){
  $page=Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
  foreach($item in @($page.value)){if($null -ne $item){$records.Add($item)}}
  $uri=$page.'@odata.nextLink'
 }
 return $records.ToArray()
}
function Get-RiskLocation($location) {
 if(-not $location){return 'Unknown'}
 $parts=@($location.city,$location.state,$location.countryOrRegion) | Where-Object {$_}
 if(-not $parts.Count){return 'Unknown'}
 return ($parts -join ', ')
}
function Show-RiskDetections([string]$upn='') {
 Assert-RiskScopes
 $uri='https://graph.microsoft.com/v1.0/identityProtection/riskDetections?$top=100'
 if($upn){$safe=$upn.Replace("'","''");$uri += "&`$filter=userPrincipalName eq '$safe'"}
 $events=@(Get-RiskPaged $uri)
 while($true){
  Head 'Risk detections / travel anomalies'
  Write-Field 'Target' $(if($upn){$upn}else{'Tenant-wide'}) 'Info'
  Write-Field 'Risk detections' $events.Count 'Info'
  Write-Host 'Travel-related findings are Microsoft Entra detections, not locally inferred impossibility.' -ForegroundColor Yellow
  $travel=@($events | Where-Object {($_.riskEventType -match 'travel|impossible') -or ($_.riskEventType -eq 'unlikelyTravel')})
  Write-Field 'Travel-related findings' $travel.Count 'Warning'
  Write-Menu '[1] All detections'
  Write-Menu '[2] Travel-related detections only'
  Write-Menu '[E] Export detections (JSON)'
  Write-Menu '[0] Back'
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  if($choice -eq '0'){return}
  if($choice -eq 'E'){Save-Evidence $events 'risk-detections';Wait-Key;continue}
  if($choice -notin @('1','2')){continue}
  $selected=if($choice -eq '2'){@($travel)}else{@($events)}
  if(-not $selected.Count){Write-Warning 'No matching detections were returned.';Wait-Key;continue}
  for($i=0;$i -lt $selected.Count;$i++){
   $e=$selected[$i]
   Write-Host "[$($i+1)] " -ForegroundColor Cyan -NoNewline
   Write-Host "$($e.detectedDateTime)  $($e.userPrincipalName)  $($e.riskEventType)  $($e.riskLevel)" -ForegroundColor $(if($e.riskLevel -eq 'high'){'Red'}elseif($e.riskLevel -eq 'medium'){'Yellow'}else{'White'})
  }
  $pick=(Read-Host 'Inspect number (Enter to return)').Trim()
  $n=0
  if([int]::TryParse($pick,[ref]$n) -and $n -ge 1 -and $n -le $selected.Count){
   $e=$selected[$n-1]
   Head 'Risk detection details'
   foreach($field in @('userPrincipalName','riskEventType','riskLevel','riskState','riskDetail','detectedDateTime','activityDateTime','ipAddress','source','detectionTimingType','requestId','correlationId','id')){Write-Field $field $e.$field}
   Write-Field 'Location' (Get-RiskLocation $e.location) 'Info'
   Write-Menu '[R] Raw record'
   if((Read-Host 'Select (Enter to return)').Trim().ToUpperInvariant() -eq 'R'){Raw-Record $e}
   Wait-Key
  }
 }
}
function Show-RiskyUsers {
 Assert-RiskScopes
 $users=@(Get-RiskPaged 'https://graph.microsoft.com/v1.0/identityProtection/riskyUsers?$top=100')
 while($true){
  Head 'Microsoft Entra risky users'
  Write-Field 'Returned risky users' $users.Count 'Info'
  Write-Host 'Requires Entra ID Protection licensing, permissions and available detections.' -ForegroundColor Yellow
  for($i=0;$i -lt $users.Count;$i++){
   $u=$users[$i]
   Write-Host "[$($i+1)] " -ForegroundColor Cyan -NoNewline
   Write-Host "$($u.userPrincipalName)  $($u.riskLevel)  $($u.riskState)  $($u.riskLastUpdatedDateTime)" -ForegroundColor $(if($u.riskLevel -eq 'high'){'Red'}elseif($u.riskLevel -eq 'medium'){'Yellow'}else{'White'})
  }
  Write-Menu '[E] Export risky users (JSON)'
  Write-Menu '[0] Back'
  $pick=(Read-Host 'Inspect number, E or 0').Trim().ToUpperInvariant()
  if($pick -eq '0'){return}
  if($pick -eq 'E'){Save-Evidence $users 'risky-users';Wait-Key;continue}
  $n=0
  if([int]::TryParse($pick,[ref]$n) -and $n -ge 1 -and $n -le $users.Count){
   $u=$users[$n-1]
   Head 'Risky user details'
   foreach($field in @('userPrincipalName','userDisplayName','riskLevel','riskState','riskDetail','riskLastUpdatedDateTime','isDeleted','id')){Write-Field $field $u.$field}
   Write-Menu '[1] View this user risk detections'
   Write-Menu '[R] Raw record'
   $c=(Read-M365MenuChoice).Trim().ToUpperInvariant()
   if($c -eq '1'){Show-RiskDetections $u.userPrincipalName}
   if($c -eq 'R'){Raw-Record $u;Wait-Key}
  }
 }
}
function Risk-Menu {
 while($true){
  Head 'Identity Protection / risky sign-ins'
  Write-Menu '[1] List risky users (tenant-wide)'
  Write-Menu '[2] View risk detections (tenant-wide)'
  Write-Menu '[3] Risk detections for a specific user'
  Write-Menu '[4] Travel / unusual location detections'
  Write-Menu '[0] Back'
  $c=(Read-M365MenuChoice).Trim()
  if($c -eq '0'){return}
  try{switch($c){
   '1'{Show-RiskyUsers}
   '2'{Show-RiskDetections}
   '3'{$upn=Ask-UPN;Show-RiskDetections $upn}
   '4'{Show-RiskDetections}
  }}catch{Write-Host "Risk query failed: $($_.Exception.Message)" -ForegroundColor Red;Wait-Key}
 }
}

function Signins { Graph-Ready; $u=Ask-UPN; Signins-ForUser $u }
function Fetch-Audit([string]$ip,[datetime]$start,[datetime]$end) { EXO-Ready; $all=[System.Collections.Generic.List[object]]::new(); $session=[guid]::NewGuid().ToString(); do { $batch=@(Search-UnifiedAuditLog -StartDate $start -EndDate $end -IPAddresses $ip -SessionId $session -SessionCommand ReturnLargeSet -ResultSize 5000 -ErrorAction Stop); foreach($r in $batch){$all.Add($r)}; if($all.Count -ge 50000){Write-Warning 'Audit query reached the 50,000 record session cap; results may be incomplete.';break} } while($batch.Count -gt 0); return $all.ToArray() }
function Investigate-IP([string]$ip='') { if(-not $ip){$ip=(Read-Host 'IP address').Trim()}; $parsed=$null; if(-not [System.Net.IPAddress]::TryParse($ip,[ref]$parsed)){throw 'Invalid IP address'}; $since=Date-Window; $start=[datetime]::Parse($since).ToUniversalTime(); $end=(Get-Date).ToUniversalTime(); $sign=@();$audit=@();$errors=[System.Collections.Generic.List[string]]::new(); try { Graph-Ready; Need 'Microsoft.Graph.Reports'; $sign=@(Get-MgAuditLogSignIn -Filter "ipAddress eq '$ip' and createdDateTime ge $since" -All -ErrorAction Stop) }catch{ $errors.Add("Graph sign-ins unavailable: $($_.Exception.Message)") }; try { $audit=@(Fetch-Audit $ip $start $end) }catch{ $errors.Add("Unified Audit Log unavailable: $($_.Exception.Message)") }; while($true){ Head 'Tenant-wide IP investigation'; Write-Field 'IP' $ip 'Info'; Write-Host "Sign-ins: $($sign.Count) | Audit events: $($audit.Count)"; Write-Host "Distinct sign-in users: $(@($sign | Select-Object -ExpandProperty UserPrincipalName -Unique).Count)"; foreach($e in $errors){Write-Warning $e}; Write-Menu "[1] All sign-ins`n[2] Successful sign-ins`n[3] Failed sign-ins`n[4] Accounts observed`n[5] Unified Audit Log`n[6] Exchange audit activity`n[7] SharePoint/OneDrive audit activity`n[8] Administrative audit activity`n[R] All raw evidence`n[E] Export combined JSON`n[0] Back"; $c=(Read-M365MenuChoice).Trim().ToUpperInvariant(); switch($c){ '1'{Browse $sign 'IP sign-ins' 'sign'} '2'{Browse @($sign|Where-Object {$_.Status.ErrorCode -eq 0}) 'Successful sign-ins' 'sign'} '3'{Browse @($sign|Where-Object {$_.Status.ErrorCode -ne 0}) 'Failed sign-ins' 'sign'} '4'{Head 'Accounts observed';$sign|Group-Object UserPrincipalName|Select-Object Count,Name|Format-Table -AutoSize|Out-Host;Wait-Key} '5'{Browse $audit 'Unified audit results' 'audit'} '6'{Browse @($audit|Where-Object {$_.AuditData -match '"Workload"\s*:\s*"Exchange"'}) 'Exchange audit' 'audit'} '7'{Browse @($audit|Where-Object {$_.AuditData -match '"Workload"\s*:\s*"(SharePoint|OneDrive)"'}) 'Files audit' 'audit'} '8'{Browse @($audit|Where-Object {$_.AuditData -match '"Workload"\s*:\s*"(AzureActiveDirectory|MicrosoftEntra)"'}) 'Admin audit' 'audit'} 'R'{Raw-Record ([pscustomobject]@{Ip=$ip;SignIns=$sign;Audit=$audit;Errors=$errors.ToArray()});Wait-Key} 'E'{Save-Evidence ([pscustomobject]@{Ip=$ip;From=$since;To=$end;SignIns=$sign;Audit=$audit;Errors=$errors.ToArray()}) 'ip-investigation';Wait-Key} '0'{return} } } }
function Full-UserInvestigation {
 Graph-Ready
 $upn=Ask-UPN
 $days=7
 $from=(Get-Date).ToUniversalTime().AddDays(-$days).ToString('yyyy-MM-ddTHH:mm:ssZ')
 $result=[ordered]@{TargetUPN=$upn;CollectedAtUtc=(Get-Date).ToUniversalTime().ToString('o');LookbackDays=$days;User=$null;MFARegistration=$null;Licenses=$null;SignIns=@();Mailbox=$null;InboxRules=@();FullAccess=@();SendAs=@();SendOnBehalf=@();Errors=[ordered]@{}}
 Write-Host "Collecting read-only investigation for $upn ..."
 try {
  $identity=Resolve-GraphUser $upn
  $id=$identity.Id
  $raw=Get-GraphRaw ("https://graph.microsoft.com/v1.0/users/$id"+'?$select=id,displayName,userPrincipalName,accountEnabled,createdDateTime,assignedLicenses,licenseAssignmentStates,signInActivity')
  $result.User=ConvertFrom-Json -InputObject $raw -Depth 100
 } catch { $result.Errors['Account']=$_.Exception.Message }
 if($result.User){
  try {$reg=Get-MfaRegistration $id; $result.MFARegistration=$reg.Data; if($reg.Error){$result.Errors['MFA']=$reg.Error}} catch {$result.Errors['MFA']=$_.Exception.Message}
  try {
   $inventory=Get-LicenseInventory $id
   $result.Licenses=[pscustomobject]@{Assigned=$result.User.assignedLicenses;AssignmentStates=$result.User.licenseAssignmentStates;Details=$inventory.Details;TenantSkus=@($inventory.SkuById.Values)}
   if($inventory.SkuError){$result.Errors['SKU']=$inventory.SkuError}
   if($inventory.DetailError){$result.Errors['LicenseDetails']=$inventory.DetailError}
  } catch {$result.Errors['Licenses']=$_.Exception.Message}
 }
 try {
  Need 'Microsoft.Graph.Reports'
  $safe=$upn.Replace("'","''")
  $result.SignIns=@(Get-MgAuditLogSignIn -Filter "userPrincipalName eq '$safe' and createdDateTime ge $from" -All -ErrorAction Stop)
 } catch {$result.Errors['SignIns']=$_.Exception.Message}
 try {
  EXO-Ready
  $mb=Get-Mailbox -Identity $upn -ErrorAction Stop
  $result.Mailbox=Convert-ExchangeEvidence $mb
  $result.SendOnBehalf=@($mb.GrantSendOnBehalfTo | ForEach-Object {[string]$_})
  try {$result.InboxRules=@(Get-InboxRule -Mailbox $upn -IncludeHidden -ErrorAction Stop | ForEach-Object {Convert-ExchangeEvidence $_})} catch {$result.Errors['InboxRules']=$_.Exception.Message}
  try {$result.FullAccess=@(Get-MailboxPermission -Identity $upn -ErrorAction Stop | ForEach-Object {Convert-ExchangeEvidence $_})} catch {$result.Errors['FullAccess']=$_.Exception.Message}
  try {$result.SendAs=@(Get-RecipientPermission -Identity $upn -ErrorAction Stop | ForEach-Object {Convert-ExchangeEvidence $_})} catch {$result.Errors['SendAs']=$_.Exception.Message}
 } catch {$result.Errors['Mailbox']=$_.Exception.Message}
 $failed=@($result.SignIns | Where-Object {$_.Status.ErrorCode -ne 0})
 $ips=@($result.SignIns | Where-Object {$_.IpAddress} | Select-Object -ExpandProperty IpAddress -Unique)
 $caFailed=@($result.SignIns | Where-Object {$_.ConditionalAccessStatus -eq 'failure'})
 $forwardRules=@($result.InboxRules | Where-Object {$_.ForwardTo -or $_.RedirectTo -or $_.ForwardAsAttachmentTo})
 while($true){
  Head 'Full user investigation'
  Write-Host "Target: $upn | Sign-in window: $days days | Collected: $($result.CollectedAtUtc)"
  Write-Host "`nACCOUNT" -ForegroundColor Cyan
  if($result.User){
   Write-Host "  Display name       : $($result.User.displayName)"
   Write-Host "  Account enabled    : $($result.User.accountEnabled)"
   Write-Host "  Assigned licenses  : $(@($result.User.assignedLicenses).Count)"
   Write-Host "  MFA registered     : $(if($result.MFARegistration){Value-OrUnknown $result.MFARegistration.isMfaRegistered}else{'Unavailable'})"
   Write-Host "  Last successful    : $($result.User.signInActivity.lastSuccessfulSignInDateTime)"
  }else{Write-Host '  Account details unavailable.'}
  Write-Host "`nSECURITY (OBSERVED SIGN-INS)" -ForegroundColor Cyan
  Write-Host "  Sign-ins retrieved : $($result.SignIns.Count)"
  Write-Host "  Failed sign-ins    : $($failed.Count)"
  Write-Host "  Unique source IPs  : $($ips.Count)"
  Write-Host "  CA failures        : $($caFailed.Count)"
  Write-Host "`nEXCHANGE ONLINE" -ForegroundColor Cyan
  if($result.Mailbox){
   Write-Host "  Forwarding address : $($result.Mailbox.ForwardingAddress)"
   Write-Host "  Forwarding SMTP    : $($result.Mailbox.ForwardingSmtpAddress)"
   Write-Host "  Inbox rules        : $($result.InboxRules.Count)"
   Write-Host "  Forwarding rules   : $($forwardRules.Count)"
   Write-Host "  Permission entries : $($result.FullAccess.Count + $result.SendAs.Count + $result.SendOnBehalf.Count) (includes inherited/system entries)"
  }else{Write-Host '  Mailbox data unavailable.'}
  if($result.Errors.Count){
   Write-Host "`nINCOMPLETE DATA: $($result.Errors.Keys -join ', ')" -ForegroundColor Yellow
   Write-Menu '[8] Show collection errors'
  }
  Write-Menu "[1] Account, licenses and MFA`n[2] Sign-in investigation`n[3] Source IPs (tenant-wide pivot)`n[4] Mailbox configuration`n[5] Forwarding and inbox rules`n[6] Mailbox permissions`n[7] Export collected investigation`n[9] Refresh investigation`n[0] Back"
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  switch($choice){
   '1' {User-Overview}
   '2' {Browse $result.SignIns 'Collected user sign-ins' 'sign'}
   '3' {
    Head 'Observed source IPs'
    for($i=0;$i -lt $ips.Count;$i++){Write-Host "[$($i+1)] $($ips[$i])"}
    $n=0;$pick=(Read-Host 'IP number (0 = Back)').Trim()
    if([int]::TryParse($pick,[ref]$n) -and $n -gt 0 -and $n -le $ips.Count){Investigate-IP $ips[$n-1]}
   }
   '4' {if($result.Mailbox){Show-ExchangeDetail $result.Mailbox 'Collected mailbox evidence' 'investigation-mailbox'}else{Write-Warning 'Mailbox unavailable';Wait-Key}}
   '5' {
    Head 'Collected forwarding and inbox rules'
    Write-Host "Forwarding address: $($result.Mailbox.ForwardingAddress)"
    Write-Host "Forwarding SMTP: $($result.Mailbox.ForwardingSmtpAddress)"
    for($i=0;$i -lt $result.InboxRules.Count;$i++){Write-Host "[$($i+1)] $($result.InboxRules[$i].Name)"}
    $n=0;$pick=(Read-Host 'Rule number (0 = Back)').Trim()
    if([int]::TryParse($pick,[ref]$n) -and $n -gt 0 -and $n -le $result.InboxRules.Count){Show-ExchangeDetail $result.InboxRules[$n-1] 'Collected inbox rule' 'investigation-rule'}
   }
   '6' {Head 'Collected mailbox permissions';$result.FullAccess|Format-List *|Out-Host;$result.SendAs|Format-List *|Out-Host;Write-Host "Send on behalf: $($result.SendOnBehalf -join ', ')";Wait-Key}
   '7' {Save-Evidence ([pscustomobject]$result) 'full-user-investigation';Wait-Key}
   '8' {Head 'Collection errors';$result.Errors.GetEnumerator()|Format-Table -AutoSize -Wrap|Out-Host;Wait-Key}
   '9' {return Full-UserInvestigation}
   '0' {return}
  }
 }
}

function Connection-Menu {
 while($true) {
  Head 'Connections'
  $ctx=$null
  $exo=@()
  try { $ctx=Graph-Context } catch { Write-Warning "Graph status unavailable: $($_.Exception.Message)" }
  try { $exo=@(EXO-Connections) } catch { Write-Warning "Exchange status unavailable: $($_.Exception.Message)" }
  Write-Section 'Connection status'
  Write-Field 'Graph' $(if($ctx){$ctx.Account}else{'Disconnected'}) $(if($ctx){'Good'}else{'Warning'})
  Write-Field 'Exchange' $(if($exo.Count){'Connected'}else{'Disconnected'}) $(if($exo.Count){'Good'}else{'Warning'})
  Write-Field 'Active target UPN' $(if($script:DefaultUPN){$script:DefaultUPN}else{'Not set'}) 'Info'
  Write-Field 'Saved targets' "$($script:SavedTargets.Count) (session only)"
  Write-Section 'Authentication'
  Write-Menu '[1] Connect Graph (browser or device code)'
  Write-Menu '[2] Connect Exchange Online (browser or device code)'
  Write-Menu '[3] Disconnect Graph'
  Write-Menu '[4] Disconnect Exchange Online'
  Write-Section 'Utilities'
  Write-Menu '[5] Check installed modules'
  Write-Menu '[6] Set/change default target UPN'
  Write-Menu '[7] Clear active target (retain saved targets)'
  Write-Menu '[8] Switch saved investigation target'
  Write-Menu '[9] Remove saved investigation target'
  Write-Menu '[0] Back'
  $choice=(Read-M365MenuChoice).Trim()
  try {
   switch($choice) {
    '1' { if($ctx){Write-Host 'Graph is already connected. Disconnect first to switch accounts.'; Wait-Key}else{Graph-Ready} }
    '2' { if($exo.Count){Write-Host 'Exchange is already connected. Disconnect first to switch accounts.'; Wait-Key}else{EXO-Ready} }
    '3' { if($ctx){Disconnect-MgGraph | Out-Null} }
    '4' { if($exo.Count){Disconnect-ExchangeOnline -Confirm:$false} }
    '5' {
     @('Microsoft.Graph.Authentication','Microsoft.Graph.Users','Microsoft.Graph.Reports','ExchangeOnlineManagement') |
      ForEach-Object {
       $m=Get-Module -ListAvailable -Name $_ | Sort-Object Version -Descending | Select-Object -First 1
       [pscustomobject]@{Module=$_;Installed=[bool]$m;Version=if($m){$m.Version}else{'-'}}
      } | Format-Table -AutoSize | Out-Host
     Wait-Key
    }
    '6' { Set-DefaultUPN }
    '7' { $script:DefaultUPN=$null; Write-Host 'Active target cleared.' }
    '8' { Choose-Target }
    '9' { Remove-Target }
    '0' {return}
   }
  } catch { Write-Host "Connection action failed: $($_.Exception.Message)" -ForegroundColor Red; Wait-Key }
 }
}

function Show-ConnectionSummary {
 $g='Disconnected'; $e='Disconnected'
 try { $ctx=Graph-Context; if($ctx){$g="Connected ($($ctx.Account))"} } catch {$g='Status unavailable'}
 try { $connections=@(EXO-Connections); if($connections.Count -gt 0){$e="Connected ($($connections[0].UserPrincipalName))"} } catch {$e='Status unavailable'}
 Write-Field 'Microsoft Graph' $g $(if($g -like 'Connected*'){'Good'}else{'Warning'})
 Write-Field 'Exchange Online' $e $(if($e -like 'Connected*'){'Good'}else{'Warning'})
 Write-Field 'Target user' $(if($script:DefaultUPN){$script:DefaultUPN}else{'Not set'}) 'Info'
 Write-Host ''
}


# Mail flow and quarantine investigations. Tenant operations are read-only.
function Ask-MailWindow {
 $daysText=(Read-Host 'Lookback days (1-90, default 7)').Trim()
 if(-not $daysText){$daysText='7'}
 $days=0
 if(-not [int]::TryParse($daysText,[ref]$days) -or $days -lt 1 -or $days -gt 90){throw 'Choose 1-90 days.'}
 return [pscustomobject]@{Start=(Get-Date).ToUniversalTime().AddDays(-$days);End=(Get-Date).ToUniversalTime();Days=$days}
}
function Ask-MailFilter {
 $sender=(Read-Host 'Sender (blank = any)').Trim()
 $recipient=(Read-Host 'Recipient (blank = any)').Trim()
 $subject=(Read-Host 'Subject contains (blank = any; client-side filter)').Trim()
 return [pscustomobject]@{Sender=$sender;Recipient=$recipient;Subject=$subject}
}
function Get-TraceResults($window,$filter) {
 EXO-Ready
 if(-not (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue)){throw 'Get-MessageTraceV2 is unavailable. Update ExchangeOnlineManagement and reconnect.'}
 $results=[System.Collections.Generic.List[object]]::new()
 $cursor=$window.Start
 while($cursor -lt $window.End){
  $end=$cursor.AddDays(10)
  if($end -gt $window.End){$end=$window.End}
  $params=@{StartDate=$cursor;EndDate=$end;ResultSize=5000;ErrorAction='Stop'}
  if($filter.Sender){$params.SenderAddress=$filter.Sender}
  if($filter.Recipient){$params.RecipientAddress=$filter.Recipient}
  $batch=@(Get-MessageTraceV2 @params)
  foreach($item in $batch){
   if(-not $filter.Subject -or [string]$item.Subject -like "*$($filter.Subject)*"){$results.Add($item)}
  }
  if($batch.Count -ge 5000){Write-Warning "Trace interval $cursor - $end returned 5000 results; additional pagination is required for exhaustive results."}
  $cursor=$end
 }
 return $results.ToArray()
}
function Show-MailTrace($filter=$null) {
 if(-not $filter){$filter=Ask-MailFilter}
 $window=Ask-MailWindow
 $records=@(Get-TraceResults $window $filter)
 while($true){
  Head 'Message trace'
  Write-Field 'Period' "$($window.Start.ToString('u')) to $($window.End.ToString('u'))" 'Info'
  Write-Field 'Results' $records.Count 'Info'
  $rows=@(for($i=0;$i -lt $records.Count;$i++){ $r=$records[$i]; [pscustomobject]@{No=$i+1;Received=$r.Received;SenderAddress=$r.SenderAddress;RecipientAddress=$r.RecipientAddress;Status=$r.Status;Subject=$r.Subject} })
  if($rows.Count){$rows|Select-Object -First 60|Format-Table -AutoSize -Wrap|Out-Host}
  if($records.Count -gt 60){Write-Warning 'Showing first 60; export includes all retrieved records.'}
  Write-Menu "[D] Delivery events for selected message`n[R] Raw message details`n[E] Export JSON`n[C] Export CSV`n[0] Back"
  $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  switch($choice){
   'D' {
    $n=0;$pick=(Read-Host 'Message number').Trim()
    if([int]::TryParse($pick,[ref]$n) -and $n -ge 1 -and $n -le $records.Count){
     $item=$records[$n-1]
     Get-MessageTraceDetailV2 -MessageTraceId $item.MessageTraceId -RecipientAddress $item.RecipientAddress -ErrorAction Stop | Format-List * | Out-Host
     Wait-Key
    }
   }
   'R' {$n=0;$pick=(Read-Host 'Message number').Trim();if([int]::TryParse($pick,[ref]$n) -and $n -ge 1 -and $n -le $records.Count){$records[$n-1]|Format-List *|Out-Host;Wait-Key}}
   'E' {Save-Evidence $records 'message-trace';Wait-Key}
   'C' {Save-MailCsv $records 'message-trace';Wait-Key}
   '0' {return}
  }
 }
}
function Save-MailCsv($items,[string]$label){
 New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
 $path=Join-Path $script:OutDir "$label-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
 @($items) | Export-Csv -Path $path -NoTypeInformation -Encoding utf8
 Write-Field 'Saved' $path 'Good'
}
function Show-MailConfiguration {
 EXO-Ready
 while($true){
  Head 'Mail flow configuration'
  Write-Menu "[1] Transport rules`n[2] Inbound connectors`n[3] Outbound connectors`n[4] Accepted domains`n[5] Remote domains`n[6] Transport configuration`n[7] Outbound spam policies (forwarding)`n[0] Back"
  $c=(Read-M365MenuChoice).Trim()
  if($c -eq '0'){return}
  $items=switch($c){
   '1' {@(Get-TransportRule -ErrorAction Stop)}
   '2' {@(Get-InboundConnector -ErrorAction Stop)}
   '3' {@(Get-OutboundConnector -ErrorAction Stop)}
   '4' {@(Get-AcceptedDomain -ErrorAction Stop)}
   '5' {@(Get-RemoteDomain -ErrorAction Stop)}
   '6' {@(Get-TransportConfig -ErrorAction Stop)}
   '7' {@(Get-HostedOutboundSpamFilterPolicy -ErrorAction Stop)}
   default { @() }
  }
  if($c -in @('1','2','3','4','5','6','7')){
   $items | Format-List * | Out-Host
   if((Read-Host 'Export JSON? (y/N)').Trim() -match '^(y|yes)$'){Save-Evidence $items 'mail-configuration'}
   Wait-Key
  }
 }
}
function Get-QuarantineResults($window,$filter){
 EXO-Ready
 if(-not (Get-Command Get-QuarantineMessage -ErrorAction SilentlyContinue)){throw 'Quarantine cmdlets unavailable for this account/session.'}
 $items=[System.Collections.Generic.List[object]]::new()
 for($page=1;$page -le 20;$page++){
  $params=@{StartReceivedDate=$window.Start;EndReceivedDate=$window.End;Page=$page;PageSize=1000;ErrorAction='Stop'}
  if($filter.Sender){$params.SenderAddress=$filter.Sender}
  if($filter.Recipient){$params.RecipientAddress=$filter.Recipient}
  $batch=@(Get-QuarantineMessage @params)
  foreach($r in $batch){if(-not $filter.Subject -or [string]$r.Subject -like "*$($filter.Subject)*"){$items.Add($r)}}
  if($batch.Count -lt 1000){break}
  if($page -eq 20){Write-Warning 'Quarantine result limit reached (20,000 raw records). Narrow filters to retrieve more.'}
 }
 return $items.ToArray()
}
function Export-QuarantineEml($message){
 if(-not (Get-Command Export-QuarantineMessage -ErrorAction SilentlyContinue)){throw 'Export-QuarantineMessage is unavailable or not permitted.'}
 $answer=(Read-Host 'Export potentially malicious email to local disk? Type EXPORT').Trim()
 if($answer -cne 'EXPORT'){Write-Warning 'Cancelled.';return}
 $result=Export-QuarantineMessage -Identity $message.Identity -ErrorAction Stop
 $payload=$result.Eml
 if($payload -is [array]){$payload=$payload -join ''}
 if(-not $payload){throw 'Export returned no Eml payload; inspect cmdlet output and supported export format.'}
 $bytes=[Convert]::FromBase64String([string]$payload)
 New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
 $folder=Join-Path $script:OutDir 'quarantine'
 New-Item -ItemType Directory -Force -Path $folder | Out-Null
 $safe=([string]$message.Identity -replace '[^a-zA-Z0-9_-]','_')
 if($safe.Length -gt 70){$safe=$safe.Substring(0,70)}
 $path=Join-Path $folder "quarantine-$safe-$(Get-Date -Format yyyyMMdd-HHmmssfff).eml"
 [System.IO.File]::WriteAllBytes($path,$bytes)
 Write-Field 'Exported' $path 'Good'
}
function Show-Quarantine($filter=$null){
 if(-not $filter){$filter=Ask-MailFilter}
 $window=Ask-MailWindow
 $records=@(Get-QuarantineResults $window $filter)
 while($true){
  Head 'Security / Quarantine'
  Write-Field 'Results' $records.Count 'Info'
  for($i=0;$i -lt [math]::Min($records.Count,60);$i++){
   $r=$records[$i]
   Write-Host ('[{0}] {1} | {2} -> {3} | {4} | {5}' -f ($i+1),$r.ReceivedTime,$r.SenderAddress,($r.RecipientAddress -join ','),$r.Type,$r.Subject) -ForegroundColor $(if($r.Type -match 'malware|phish'){'Red'}else{'White'})
  }
  if($records.Count -gt 60){Write-Warning 'Showing first 60. Narrow the search to select later records.'}
  Write-Menu "[D] View message details`n[P] Preview (metadata/preview cmdlet)`n[X] Export selected EML`n[B] Batch export first 60 EML files (confirmation per message)`n[E] Export metadata JSON`n[C] Export metadata CSV`n[0] Back"
  $c=(Read-M365MenuChoice).Trim().ToUpperInvariant()
  if($c -eq '0'){return}
  if($c -eq 'E'){Save-Evidence $records 'quarantine';Wait-Key;continue}
  if($c -eq 'C'){Save-MailCsv $records 'quarantine';Wait-Key;continue}
  if($c -eq 'B'){
   foreach($r in ($records | Select-Object -First 60)){try{Export-QuarantineEml $r}catch{Write-Warning $_.Exception.Message}}
   Wait-Key;continue
  }
  if($c -notin @('D','P','X')){continue}
  $n=0;$pick=(Read-Host 'Message number').Trim()
  if(-not [int]::TryParse($pick,[ref]$n) -or $n -lt 1 -or $n -gt [math]::Min($records.Count,60)){continue}
  $item=$records[$n-1]
  switch($c){
   'D' {$item|Format-List *|Out-Host}
   'P' {if(Get-Command Preview-QuarantineMessage -ErrorAction SilentlyContinue){Preview-QuarantineMessage -Identity $item.Identity -ErrorAction Stop | Format-List * | Out-Host}else{Write-Warning 'Preview cmdlet unavailable.'}}
   'X' {Export-QuarantineEml $item}
  }
  Wait-Key
 }
}
function Show-SecurityPolicies {
 EXO-Ready
 while($true){
  Head 'Security policies'
  Write-Menu "[1] Anti-spam policies`n[2] Anti-phishing policies`n[3] Anti-malware policies`n[4] Quarantine policies`n[0] Back"
  $c=(Read-M365MenuChoice).Trim()
  if($c -eq '0'){return}
  $items=switch($c){
   '1' {@(Get-HostedContentFilterPolicy -ErrorAction Stop)}
   '2' {@(Get-AntiPhishPolicy -ErrorAction Stop)}
   '3' {@(Get-MalwareFilterPolicy -ErrorAction Stop)}
   '4' {@(Get-QuarantinePolicy -ErrorAction Stop)}
   default {@()}
  }
  if($c -in @('1','2','3','4')){$items|Format-List *|Out-Host;Wait-Key}
 }
}
function Investigate-Email {
 $filter=Ask-MailFilter
 $window=Ask-MailWindow
 $traces=@();$quarantine=@();$errors=[System.Collections.Generic.List[string]]::new()
 try{$traces=@(Get-TraceResults $window $filter)}catch{$errors.Add("Message trace: $($_.Exception.Message)")}
 try{$quarantine=@(Get-QuarantineResults $window $filter)}catch{$errors.Add("Quarantine: $($_.Exception.Message)")}
 while($true){
  Head 'Unified email investigation'
  Write-Field 'Sender' $filter.Sender 'Info'
  Write-Field 'Recipient' $filter.Recipient 'Info'
  Write-Field 'Subject filter' $filter.Subject 'Info'
  Write-Field 'Trace results' $traces.Count 'Good'
  Write-Field 'Quarantine results' $quarantine.Count 'Warning'
  foreach($err in $errors){Write-Warning $err}
  Write-Menu "[1] Trace results`n[2] Quarantine results`n[3] Export combined JSON`n[0] Back"
  $c=(Read-M365MenuChoice).Trim()
  switch($c){
   '1' {$traces|Select-Object Received,SenderAddress,RecipientAddress,Status,Subject|Format-Table -AutoSize -Wrap|Out-Host;Wait-Key}
   '2' {$quarantine|Select-Object ReceivedTime,SenderAddress,RecipientAddress,Type,Subject|Format-Table -AutoSize -Wrap|Out-Host;Wait-Key}
   '3' {Save-Evidence ([pscustomobject]@{Start=$window.Start;End=$window.End;Filter=$filter;Trace=$traces;Quarantine=$quarantine;Errors=$errors.ToArray()}) 'email-investigation';Wait-Key}
   '0' {return}
  }
 }
}
function Mail-FlowMenu {
 while($true){
  Head 'Mail flow'
  Write-Menu "[1] Search message trace`n[2] Transport rules, connectors and domains`n[3] Unified email investigation`n[0] Back"
  $c=(Read-M365MenuChoice).Trim()
  try{switch($c){'1'{Show-MailTrace} '2'{Show-MailConfiguration} '3'{Investigate-Email} '0'{return}}}catch{Write-Host "Mail flow error: $($_.Exception.Message)" -ForegroundColor Red;Wait-Key}
 }
}
function Security-Menu {
 while($true){
  Head 'Security / Quarantine'
  Write-Menu "[1] Quarantine search, details and EML export`n[2] Security policies`n[3] Unified email investigation`n[0] Back"
  $c=(Read-M365MenuChoice).Trim()
  try{switch($c){'1'{Show-Quarantine} '2'{Show-SecurityPolicies} '3'{Investigate-Email} '0'{return}}}catch{Write-Host "Security error: $($_.Exception.Message)" -ForegroundColor Red;Wait-Key}
 }
}

while($true){Head 'Main menu'; Show-ConnectionSummary; Write-Menu "[1] List all tenant users`n[2] User overview`n[3] Full user investigation`n[4] Mailbox configuration`n[5] Forwarding and inbox rules`n[6] Sign-in activity`n[7] Mailbox permissions`n[8] Conditional Access policies`n`n[M] Mail flow`n[Q] Security and quarantine`n[I] Tenant-wide IP investigation`n[R] Risky users / unusual travel`n[C] Connection management`n`n[0] Exit"; $choice=(Read-M365MenuChoice).Trim().ToUpperInvariant(); if($choice -eq '0'){break}; try { switch($choice){ '1'{Tenant-Users} '2'{User-Overview} '3'{Full-UserInvestigation} '4'{Mailbox} '5'{Rules} '6'{Signins} '7'{Permissions} '8'{ConditionalAccess-Policies} 'I'{Investigate-IP} 'R'{Risk-Menu} 'M'{Mail-FlowMenu} 'Q'{Security-Menu} 'C'{Connection-Menu} default{Write-Host 'Unknown option';Wait-Key} } }catch{Write-Host "Operation failed: $($_.Exception.Message)" -ForegroundColor Red;Wait-Key} }
