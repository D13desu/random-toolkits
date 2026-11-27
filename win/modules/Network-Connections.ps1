function Format-PcSocketEndpoint {
    param([string]$Address,[int]$Port)
    if($Address.Contains(':')){return ('[{0}]:{1}' -f $Address,$Port)}
    return ('{0}:{1}' -f $Address,$Port)
}
function Get-PcNetworkConnections {
    $issues=New-Object 'Collections.Generic.List[string]'
    $sockets=New-Object 'Collections.Generic.List[object]'
    foreach($protocol in @('TCP','UDP')){
        $command=if($protocol -eq 'TCP'){'Get-NetTCPConnection'}else{'Get-NetUDPEndpoint'}
        try{
            if(-not (Get-Command $command -ErrorAction SilentlyContinue)){throw "$command is unavailable on this Windows installation."}
            foreach($socket in @(& $command -ErrorAction Stop)){$sockets.Add([pscustomobject]@{Protocol=$protocol;Socket=$socket})}
        }catch{$issues.Add($protocol+': '+$_.Exception.Message)}
    }
    $processes=@{}
    try{
        foreach($process in @(Get-CimInstance Win32_Process -Property ProcessId,Name,ExecutablePath,CreationDate -OperationTimeoutSec 5 -ErrorAction Stop)){
            $processes[[string]$process.ProcessId]=$process
        }
    }catch{$issues.Add('Process metadata: '+$_.Exception.Message)}
    $rows=New-Object 'Collections.Generic.List[object]'
    $identities=@{}
    foreach($entry in $sockets){
        $socket=$entry.Socket;$ownerId=[long]$socket.OwningProcess
        $local=Format-PcSocketEndpoint ([string]$socket.LocalAddress) ([int]$socket.LocalPort)
        $remote=if($entry.Protocol -eq 'TCP'){Format-PcSocketEndpoint ([string]$socket.RemoteAddress) ([int]$socket.RemotePort)}else{'*'}
        $state=if($entry.Protocol -eq 'TCP'){[string]$socket.State}else{'Bound'}
        $name='Unavailable / exited';$path=$null;$ownership='Best-effort PID lookup; snapshots are not atomic.'
        if($ownerId -eq 0){$name='Unattributed';$ownership='Windows supplied PID 0; no live process is attributed.'}
        elseif($processes.ContainsKey([string]$ownerId)){
            $process=$processes[[string]$ownerId];$reused=$false
            if($socket.CreationTime -is [datetime] -and $process.CreationDate -is [datetime] -and $socket.CreationTime.Year -ge 2000){
                $reused=($process.CreationDate.ToUniversalTime() - $socket.CreationTime.ToUniversalTime()).TotalSeconds -gt 2
            }
            if($reused){$name='PID reused / exited';$ownership='Current process started after this endpoint; ownership withheld.'}
            else{$name=[string]$process.Name;$path=[string]$process.ExecutablePath}
        }
        $pathStatus=if($path){'Available'}else{'Unavailable (permissions, exited process or kernel/unattributed endpoint)'}
        $identity=$entry.Protocol+'|'+$local+'|'+$remote+'|'+$ownerId+'|'+$socket.CreationTime
        $base=$identity;$suffix=1;while($identities.ContainsKey($identity)){$suffix++;$identity=$base+'|'+$suffix};$identities[$identity]=$true
        $rows.Add([pscustomobject]@{Id=$identity;Protocol=$entry.Protocol;State=$state;LocalEndpoint=$local;RemoteEndpoint=$remote;LocalAddress=$socket.LocalAddress;LocalPort=$socket.LocalPort;RemoteAddress=$(if($entry.Protocol -eq 'TCP'){$socket.RemoteAddress}else{$null});RemotePort=$(if($entry.Protocol -eq 'TCP'){$socket.RemotePort}else{$null});ProcessId=$ownerId;ProcessName=$name;ExecutablePath=$path;PathStatus=$pathStatus;Ownership=$ownership;Created=$socket.CreationTime})
    }
    [pscustomobject]@{CollectedAt=(Get-Date);Rows=@($rows.ToArray() | Sort-Object Protocol,@{Expression={if($_.State -eq 'Listen'){0}else{1}}},LocalPort,LocalAddress,RemoteEndpoint,ProcessId);Issues=@($issues.ToArray())}
}
function New-PcNetworkConnectionMenuItem {
    param($Row)
    $path=if($Row.ExecutablePath){$Row.ExecutablePath}else{'Executable path unavailable'}
    $stateColor=switch([string]$Row.State){'Established'{'Green'}'Listen'{'Yellow'}'Bound'{'Cyan'}'TimeWait'{'DarkGray'}default{'Gray'}}
    $remoteAddress=if($Row.Protocol -eq 'UDP'){'*'}else{[string]$Row.RemoteAddress}
    $remotePort=if($null -ne $Row.RemotePort){[string]$Row.RemotePort}else{''}
    $localAddress=if(([string]$Row.LocalAddress).Contains(':')){'['+[string]$Row.LocalAddress+']'}else{[string]$Row.LocalAddress}
    if($Row.Protocol -ne 'UDP' -and $remoteAddress.Contains(':')){$remoteAddress='['+$remoteAddress+']'}
    $labelParts=@(
        [pscustomobject]@{Text=([string]$Row.Protocol);Color='Cyan'}
        [pscustomobject]@{Text=' ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.State);Color=$stateColor}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=$localAddress;Color='White'}
        [pscustomobject]@{Text=':';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.LocalPort);Color='Yellow'}
        [pscustomobject]@{Text=' -> ';Color='DarkGray'}
        [pscustomobject]@{Text=$remoteAddress;Color='Gray'}
    )
    if($remotePort){$labelParts+=@([pscustomobject]@{Text=':';Color='DarkGray'},[pscustomobject]@{Text=$remotePort;Color='Yellow'})}
    $detailParts=@(
        [pscustomobject]@{Text='PID ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.ProcessId);Color='Magenta'}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=([string]$Row.ProcessName);Color='Cyan'}
        [pscustomobject]@{Text=' | ';Color='DarkGray'}
        [pscustomobject]@{Text=$path;Color='Gray'}
    )
    [pscustomobject]@{
        Id=$Row.Id
        Label=('{0} {1} | {2} -> {3}' -f $Row.Protocol,$Row.State,$Row.LocalEndpoint,$Row.RemoteEndpoint)
        Detail=('PID {0} | {1} | {2}' -f $Row.ProcessId,$Row.ProcessName,$path)
        LabelParts=$labelParts
        DetailParts=$detailParts
        SearchText=($Row.ProcessId.ToString()+' '+$Row.ProcessName+' '+$Row.ExecutablePath)
        Data=$Row
    }
}
function Start-PcNetworkConnections {
    $snapshot=Get-PcNetworkConnections;$state=@{};$protocol='TCP';$tcpState='All'
    while($true){
        $rows=@($snapshot.Rows | Where-Object {($protocol -eq 'Both' -or $_.Protocol -eq $protocol) -and ($tcpState -eq 'All' -or ($_.Protocol -eq 'TCP' -and $_.State -eq $tcpState))})
        $menu=@(foreach($row in $rows){New-PcNetworkConnectionMenuItem $row})
        $description=('{0:HH:mm:ss} snapshot | {1} / {2} | {3} entries | Collection issues: {4} (C)' -f $snapshot.CollectedAt,$protocol,$tcpState,$rows.Count,$snapshot.Issues.Count)
        $choice=Show-PcMenu -Title 'Windows > Network > Connections' -Items $menu -State $state -Filterable -Refreshable -Description $description -Commands @{T='TCP/UDP/both';L='TCP listeners';E='Established TCP';A='All states';C='Collection notes'}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$snapshot=Get-PcNetworkConnections}
            'Select'{Show-PcListDetails ($choice.Item.Data | Select-Object Protocol,State,LocalEndpoint,RemoteEndpoint,ProcessId,ProcessName,ExecutablePath,PathStatus,Ownership,Created) 'Connection details (cached snapshot)'}
            'Command'{switch($choice.Command){
                'T'{$protocol=switch($protocol){'TCP'{'UDP'}'UDP'{'Both'}default{'TCP'}};$tcpState='All'}
                'L'{$protocol='TCP';$tcpState='Listen'}
                'E'{$protocol='TCP';$tcpState='Established'}
                'A'{$tcpState='All'}
                'C'{Show-PcListDetails ([pscustomobject]@{CollectedAt=$snapshot.CollectedAt;TCP=@($snapshot.Rows | Where-Object Protocol -EQ TCP).Count;UDP=@($snapshot.Rows | Where-Object Protocol -EQ UDP).Count;CollectionIssues=($snapshot.Issues -join "`n");Notes='Read-only numeric endpoints; no DNS queries or network probes. R collects a fresh snapshot. UDP rows are bound local sockets, not TCP-style connections; no remote peer is supplied. Process attribution is best effort because endpoints and processes are collected separately. Administrator access may reveal additional executable paths. A listener does not establish firewall reachability.'}) 'Connection collection notes'}
            }}
        }
    }
}

function Get-PcSmbConnectionField($Connection,[string]$Name) {
    $property=$Connection.PSObject.Properties[$Name]
    if($null -eq $property -or $null -eq $property.Value){return 'Unavailable'}
    return $property.Value
}
function Get-PcSmbConnections {
    $collectedAt=Get-Date
    $rows=New-Object 'Collections.Generic.List[object]'
    $status='OK';$issue=''
    if(-not (Get-Command Get-SmbConnection -ErrorAction SilentlyContinue)){
        $status='Unavailable';$issue='Get-SmbConnection (SmbShare module) is unavailable on this Windows installation.'
    }else{
        try{
            # Finish collection before constructing rows: an error must not leave a
            # partial/stale set that looks like a successful empty snapshot.
            $connections=@(Get-SmbConnection -ErrorAction Stop)
            $index=0
            foreach($connection in $connections){
                if($null -eq $connection){continue}
                $index++
                $identity='Unavailable'
                if($connection.Credential -is [string]){$identity=$connection.Credential}
                elseif($connection.Credential -is [Management.Automation.PSCredential]){$identity=$connection.Credential.UserName}
                $server=[string](Get-PcSmbConnectionField $connection 'ServerName')
                $share=[string](Get-PcSmbConnectionField $connection 'ShareName')
                $rows.Add([pscustomobject]@{
                    Id=('smb-'+$index);ServerName=$server;ShareName=$share
                    SharePath=('\\'+$server+'\'+$share)
                    UserName=(Get-PcSmbConnectionField $connection 'UserName')
                    CredentialIdentity=$identity
                    Dialect=(Get-PcSmbConnectionField $connection 'Dialect')
                    NumOpens=(Get-PcSmbConnectionField $connection 'NumOpens')
                    Encrypted=(Get-PcSmbConnectionField $connection 'Encrypted')
                    ContinuouslyAvailable=(Get-PcSmbConnectionField $connection 'ContinuouslyAvailable')
                })
            }
        }catch{
            $rows.Clear();$status='Failed';$issue=$_.Exception.Message
        }
    }
    [pscustomobject]@{CollectedAt=$collectedAt;Status=$status;Issue=$issue;Rows=$rows.ToArray()}
}
function New-PcSmbConnectionMenuItem($Row) {
    [pscustomobject]@{
        Id=$Row.Id
        Label=('{0} | SMB {1} | Opens: {2}' -f $Row.SharePath,$Row.Dialect,$Row.NumOpens)
        Detail=('User: {0} | Credential identity: {1}' -f $Row.UserName,$Row.CredentialIdentity)
        SearchText=($Row.ServerName+' '+$Row.ShareName+' '+$Row.UserName+' '+$Row.CredentialIdentity)
        Data=$Row
    }
}
function Start-PcSmbConnections {
    $snapshot=Get-PcSmbConnections;$state=@{}
    while($true){
        $menu=@(foreach($row in $snapshot.Rows){New-PcSmbConnectionMenuItem $row})
        $result=if($snapshot.Status -ne 'OK'){$snapshot.Status+': '+$snapshot.Issue}elseif(-not $snapshot.Rows.Count){'No SMB client connections returned in this logon/elevation context.'}else{'Connections: '+$snapshot.Rows.Count}
        $description=('{0:HH:mm:ss} snapshot | {1} | Local SMB client only; C: scope and collection notes' -f $snapshot.CollectedAt,$result)
        $choice=Show-PcMenu -Title 'Windows > Network > SMB client connections' -Items $menu -State $state -Filterable -Refreshable -Description $description -Commands @{C='Scope and collection notes'}
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$snapshot=Get-PcSmbConnections}
            'Select'{Show-PcListDetails ($choice.Item.Data | Select-Object ServerName,ShareName,SharePath,UserName,CredentialIdentity,Dialect,NumOpens,Encrypted,ContinuouslyAvailable) 'SMB client connection (cached snapshot)'}
            'Command'{if($choice.Command -eq 'C'){
                Show-PcListDetails ([pscustomobject]@{
                    CollectedAt=$snapshot.CollectedAt;Status=$snapshot.Status;CollectionIssue=$snapshot.Issue
                    Scope='Outbound SMB connections from this Windows client, visible to the current logon/elevation context. An elevated console may see a different set; an access error may require an Administrator session.'
                    Identity='UserName is the logon identity. CredentialIdentity is the account used for the share connection, which can differ. No password or credential object is displayed.'
                    Limitations='NumOpens is an aggregate count, not a list of filenames or locks. This does not enumerate NAS-wide sessions, other clients, server-side open files, share ACLs or effective write permissions. Zero opens/empty results do not prove a document is unlocked.'
                    Actions='Read-only snapshot; filter by server, share or identity, select for full details, and use R to refresh. No connections are created, disconnected or modified.'
                }) 'SMB collection notes'
            }}
        }
    }
}

function Get-PcSmbDiagnosticCatalog {
    @(
        [pscustomobject]@{Key='1';Id='Connections';Name='Client connections and identities';Command='Get-SmbConnection';Admin=$false;Fields=@()}
        [pscustomobject]@{Key='2';Id='Mappings';Name='Mapped shares and drive letters';Command='Get-SmbMapping';Admin=$false;Fields=@('LocalPath','RemotePath','Status','Persistent')}
        [pscustomobject]@{Key='3';Id='ClientConfiguration';Name='SMB client signing, encryption and guest settings';Command='Get-SmbClientConfiguration';Admin=$false;Fields=@('EnableSecuritySignature','RequireSecuritySignature','EnableInsecureGuestLogons','RequireEncryption','EnableMultiChannel','ConnectionCountPerRssNetworkInterface','DirectoryCacheLifetime','FileInfoCacheLifetime','FileNotFoundCacheLifetime')}
        [pscustomobject]@{Key='4';Id='Multichannel';Name='Client multichannel paths and interfaces';Command='Get-SmbMultichannelConnection';Admin=$false;Fields=@('ServerName','Selected','ClientIpAddress','ServerIpAddress','ClientInterfaceIndex','ServerInterfaceIndex','ClientRssCapable','ClientRdmaCapable','CurrentChannels','MaxChannels')}
        [pscustomobject]@{Key='5';Id='Sessions';Name='Clients connected to THIS Windows file server';Command='Get-SmbSession';Admin=$true;Fields=@('SessionId','ClientComputerName','ClientUserName','NumOpens','SecondsExists','SecondsIdle','Dialect','Encrypted')}
        [pscustomobject]@{Key='6';Id='OpenFiles';Name='Open files hosted by THIS Windows file server';Command='Get-SmbOpenFile';Admin=$true;Fields=@('FileId','SessionId','Path','ShareRelativePath','ClientComputerName','ClientUserName','Permissions','Locks')}
        [pscustomobject]@{Key='7';Id='Shares';Name='Shares hosted by THIS Windows file server';Command='Get-SmbShare';Admin=$false;Fields=@('Name','Path','Description','ScopeName','Special','EncryptData','FolderEnumerationMode','CachingMode','ContinuouslyAvailable')}
        [pscustomobject]@{Key='8';Id='ShareAccess';Name='Share-level permissions on THIS Windows server';Command='Get-SmbShareAccess';Admin=$false;Fields=@('Name','ScopeName','AccountName','AccessControlType','AccessRight')}
    )
}
function Get-PcSmbDiagnosticSnapshot {
    param([ValidateSet('Mappings','ClientConfiguration','Multichannel','Sessions','OpenFiles','Shares','ShareAccess')][string]$Kind,[string]$ShareName)
    $spec=Get-PcSmbDiagnosticCatalog | Where-Object Id -EQ $Kind | Select-Object -First 1
    $rows=New-Object 'Collections.Generic.List[object]';$status='OK';$issue=''
    if(-not (Get-Command $spec.Command -ErrorAction SilentlyContinue)){$status='Unavailable';$issue='Missing '+$spec.Command}
    else{
        try{
            if($Kind -eq 'ShareAccess'){
                if([string]::IsNullOrWhiteSpace($ShareName) -or $ShareName.IndexOfAny([char[]]'*?[]') -ge 0){throw 'Enter one exact local share name, without wildcard characters.'}
                $raw=@(Get-SmbShareAccess -Name $ShareName -ErrorAction Stop)
            }else{$raw=@(& $spec.Command -ErrorAction Stop)}
            $index=0
            foreach($record in $raw){
                if($null -eq $record){continue};$index++
                $projected=[ordered]@{Id=($Kind+'-'+$index)}
                foreach($field in $spec.Fields){$projected[$field]=Get-PcSmbConnectionField $record $field}
                $rows.Add([pscustomobject]$projected)
            }
        }catch{$rows.Clear();$status='Failed';$issue=$_.Exception.Message}
    }
    [pscustomobject]@{CollectedAt=(Get-Date);Status=$status;Issue=$issue;Rows=$rows.ToArray();Kind=$Kind}
}
function Start-PcSmbDiagnosticView([string]$Kind,[string]$ShareName) {
    $snapshot=Get-PcSmbDiagnosticSnapshot $Kind $ShareName;$state=@{}
    $spec=Get-PcSmbDiagnosticCatalog | Where-Object Id -EQ $Kind | Select-Object -First 1
    while($true){
        $items=@(foreach($row in $snapshot.Rows){
            $parts=@(foreach($field in $spec.Fields){'{0}: {1}' -f $field,$row.$field})
            [pscustomobject]@{Id=$row.Id;Label=($parts[0..([math]::Min(2,$parts.Count-1))] -join ' | ');Detail=($parts -join ' | ');SearchText=($parts -join ' ');Data=$row}
        })
        $description=if($snapshot.Status -eq 'OK'){'Snapshot '+$snapshot.CollectedAt.ToString('HH:mm:ss')+' | '+$snapshot.Rows.Count+' returned | Local Windows scope; current logon/elevation context.'}else{$snapshot.Status+': '+$snapshot.Issue}
        $choice=Show-PcMenu -Title ('Windows > Network > SMB > '+$spec.Name) -Items $items -State $state -Filterable -Refreshable -Description $description
        switch($choice.Action){
            'Back'{return}
            'Refresh'{$snapshot=Get-PcSmbDiagnosticSnapshot $Kind $ShareName}
            'Select'{Show-PcListDetails ($choice.Item.Data | Select-Object -Property $spec.Fields) 'SMB details (cached; read-only)'}
        }
    }
}
function Get-PcFilesystemAclSnapshot([string]$LiteralPath) {
    if($LiteralPath -notmatch '^(?:[a-zA-Z]:[\\/]|\\\\[^\\]+\\[^\\]+)'){throw 'Enter an absolute filesystem path, such as C:\Data or \\NAS\Share\Folder.'}
    $item=Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if($item.PSProvider.Name -ne 'FileSystem'){throw 'Only filesystem paths are supported.'}
    $acl=Get-Acl -LiteralPath $item.FullName -ErrorAction Stop
    $rules=@(foreach($rule in $acl.Access){
        [pscustomobject]@{Identity=[string]$rule.IdentityReference;Type=[string]$rule.AccessControlType;Rights=[string]$rule.FileSystemRights;IsInherited=$rule.IsInherited;InheritanceFlags=[string]$rule.InheritanceFlags;PropagationFlags=[string]$rule.PropagationFlags}
    })
    [pscustomobject]@{Path=$item.FullName;Owner=[string]$acl.Owner;InheritanceProtected=$acl.AreAccessRulesProtected;Attributes=[string]$item.Attributes;Rules=$rules;Notes='ACL entries and inheritance only; not an effective-access calculation. Allow/Deny ordering, groups, share permissions and the server filesystem all affect access. A Synology SMB view may not expose every DSM ACL detail.'}
}
function Start-PcFilesystemAclInspector {
    $path=Read-PcInput 'Absolute local or UNC file/folder path (literal; no quotes)'
    if([string]::IsNullOrWhiteSpace($path)){return}
    $snapshot=Get-PcFilesystemAclSnapshot $path
    $state=@{};$index=0
    $items=@(foreach($rule in $snapshot.Rules){
        $index++
        [pscustomobject]@{Id=('ace-'+$index);Label=($rule.Type+' | '+$rule.Identity+' | '+$rule.Rights);Detail=('Inherited: '+$rule.IsInherited+' | '+$rule.InheritanceFlags+' | '+$rule.PropagationFlags);Data=$rule}
    })
    while($true){
        $choice=Show-PcMenu -Title 'Filesystem ACL entries (not calculated effective access)' -Items $items -State $state -Filterable -Description ($snapshot.Path+' | Owner: '+$snapshot.Owner+' | Inheritance protected: '+$snapshot.InheritanceProtected) -Commands @{C='Ownership, attributes and scope'}
        switch($choice.Action){
            'Back'{return}
            'Select'{Show-PcListDetails $choice.Item.Data 'Filesystem ACE (cached)'}
            'Command'{if($choice.Command -eq 'C'){Show-PcListDetails ($snapshot | Select-Object Path,Owner,InheritanceProtected,Attributes,Notes) 'ACL scope and ownership'}}
        }
    }
}
function Start-PcSmbEvents {
    if(-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)){throw 'Get-WinEvent is unavailable.'}
    $logs=@(Get-WinEvent -ListLog 'Microsoft-Windows-SMB*' -ErrorAction Stop | Sort-Object LogName)
    if(-not $logs.Count){Write-Host 'No SMB event channels returned for this Windows installation.';Wait-PcMenuReturn;return}
    $items=@(foreach($log in $logs){[pscustomobject]@{Id=$log.LogName;Label=$log.LogName;Detail=('Enabled: '+$log.IsEnabled+' | Records: '+$log.RecordCount);Data=$log}})
    $state=@{}
    while($true){
        $choice=Show-PcMenu -Title 'Windows > SMB event channels' -Items $items -State $state -Filterable -Description 'Local client/server channels. Disabled logs are not enabled by this tool; permissions may restrict access.'
        if($choice.Action -eq 'Back'){return}
        if($choice.Action -eq 'Select'){Start-PcEventBrowser $choice.Item.Data.LogName}
    }
}
function Start-PcSmbMenu {
    $state=@{}
    while($true){
        $menu=@(foreach($entry in @(Get-PcSmbDiagnosticCatalog)){
            $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@($entry.Command);Admin=$entry.Admin})
            $reason=if($availability.Available){''}else{$availability.Reason}
            New-PcMenuItem $entry.Key $entry.Name 'Check' 'Read-only' $reason
        })
        $events=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false})
        $acl=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@('Get-Item','Get-Acl');Admin=$false})
        $menu+=New-PcMenuItem '9' 'SMB client/server event logs' 'Menu' '' $(if($events.Available){''}else{$events.Reason})
        $menu+=New-PcMenuItem '10' 'Filesystem ACL and inheritance inspector' 'Check' 'Local or UNC path; no permissions are changed' $(if($acl.Available){''}else{$acl.Reason})
        $answer=Read-PcCategoryMenu 'Windows > Network > SMB diagnostics' $menu $state 'Server views query THIS Windows machine, not a Synology NAS. No disconnect, close, delete or permission-change actions.'
        if($null -eq $answer -or $answer -in @('0','B')){return}
        try{
            if($answer -eq '9'){Start-PcSmbEvents;continue}
            if($answer -eq '10'){Start-PcFilesystemAclInspector;continue}
            $entry=Get-PcSmbDiagnosticCatalog | Where-Object Key -EQ $answer | Select-Object -First 1
            if(-not $entry){continue}
            $availability=Get-NetworkAvailability ([pscustomobject]@{MinPS='5.0';Commands=@($entry.Command);Admin=$entry.Admin})
            if(-not $availability.Available){throw $availability.Reason}
            if($entry.Id -eq 'Connections'){Start-PcSmbConnections;continue}
            $share=''
            if($entry.Id -eq 'ShareAccess'){$share=Read-PcInput 'Exact share name hosted on THIS Windows server';if(-not $share){continue}}
            Start-PcSmbDiagnosticView $entry.Id $share
        }catch [OperationCanceledException]{continue}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn}
    }
}
