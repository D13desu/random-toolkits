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
                $reused=$process.CreationDate.ToUniversalTime() -gt $socket.CreationTime.ToUniversalTime()
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
