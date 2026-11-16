$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Sysinternals-Launcher.ps1')
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message};Write-Output "PASS: $Message"}

$catalog=@(Get-PcSysinternalsLiveCatalog)
Assert ($catalog.Count -eq 10) 'Curated Sysinternals Live catalog has ten tools'
Assert (@($catalog.Id|Select-Object -Unique).Count -eq $catalog.Count) 'Tool identifiers are unique'
Assert (-not ($catalog.Id -contains 'sysmon') -and -not ($catalog.Id -contains 'sdelete')) 'Service-installing and destructive tools are not one-click launchers'

$savedArchitecture=$env:PROCESSOR_ARCHITECTURE
$savedWow=$env:PROCESSOR_ARCHITEW6432
try{
 $env:PROCESSOR_ARCHITEW6432='';$env:PROCESSOR_ARCHITECTURE='AMD64'
 $x64=Get-PcSysinternalsLivePath procexp
 Assert ($x64.Path -eq '\\live.sysinternals.com\tools\procexp64.exe') 'x64 shortcut uses the official tools share and x64 binary'
 $env:PROCESSOR_ARCHITECTURE='ARM64'
 $arm=Get-PcSysinternalsLivePath procmon
 Assert ($arm.Path -eq '\\live.sysinternals.com\tools\ARM64\Procmon64a.exe') 'ARM64 shortcut uses the official ARM64 share folder'
 $env:PROCESSOR_ARCHITECTURE='x86'
 $x86=Get-PcSysinternalsLivePath autoruns
 Assert ($x86.Path -eq '\\live.sysinternals.com\tools\Autoruns.exe') 'x86 shortcut uses the x86 executable'
} finally {$env:PROCESSOR_ARCHITECTURE=$savedArchitecture;$env:PROCESSOR_ARCHITEW6432=$savedWow}

$script:Started=$null
function Start-Process {param($FilePath,$ArgumentList,$ErrorAction);$script:Started=$FilePath;$script:Arguments=$ArgumentList}
$env:PROCESSOR_ARCHITEW6432='';$env:PROCESSOR_ARCHITECTURE='AMD64'
Start-PcSysinternalsLiveTool tcpview
Assert ($script:Started -eq '\\live.sysinternals.com\tools\tcpview64.exe') 'Tool launcher passes the Microsoft UNC path directly to Start-Process'
$script:AccessExecutable=$null;$script:AccessArguments=@();$script:AccessCalls=0
Assert ((Resolve-PcAccessChkAccount 'alice' 'GIROSYSTEM\kgarcia') -eq 'GIROSYSTEM\alice') 'Bare username inherits the summary identity domain'
Assert ((Resolve-PcAccessChkAccount '' 'GIROSYSTEM\kgarcia') -eq 'GIROSYSTEM\kgarcia') 'Blank account uses the full summary identity'
foreach($account in @('OTHER\alice','alice@example.com','Everyone','BUILTIN\Users','S-1-5-18')){
 Assert ((Resolve-PcAccessChkAccount $account 'GIROSYSTEM\kgarcia') -eq $account) 'Explicit identity or well-known principal is preserved'
}
Assert ((Resolve-PcAccessChkAccount 'alice' 'user@example.com') -eq 'alice') 'UPN summary does not invent a Windows domain'
function Invoke-PcAccessChk {param($Executable,$Arguments);$script:AccessExecutable=$Executable;$script:AccessArguments=$Arguments;$script:AccessCalls++;return 0}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
function Read-Host {param($Prompt);if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
foreach($answer in @('DOMAIN\Test User','C:\Data & Reports','3','y','')){$script:Answers.Enqueue($answer)}
Start-PcSysinternalsLiveTool accesschk
Assert ($script:AccessExecutable -eq '\\live.sysinternals.com\tools\accesschk64.exe' -and ($script:AccessArguments -join '|') -eq '-v|-w|-s|DOMAIN\Test User|C:\Data & Reports') 'AccessChk receives account, literal spaced path, write filter and recursion as separate arguments'
Assert ($script:Answers.Count -eq 0) 'AccessChk waits for Enter after displaying output'
$script:PcSystemSummary=[pscustomobject]@{Username='GIROSYSTEM\kgarcia'}
foreach($answer in @('alice','C:\Data','1','n','')){$script:Answers.Enqueue($answer)}
Start-PcSysinternalsLiveTool accesschk
Assert ('GIROSYSTEM\alice' -in $script:AccessArguments) 'Interactive account prompt uses the summary domain for a bare username'
foreach($answer in @('','C:\Data','1','n','')){$script:Answers.Enqueue($answer)}
Start-PcSysinternalsLiveTool accesschk
Assert ('GIROSYSTEM\kgarcia' -in $script:AccessArguments) 'Enter checks the current summary identity without retyping it'
$script:PcSystemSummary=$null
$readArgs=@(New-PcAccessChkArguments -Account Everyone -Path 'C:\' -Access Read)
Assert (($readArgs -join '|') -eq '-v|-r|Everyone|C:\.') 'Read filter and drive-root path are preserved safely'
$allArgs=@(New-PcAccessChkArguments -Account 'DOMAIN\user' -Path '\\server\share\Folder Name')
Assert (($allArgs -join '|') -eq '-v|DOMAIN\user|\\server\share\Folder Name') 'Default shows all permissions without read/write filters or recursion'
foreach($bad in @(@('-w','C:\Data'),@('Everyone','relative'),@('Everyone','C:\Data"'),@('Everyone','C:\*'))){
 $caught=$false;try{$null=New-PcAccessChkArguments -Account $bad[0] -Path $bad[1]}catch{$caught=$true}
 Assert $caught 'Invalid account, relative path, quotes or wildcards are rejected before execution'
}
$before=$script:AccessCalls
foreach($answer in @('B')){$script:Answers.Enqueue($answer)}
Start-PcSysinternalsLiveTool accesschk
Assert ($script:AccessCalls -eq $before -and $script:Answers.Count -eq 0) 'Back cancels without launching AccessChk'
function Invoke-PcAccessChk {param($Executable,$Arguments);throw 'Mock native failure'}
foreach($answer in @('Everyone','C:\Data','1','n','')){$script:Answers.Enqueue($answer)}
$caught=$false;try{Start-PcSysinternalsLiveTool accesschk}catch{$caught=$_.Exception.Message -eq 'Mock native failure'}
Assert ($caught -and $script:Answers.Count -eq 0) 'Launch failure still pauses before returning'
$env:PROCESSOR_ARCHITECTURE=$savedArchitecture;$env:PROCESSOR_ARCHITEW6432=$savedWow

$toolkit=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Sysinternals-Launcher.ps1') -Raw
$embedded=($toolkit -split '# BEGIN SYSINTERNALS LAUNCHER',2)[1] -split '# END SYSINTERNALS LAUNCHER',2
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded Sysinternals launcher matches maintained source'
Assert ($toolkit -match "New-PcMenuItem '13' 'Microsoft Sysinternals Live'") 'Windows main menu exposes the Sysinternals Live section'
Assert ($toolkit -match "'13'\s*\{\s*Start-PcSysinternalsMenu\s*\}") 'Windows main menu dispatches to the Sysinternals Live section'
