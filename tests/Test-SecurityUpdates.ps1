$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($Condition,[string]$Message){if(-not $Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}

function Get-MpComputerStatus {
    [pscustomobject]@{AntivirusEnabled=$true;AntispywareEnabled=$true;AMServiceEnabled=$true;RealTimeProtectionEnabled=$true;BehaviorMonitorEnabled=$true;IoavProtectionEnabled=$true;NISEnabled=$true;IsTamperProtected=$true;AMEngineVersion='1.2.3';AMProductVersion='4.5.6';AntivirusSignatureVersion='7.8.9';AntivirusSignatureLastUpdated=[datetime]'2026-01-01';QuickScanAge=1;QuickScanEndTime=[datetime]'2026-01-02';FullScanAge=4;FullScanEndTime=[datetime]'2025-12-30'}
}
$result=Get-PcDefenderStatus
Assert ($result.Status -eq 'PASS' -and $result.RealTimeProtectionEnabled -and $result.TamperProtected) 'Defender status reports core protection and signature state'

function Get-MpThreatDetection { @() }
Assert ((Get-PcDefenderDetections).Status -eq 'PASS') 'Empty Defender detection history is reported cleanly'
function Get-MpThreatDetection { [pscustomobject]@{InitialDetectionTime=[datetime]'2026-01-01';LastThreatStatusChangeTime=[datetime]'2026-01-02';ThreatID=42;ThreatStatusID=1;ActionSuccess=$true;Resources=@('file:_fixture')} }
$result=Get-PcDefenderDetections
Assert ($result.Status -eq 'WARN' -and $result.ThreatId -eq 42) 'Defender detection history preserves prior findings without claiming they remain active'

function Get-CimInstance {
    param($Namespace,$ClassName,$ErrorAction)
    if($ClassName -eq 'AntiVirusProduct'){return [pscustomobject]@{displayName='Fixture AV';productState=397568;pathToSignedProductExe='C:\Fixture\av.exe';pathToSignedReportingExe='C:\Fixture\report.exe';timestamp='fixture'}}
    [pscustomobject]@{VirtualizationBasedSecurityStatus=2;SecurityServicesConfigured=@(1,2);SecurityServicesRunning=@(1,2);CodeIntegrityPolicyEnforcementStatus=2;UserModeCodeIntegrityPolicyEnforcementStatus=2}
}
Assert ((Get-PcAntivirusProviders).Name -eq 'Fixture AV') 'Security Center antivirus registration is reported without decoding vendor-specific state'
Assert ((Get-PcDeviceGuardStatus).Status -eq 'PASS') 'Running virtualization-based security is detected'

function Get-Tpm {[pscustomobject]@{TpmPresent=$true;TpmReady=$true;TpmEnabled=$true;TpmActivated=$true;TpmOwned=$true;ManufacturerVersion='fixture'}}
function Confirm-SecureBootUEFI {$true}
$results=@(Get-PcPlatformSecurity)
Assert ($results.Count -eq 2 -and @($results|Where-Object Status -eq 'PASS').Count -eq 2) 'TPM and Secure Boot are checked independently'
function Get-BitLockerVolume {[pscustomobject]@{MountPoint='C:';VolumeType='OperatingSystem';VolumeStatus='FullyEncrypted';ProtectionStatus='On';EncryptionMethod='XtsAes256';EncryptionPercentage=100;LockStatus='Unlocked';AutoUnlockEnabled=$false;KeyProtector=@('SECRET-MUST-NOT-LEAK')}}
$result=Get-PcBitLockerStatus
Assert ($result.Status -eq 'PASS' -and -not ($result.PSObject.Properties.Name -contains 'KeyProtector')) 'BitLocker status omits recovery and key-protector material'

$script:NativeCalls=New-Object 'Collections.Generic.List[string]'
function auditpol.exe {$script:NativeCalls.Add($args -join ' ');$script:LASTEXITCODE=0;'Audit fixture'}
$null=Get-PcAuditPolicy
Assert (($script:NativeCalls -join '|') -eq '/get /category:*') 'Audit policy uses the read-only auditpol query'

function Get-Service { param($Name,$ErrorAction) foreach($serviceName in $Name){[pscustomobject]@{Name=$serviceName;DisplayName=$serviceName;Status='Running';StartType='Manual'}} }
$services=@(Get-PcWindowsUpdateServices)
Assert ($services.Count -eq 5 -and @($services|Where-Object Status -eq 'PASS').Count -eq 5) 'Windows Update service inventory handles trigger-start services'

function Get-ItemProperty {
    param($LiteralPath,$Name,$ErrorAction)
    if($LiteralPath -like '*WindowsUpdate*'){return [pscustomobject]@{WUServer='https://wsus.example.test';UseWUServer=1}}
    [pscustomobject]@{PendingFileRenameOperations=@('fixture')}
}
$policy=@(Get-PcWindowsUpdatePolicy)
Assert (@($policy|Where-Object Name -eq 'WUServer').Count -eq 2) 'Configured update policy is read without changing registry state'

$historyEntries=@(
    [pscustomobject]@{Date=[datetime]'2026-01-02';Title='Successful update';Operation=1;ResultCode=2;HResult=0;SupportUrl='https://example.test/1'},
    [pscustomobject]@{Date=[datetime]'2026-01-01';Title='Failed update';Operation=1;ResultCode=4;HResult=-2145124329;SupportUrl='https://example.test/2'}
)
$history=[pscustomobject]@{Count=$historyEntries.Count;Entries=$historyEntries};$history|Add-Member ScriptMethod Item {param($index)$this.Entries[$index]}
$updatesList=@([pscustomobject]@{Title='Available security update';KBArticleIDs=@('5000001');MsrcSeverity='Critical';Type='Software';IsDownloaded=$false;IsMandatory=$true;RebootRequired=$true})
$updates=[pscustomobject]@{Count=$updatesList.Count;Entries=$updatesList};$updates|Add-Member ScriptMethod Item {param($index)$this.Entries[$index]}
$script:SearchCriteria=$null
$searcher=[pscustomobject]@{History=$history;SearchUpdates=$updates};$searcher|Add-Member ScriptMethod GetTotalHistoryCount {$this.History.Count};$searcher|Add-Member ScriptMethod QueryHistory {param($start,$count)$this.History};$searcher|Add-Member ScriptMethod Search {param($criteria)$script:SearchCriteria=$criteria;[pscustomobject]@{Updates=$this.SearchUpdates}}
$script:UpdateSession=[pscustomobject]@{Searcher=$searcher};$script:UpdateSession|Add-Member ScriptMethod CreateUpdateSearcher {$this.Searcher}
function New-PcWindowsUpdateSession {$script:UpdateSession}
$historyRows=@(Get-PcWindowsUpdateHistory)
Assert ($historyRows.Count -eq 2 -and $historyRows[1].HResult -match '^0x[0-9A-F]{8}$' -and $historyRows[1].Status -eq 'WARN') 'Update history maps result codes and normalizes signed HRESULT values'
$available=@(Find-PcAvailableUpdates)
Assert ($script:SearchCriteria -eq 'IsInstalled=0 and IsHidden=0' -and $available.Count -eq 1 -and -not $available[0].Downloaded) 'Available-update search uses discovery-only criteria and returns metadata'

function Test-Path {param($LiteralPath) $LiteralPath -like '*RebootRequired'}
$reboot=@(Get-PcUpdateRebootStatus)
Assert ($reboot.Count -eq 3 -and @($reboot|Where-Object Status -eq 'WARN').Count -eq 2) 'Servicing and pending-file reboot indicators remain independent'

$securityIds=@((Get-PcSecurityChecks).Id);$updateIds=@((Get-PcUpdateChecks).Id)
Assert (@('security-defender','security-detections','security-providers','security-platform','security-vbs','security-bitlocker','security-audit','security-firewall','security-events','security-defender-events'|Where-Object{$_ -notin $securityIds}).Count -eq 0) 'All Security checks are registered'
Assert (@('update-services','update-policy','update-history','update-installed','update-reboot','update-available','update-events'|Where-Object{$_ -notin $updateIds}).Count -eq 0) 'All Windows Update checks are registered'

$script:Ran=0;$script:MenuAnswers=New-Object 'Collections.Generic.Queue[string]';$script:MenuAnswers.Enqueue('1');$script:MenuAnswers.Enqueue('B')
function Read-PcCategoryMenu {param($Title,$Items,$State,$Description) $script:MenuAnswers.Dequeue()}
function Get-NetworkAvailability {param($Entry)[pscustomobject]@{Available=$true;Reason=''}}
function Read-Host {param($Prompt)'no'}
$entry=[pscustomobject]@{Key='1';Id='slow';Name='Slow scan';MinPS='5.0';Commands=@();Admin=$false;OpenMenu=$false;ConfirmRun=$true;Action={$script:Ran++}}
Start-PcDiagnosticMenu 'Fixture' @($entry)
Assert ($script:Ran -eq 0 -and $script:MenuAnswers.Count -eq 0) 'Declining a potentially slow scan prevents its action from running'

Write-Output "Security and Update tests passed on PowerShell $($PSVersionTable.PSVersion)."
