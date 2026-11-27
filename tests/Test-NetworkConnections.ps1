$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -NoMenu
function Assert($ok,$message){if(-not $ok){throw $message};Write-Output "PASS: $message"}
Assert ((Format-PcSocketEndpoint '::1' 443) -eq '[::1]:443') 'IPv6 endpoints are unambiguous'
Assert ((Format-PcSocketEndpoint '127.0.0.1' 80) -eq '127.0.0.1:80') 'IPv4 endpoints retain numeric ports'
$script:UdpFails=$false;$script:Queries=0
function Get-NetTCPConnection {
 [CmdletBinding()]param()
 $script:Queries++
 foreach($state in @('Listen','Established','TimeWait')){[pscustomobject]@{LocalAddress='127.0.0.1';LocalPort=443;RemoteAddress='0.0.0.0';RemotePort=0;State=$state;OwningProcess=$(if($state -eq 'TimeWait'){0}else{42});CreationTime=[datetime]'2026-01-01'}}
 [pscustomobject]@{LocalAddress='::';LocalPort=80;RemoteAddress='::';RemotePort=0;State='Listen';OwningProcess=43;CreationTime=[datetime]'2026-01-01'}
}
function Get-NetUDPEndpoint {
 [CmdletBinding()]param()
 if($script:UdpFails){throw 'Fixture UDP access failure'}
 # Duplicate bound sockets must not break shared menu identity.
 foreach($i in 1..2){[pscustomobject]@{LocalAddress='::';LocalPort=5353;OwningProcess=99;CreationTime=[datetime]'2026-01-01'}}
}
function Get-CimInstance {
 param($ClassName,$Property,$OperationTimeoutSec,$ErrorAction)
 [pscustomobject]@{ProcessId=42;Name='fixture.exe';ExecutablePath='C:\fixture.exe';CreationDate=[datetime]'2025-01-01'}
 [pscustomobject]@{ProcessId=43;Name='reused.exe';ExecutablePath='C:\reused.exe';CreationDate=[datetime]'2026-02-01'}
}
$snapshot=Get-PcNetworkConnections
Assert ($snapshot.Rows.Count -eq 6 -and $snapshot.Issues.Count -eq 0) 'TCP and UDP collected once into snapshot'
Assert (@($snapshot.Rows.Id | Select-Object -Unique).Count -eq 6) 'Duplicate socket tuples retain unique row IDs'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 42 | Select-Object -First 1).ExecutablePath -eq 'C:\fixture.exe') 'PID maps to process path'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 43).ProcessName -eq 'PID reused / exited') 'Reused PID is not attributed to a newer process'
Assert (($snapshot.Rows | Where-Object ProcessId -EQ 0).ProcessName -eq 'Unattributed') 'PID zero is not labelled as an owning process'
Assert (@($snapshot.Rows | Where-Object {$_.Protocol -eq 'UDP' -and ($_.State -ne 'Bound' -or $_.RemoteEndpoint -ne '*')}).Count -eq 0) 'UDP does not invent TCP state or remote peer'
$colored=New-PcNetworkConnectionMenuItem ($snapshot.Rows | Where-Object ProcessId -EQ 42 | Select-Object -First 1)
Assert (($colored.LabelParts | Where-Object {$_.Text -eq '443'}).Color -eq 'Yellow') 'Connection ports use the port colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq 'fixture.exe'}).Color -eq 'Cyan') 'Process binary uses the binary colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq 'C:\fixture.exe'}).Color -eq 'Gray') 'Executable path uses the path colour'
Assert (($colored.DetailParts | Where-Object {$_.Text -eq '42'}).Color -eq 'Magenta') 'PID uses the process identifier colour'
$script:UdpFails=$true;$partial=Get-PcNetworkConnections
Assert ($partial.Rows.Count -eq 4 -and $partial.Issues.Count -eq 1) 'UDP failure preserves TCP rows and reports incomplete collection'
$script:UdpFails=$false
$script:Answers=New-Object 'Collections.Generic.Queue[string]'
foreach($answer in @('L','Select','Back','E','Select','Back','T','F','5353','Select','Back','F','','A','T','R','C','Back','B')){$script:Answers.Enqueue($answer)}
function Read-Host {param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};$script:Answers.Dequeue()}
function Test-PcMenuKeyboard {$false}
$before=$script:Queries
Start-PcNetworkConnections
Assert ($script:Answers.Count -eq 0 -and $script:Queries -eq ($before+2)) 'Protocol/state filters, details, notes and refresh navigate without implicit rescans'
Assert ('connections' -in (Get-NetworkMenuItems (Get-NetworkCategories | Where-Object Id -EQ connectivity)).Entry.Id) 'Connections reachable in Connectivity menu'
$source=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN NETWORK CONNECTIONS',2)[1] -split '# END NETWORK CONNECTIONS',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Network-Connections.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded connections module matches source'

# BEGIN SMB CONNECTION TESTS
$script:SmbMode='Rows';$script:SmbQueries=0;$script:SmbMissing=$false
function Get-SmbConnection {
    [CmdletBinding()]param()
    $script:SmbQueries++
    if($script:SmbMode -eq 'Fail'){throw 'SMB access denied fixture'}
    if($script:SmbMode -eq 'Empty'){return}
    $row=[pscustomobject]@{ServerName='NAS test';ShareName='Share with spaces';UserName='DOMAIN\LocalUser';Credential='OTHER\ShareUser';Dialect='3.1.1';NumOpens=0;Encrypted=$false;ContinuouslyAvailable=$false}
    $row;$row
    if($script:SmbMode -eq 'Partial'){throw 'SMB interrupted fixture'}
    [pscustomobject]@{ServerName='NAS2';ShareName='Data';UserName='DOMAIN\User';Credential=[Management.Automation.PSCredential]::new('DOMAIN\ObjectIdentity',[Security.SecureString]::new());NumOpens=2}
}
function Get-Command {
    param($Name,$ErrorAction)
    if($Name -eq 'Get-SmbConnection'){
        if(-not $script:SmbMissing){[pscustomobject]@{Name=$Name}}
    }else{Microsoft.PowerShell.Core\Get-Command -Name $Name -ErrorAction $ErrorAction}
}
$smb=Get-PcSmbConnections
Assert ($smb.Status -eq 'OK' -and $smb.Rows.Count -eq 3 -and $script:SmbQueries -eq 1) 'SMB collection queries the cmdlet once'
Assert (@($smb.Rows.Id | Select-Object -Unique).Count -eq 3) 'Identical server/share records retain distinct menu IDs'
Assert ($smb.Rows[0].UserName -eq 'DOMAIN\LocalUser' -and $smb.Rows[0].CredentialIdentity -eq 'OTHER\ShareUser') 'Logon identity and share credential identity remain separate'
Assert ($smb.Rows[0].NumOpens -eq 0 -and $smb.Rows[0].Encrypted -ceq $false) 'Zero opens and false encryption are preserved'
Assert ($smb.Rows[2].CredentialIdentity -eq 'DOMAIN\ObjectIdentity' -and $smb.Rows[2].Dialect -eq 'Unavailable') 'Credential objects expose only the account name; missing metadata stays unavailable'
Assert (($smb.Rows[2] | ConvertTo-Json) -notmatch 'Password|SecureString') 'Snapshot contains no credential object or password property'
$item=New-PcSmbConnectionMenuItem $smb.Rows[0]
Assert ($item.Label -like '*\\NAS test\Share with spaces*' -and $item.SearchText -like '*OTHER\ShareUser*') 'Spaced share paths and alternate identities remain searchable'
$script:SmbMode='Empty';$empty=Get-PcSmbConnections
Assert ($empty.Status -eq 'OK' -and $empty.Rows.Count -eq 0 -and -not $empty.Issue) 'Successful empty SMB query is distinct from failure'
$script:SmbMode='Fail';$failed=Get-PcSmbConnections
Assert ($failed.Status -eq 'Failed' -and $failed.Rows.Count -eq 0 -and $failed.Issue -like '*access denied*') 'SMB query errors remain visible and do not reuse cached rows'
$script:SmbMode='Partial';$failed=Get-PcSmbConnections
Assert ($failed.Status -eq 'Failed' -and $failed.Rows.Count -eq 0) 'Interrupted SMB enumeration is not presented as complete'
$script:SmbMissing=$true;$before=$script:SmbQueries;$missing=Get-PcSmbConnections
Assert ($missing.Status -eq 'Unavailable' -and $script:SmbQueries -eq $before) 'Missing SMB cmdlet is reported before execution'
$script:SmbMissing=$false;$script:SmbMode='Rows'
$script:SmbSteps=New-Object 'Collections.Generic.Queue[string]'
foreach($step in @('Select','Notes','Refresh','Back')){$script:SmbSteps.Enqueue($step)}
$script:SmbDetails=New-Object 'Collections.Generic.List[object]'
function Show-PcMenu {
    param($Title,$Items,$State,[switch]$Filterable,[switch]$Refreshable,$Description,$Commands)
    Assert ($Filterable -and $Refreshable) 'SMB view enables shared search and refresh controls' | Out-Host
    switch($script:SmbSteps.Dequeue()){
        'Select'{[pscustomobject]@{Action='Select';Item=$Items[0]}}
        'Notes'{[pscustomobject]@{Action='Command';Command='C'}}
        'Refresh'{[pscustomobject]@{Action='Refresh'}}
        'Back'{[pscustomobject]@{Action='Back'}}
    }
}
function Show-PcListDetails {param($Row,$Title);$script:SmbDetails.Add($Row)}
$before=$script:SmbQueries
Start-PcSmbConnections
Assert ($script:SmbQueries -eq $before+2 -and $script:SmbSteps.Count -eq 0) 'SMB details and notes reuse the snapshot; only refresh re-queries'
Assert ($script:SmbDetails[1].Limitations -like '*not a list of filenames or locks*') 'SMB notes explain aggregate open counts and client-only scope'
# END SMB CONNECTION TESTS
Assert ('smb-connections' -in (Get-NetworkMenuItems (Get-NetworkCategories | Where-Object Id -EQ connectivity)).Entry.Id) 'SMB view is reachable from Connectivity and adapters'
