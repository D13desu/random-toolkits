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
