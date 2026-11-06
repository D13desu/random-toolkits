$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
$script:Admin=$true
function Get-NetworkAvailability {param($Entry) [pscustomobject]@{Available=$script:Admin;Reason='Requires administrator'}}
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
$script:Calls=New-Object 'Collections.Generic.List[string]'
$script:Dependents=@()
function Get-Service {param($Name,$ErrorAction) [pscustomobject]@{Name=$Name;DisplayName='Fixture';Status='Running';CanStop=$true;DependentServices=$script:Dependents;ServicesDependedOn=@()}}
function Start-Service {param($InputObject,$ErrorAction) $script:Calls.Add('Start')}
function Stop-Service {param($InputObject,$ErrorAction) $script:Calls.Add('Stop')}
function Restart-Service {param($InputObject,$ErrorAction) $script:Calls.Add('Restart')}
$script:Answers.Enqueue('n');Invoke-PcServiceAction Fixture Stop
Assert ($script:Calls.Count -eq 0) 'Declined service action does not mutate'
foreach($action in @('Start','Stop','Restart')){$script:Answers.Enqueue('y');Invoke-PcServiceAction Fixture $action}
Assert (($script:Calls -join ',') -eq 'Start,Stop,Restart') 'Confirmed actions target the selected service'
$script:Dependents=@([pscustomobject]@{Name='Dependent';Status='Running'})
$blocked=$false;try{Invoke-PcServiceAction Fixture Restart}catch{$blocked=$true}
Assert ($blocked -and $script:Calls.Count -eq 3) 'Active dependents block restart before confirmation'
$script:Admin=$false;$blocked=$false;try{Invoke-PcServiceAction Fixture Start}catch{$blocked=$true}
Assert $blocked 'Service mutation requires elevation'
$blocked=$false;try{Invoke-PcWindowsRepair CheckHealth}catch{$blocked=$true}
Assert $blocked 'Repair checks require elevation too'
$script:Admin=$true
function Invoke-PcRepairNative {param($Command) $script:Calls.Add($Command.Action);return 0}
$script:Answers.Enqueue('n');Invoke-PcWindowsRepair RestoreHealth
Assert ($script:Calls.Count -eq 3) 'Declined Windows repair does not launch'
$script:Answers.Enqueue('y');Invoke-PcWindowsRepair RepairFiles
Assert ($script:Calls[-1] -eq 'RepairFiles') 'Confirmed repair launches selected fixed command'
Invoke-PcWindowsRepair VerifyFiles
Assert ($script:Calls[-1] -eq 'VerifyFiles') 'Verification launches without repair confirmation'
Assert (((Get-PcRepairCommand VerifyFiles).Arguments -join ' ') -eq '/verifyonly') 'Verification cannot repair files'
Assert (((Get-PcRepairCommand RestoreHealth).Arguments -join ' ') -eq '/Online /Cleanup-Image /RestoreHealth /NoRestart') 'DISM repair uses fixed arguments and suppresses restart'
function Get-PcServiceInventory {[pscustomobject]@{Name='Fixture';DisplayName='Fixture';PathName='C:\fixture.exe';State='Running';StartMode='Auto'}}
$serviceColorItem=New-PcServiceMenuItem (Get-PcServiceInventory)
Assert (($serviceColorItem.LabelParts | Where-Object Text -EQ Running).Color -eq 'Green') 'Running service uses healthy colour'
Assert (($serviceColorItem.DetailParts | Select-Object -First 1).Color -eq 'Gray') 'Service binary path uses metadata colour'
function Test-PcMenuKeyboard {$false}
function Show-PcServiceDetails {param($Row) Assert ($Row.Name -eq 'Fixture') 'Selection opens correct service'}
foreach($answer in @('F','fixture','Down','Select','R','B')){$script:Answers.Enqueue($answer)}
Start-PcServices
$script:Answers.Enqueue('B');Start-PcWindowsRepair
Assert ($script:Answers.Count -eq 0) 'Services navigation/filter/refresh and repair Back return cleanly'
$source=Get-Content (Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN SYSTEM MAINTENANCE',2)[1] -split '# END SYSTEM MAINTENANCE',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/net/System-Maintenance.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded maintenance module matches source'
