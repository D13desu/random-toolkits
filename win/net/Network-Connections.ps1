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
function Start-PcNetworkConnections {
    $snapshot=Get-PcNetworkConnections;$state=@{};$protocol='TCP';$tcpState='All'
    while($true){
        $rows=@($snapshot.Rows | Where-Object {($protocol -eq 'Both' -or $_.Protocol -eq $protocol) -and ($tcpState -eq 'All' -or ($_.Protocol -eq 'TCP' -and $_.State -eq $tcpState))})
        $menu=@(foreach($row in $rows){
            $path=if($row.ExecutablePath){$row.ExecutablePath}else{'Executable path unavailable'}
            [pscustomobject]@{Id=$row.Id;Label=('{0} {1} | {2} -> {3}' -f $row.Protocol,$row.State,$row.LocalEndpoint,$row.RemoteEndpoint);Detail=('PID {0} | {1} | {2}' -f $row.ProcessId,$row.ProcessName,$path);SearchText=($row.ProcessId.ToString()+' '+$row.ProcessName+' '+$row.ExecutablePath);Data=$row}
        })
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
