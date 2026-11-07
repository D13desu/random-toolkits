# Embedded into Windows-Toolkit.ps1 for the single-download launcher.
function ConvertTo-DiscoveryMac([string]$Mac) {
    $value=$Mac.Trim()
    if($value -notmatch '^(?:[0-9A-Fa-f]{12}|(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}|[0-9A-Fa-f]{4}(?:\.[0-9A-Fa-f]{4}){2})$'){return ''}
    return ($value -replace '[:.\-]','').ToUpperInvariant()
}
function Get-DiscoveryOuiDatabase {
    param([string]$CacheDirectory=(Join-Path $env:LOCALAPPDATA 'Random-Toolkits\oui'))
    $map=@{};$date='';$status='Unavailable';$cache=Join-Path $CacheDirectory 'assignments.csv'
    try{
        if(Test-Path -LiteralPath $cache){
            foreach($row in (Import-Csv -LiteralPath $cache -Encoding UTF8 -ErrorAction Stop)){
                if($row.Assignment -notmatch '^(?:[A-F0-9]{6}|[A-F0-9]{7}|[A-F0-9]{9})$' -or [string]::IsNullOrWhiteSpace($row.Organization)){throw 'Invalid cached assignment data.'}
                $map[$row.Assignment]=$row.Organization
            }
            if(-not $map.Count){throw 'Empty cached assignment data.'}
            $date=(Get-Item -LiteralPath $cache).LastWriteTimeUtc.ToString('o');$status='Cached'
        }
    }catch{$map=@{};$date=''}
    $temporary=New-Object 'Collections.Generic.List[string]'
    try{
        $attempt=Join-Path $CacheDirectory 'last-attempt.txt'
        $fresh=$date -and ([datetime]::UtcNow-[datetime]::Parse($date).ToUniversalTime()).TotalDays -lt 30
        $recent=(Test-Path -LiteralPath $attempt) -and ([datetime]::UtcNow-(Get-Item -LiteralPath $attempt).LastWriteTimeUtc).TotalHours -lt 24
        if(-not $fresh -and -not $recent){
            $null=[IO.Directory]::CreateDirectory($CacheDirectory)
            [IO.File]::WriteAllText($attempt,[datetime]::UtcNow.ToString('o'))
            Write-Host 'Downloading IEEE MAC assignment lists for local lookup (cached for 30 days)...'
            $records=New-Object 'Collections.Generic.List[object]';$newMap=@{}
            foreach($source in @(@('oui/oui.csv',6,'MA-L'),@('oui28/mam.csv',7,'MA-M'),@('oui36/oui36.csv',9,'MA-S'))){
                $file=Join-Path $CacheDirectory ([guid]::NewGuid().ToString('N')+'.tmp');$temporary.Add($file)
                Invoke-WebRequest -UseBasicParsing -Uri ('https://standards-oui.ieee.org/'+$source[0]) -OutFile $file -TimeoutSec 15 -ErrorAction Stop
                $count=0
                foreach($row in (Import-Csv -LiteralPath $file -Encoding UTF8 -ErrorAction Stop)){
                    if($row.Registry -ne $source[2] -or $row.Assignment -notmatch ('^[A-Fa-f0-9]{'+$source[1]+'}$') -or [string]::IsNullOrWhiteSpace($row.'Organization Name')){throw 'Invalid IEEE assignment list.'}
                    $key=$row.Assignment.ToUpperInvariant();$name=$row.'Organization Name' -replace '[\x00-\x1F\x7F]',' '
                    $records.Add([pscustomobject]@{Assignment=$key;Organization=$name});$newMap[$key]=$name;$count++
                }
                if(-not $count){throw 'Empty IEEE assignment list.'}
            }
            $staged=Join-Path $CacheDirectory ([guid]::NewGuid().ToString('N')+'.tmp');$temporary.Add($staged)
            $records.ToArray() | Export-Csv -LiteralPath $staged -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Move-Item -LiteralPath $staged -Destination $cache -Force -ErrorAction Stop
            $map=$newMap;$date=(Get-Item -LiteralPath $cache).LastWriteTimeUtc.ToString('o');$status='Downloaded'
        }elseif($map.Count -and -not $fresh){$status='Stale cache'}
    }catch{
        $status=if($map.Count){'Stale cache (refresh unavailable)'}else{'Unavailable (download/cache error)'}
        Write-Verbose $_.Exception.Message
        Write-Warning 'IEEE lookup data could not be refreshed. Discovery still works; cached assignments will be used when available.'
    }finally{foreach($file in $temporary){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}}}
    [pscustomobject]@{Entries=$map;RetrievedUtc=$date;Status=$status}
}
function Resolve-DiscoveryOui([string]$Mac,$Database) {
    $value=ConvertTo-DiscoveryMac $Mac;$prefix='';$vendor='';$kind='Invalid MAC'
    if($value){
        $first=[Convert]::ToInt32($value.Substring(0,2),16)
        if($value -eq '000000000000'){$kind='Unspecified'}
        elseif($value -eq 'FFFFFFFFFFFF'){$kind='Broadcast'}
        elseif($first -band 1){$kind='Multicast'}
        elseif($first -band 2){$kind='Locally administered (may be randomized)'}
        elseif(-not $Database -or -not $Database.Entries.Count){$kind='Database unavailable'}
        else{
            $kind='No IEEE match'
            foreach($length in @(9,7,6)){
                $candidate=$value.Substring(0,$length)
                if($Database.Entries.ContainsKey($candidate)){$prefix=$candidate+'/'+($length*4);$vendor=$Database.Entries[$candidate];$kind='IEEE assignment';break}
            }
        }
    }
    $formatted=if($value){([regex]::Matches($value,'..') | ForEach-Object {$_.Value}) -join ':'}else{''}
    [pscustomobject]@{MAC=$formatted;OuiPrefix=$prefix;Vendor=$vendor;MacStatus=$kind}
}
function Add-DiscoveryMacInfo($Rows,$Database,[object[]]$Neighbors) {
    $index=@{}
    foreach($neighbor in $Neighbors){
        if([string]$neighbor.State -notin @('Reachable','Stale','Delay','Probe','Permanent')){continue}
        $mac=ConvertTo-DiscoveryMac ([string]$neighbor.LinkLayerAddress)
        if(-not $mac -or $mac -in @('000000000000','FFFFFFFFFFFF')){continue}
        if(-not $index.ContainsKey([string]$neighbor.IPAddress)){$index[[string]$neighbor.IPAddress]=@()}
        $index[[string]$neighbor.IPAddress]+=$neighbor
    }
    foreach($row in $Rows){
        $matches=@($index[[string]$row.Address] | Where-Object {$null -ne $_})
        $macs=@($matches | ForEach-Object {ConvertTo-DiscoveryMac $_.LinkLayerAddress} | Select-Object -Unique)
        $info=Resolve-DiscoveryOui '' $Database
        if($macs.Count -eq 1){$info=Resolve-DiscoveryOui $macs[0] $Database}
        elseif($macs.Count -gt 1){$info.MacStatus='Ambiguous neighbor entries'}
        else{$info.MacStatus='No neighbor MAC available'}
        foreach($property in $info.PSObject.Properties){$row | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force}
        $row | Add-Member -NotePropertyName MacInterfaces -NotePropertyValue (($matches | Select-Object -ExpandProperty InterfaceIndex -Unique) -join ',') -Force
        $row | Add-Member -NotePropertyName MacNeighborState -NotePropertyValue (($matches | ForEach-Object {[string]$_.State} | Select-Object -Unique) -join ',') -Force
        $row | Add-Member -NotePropertyName OuiRetrievedUtc -NotePropertyValue $Database.RetrievedUtc -Force
        $row | Add-Member -NotePropertyName OuiDatabaseStatus -NotePropertyValue $Database.Status -Force
    }
}
function ConvertTo-DiscoveryNumber([string]$Address) {
    if($Address -notmatch '^\d{1,3}(\.\d{1,3}){3}$'){throw 'Use dotted-decimal IPv4 addresses.'}
    [uint64]$value=0
    foreach($part in $Address.Split('.')){if([int]$part -gt 255){throw 'IPv4 octets must be 0-255.'};$value=$value*256+[int]$part}
    return $value
}
function ConvertFrom-DiscoveryNumber([uint64]$Value) {
    return ('{0}.{1}.{2}.{3}' -f (($Value -shr 24) -band 255),(($Value -shr 16) -band 255),(($Value -shr 8) -band 255),($Value -band 255))
}
function Get-DiscoveryTargets([string]$Scope) {
    $text=$Scope.Trim();[uint64]$first=0;[uint64]$last=0
    if($text.Contains('/')){
        $parts=$text.Split('/');$prefix=0
        if($parts.Count -ne 2 -or -not [int]::TryParse($parts[1],[ref]$prefix) -or $prefix -lt 22 -or $prefix -gt 32){throw 'Use an IPv4 CIDR prefix from /22 to /32 (maximum 1024 addresses).'}
        $ip=ConvertTo-DiscoveryNumber $parts[0];[uint64]$size=[math]::Pow(2,32-$prefix)
        $first=[uint64]([math]::Floor($ip/[double]$size)*$size);$last=$first+$size-1
        if($prefix -le 30){$first++;$last--}
    }elseif($text.Contains('-')){
        $parts=$text.Split('-');if($parts.Count -ne 2){throw 'Use startIPv4-endIPv4.'}
        $first=ConvertTo-DiscoveryNumber $parts[0].Trim();$last=ConvertTo-DiscoveryNumber $parts[1].Trim()
    }else{$first=ConvertTo-DiscoveryNumber $text;$last=$first}
    if($last -lt $first -or $last-$first+1 -gt 1024){throw 'Choose an ascending range of at most 1024 addresses.'}
    if($first -eq 0 -or $last -ge 3758096384){throw 'Unspecified, multicast and reserved broadcast targets are not supported.'}
    for($n=$first;$n -le $last;$n++){ConvertFrom-DiscoveryNumber $n}
}
function Get-DiscoveryPorts([string]$Text) {
    $ports=@($Text.Split(',') | ForEach-Object {
        $port=0;if(-not [int]::TryParse($_.Trim(),[ref]$port) -or $port -lt 1 -or $port -gt 65535){throw 'Ports must be comma-separated integers from 1 to 65535.'};$port
    } | Select-Object -Unique)
    if($ports.Count -gt 16){throw 'Choose at most 16 TCP ports.'}
    return $ports
}
function Read-DiscoveryCancelKey {
    try{if(-not [Console]::IsInputRedirected -and [Console]::KeyAvailable){return [Console]::ReadKey($true).Key}}catch{}
}
function Invoke-NetworkDiscovery {
    param([Parameter(Mandatory=$true)][string]$Scope,[int[]]$Ports=@(22,80,443,445,3389,9100),
        [ValidateRange(100,2000)][int]$TimeoutMs=400,[ValidateRange(1,64)][int]$Concurrency=32)
    $targets=@(Get-DiscoveryTargets $Scope)
    $Ports=@(Get-DiscoveryPorts ($Ports -join ','))
    $worker={param($ip,$ports,$timeout)
        $pingStatus='No response';$latency=$null;$ping=New-Object Net.NetworkInformation.Ping
        try{$reply=$ping.Send($ip,$timeout);$pingStatus=[string]$reply.Status;if($reply.Status -eq 'Success'){$latency=$reply.RoundtripTime}}
        catch{$pingStatus='Error'}finally{$ping.Dispose()}
        $open=@();$closed=@();$unanswered=@();$errors=@()
        foreach($port in $ports){
            $client=New-Object Net.Sockets.TcpClient;$pending=$null
            try{
                $pending=$client.BeginConnect($ip,$port,$null,$null)
                if($pending.AsyncWaitHandle.WaitOne($timeout)){$client.EndConnect($pending);$open+=$port}else{$unanswered+=$port}
            }catch{
                $errorObject=$_.Exception;while($errorObject.InnerException){$errorObject=$errorObject.InnerException}
                if($errorObject -is [Net.Sockets.SocketException] -and $errorObject.SocketErrorCode -eq 'ConnectionRefused'){$closed+=$port}
                else{$errors+=$port}
            }finally{$client.Close();if($pending){$pending.AsyncWaitHandle.Close()}}
        }
        [pscustomobject]@{Address=$ip;Responded=($pingStatus -eq 'Success' -or $open.Count -gt 0 -or $closed.Count -gt 0);Ping=$pingStatus;LatencyMs=$latency;OpenTCP=($open -join ',');ClosedTCP=($closed -join ',');NoResponseTCP=($unanswered -join ',');ErrorTCP=($errors -join ',')}
    }
    $pool=[RunspaceFactory]::CreateRunspacePool(1,$Concurrency);$pool.Open()
    $active=New-Object Collections.ArrayList;$rows=New-Object 'Collections.Generic.List[object]';$next=0;$cancelled=$false
    try{
        while($next -lt $targets.Count -or $active.Count){
            while($next -lt $targets.Count -and $active.Count -lt $Concurrency){
                $ps=[PowerShell]::Create();$ps.RunspacePool=$pool
                $null=$ps.AddScript($worker.ToString()).AddArgument($targets[$next]).AddArgument($Ports).AddArgument($TimeoutMs)
                $null=$active.Add([pscustomobject]@{Shell=$ps;Handle=$ps.BeginInvoke()});$next++
            }
            foreach($job in @($active.ToArray())){
                if($job.Handle.IsCompleted){
                    try{foreach($row in $job.Shell.EndInvoke($job.Handle)){$rows.Add($row)};if($job.Shell.HadErrors){throw ($job.Shell.Streams.Error | Out-String)}}
                    finally{$job.Shell.Dispose();$active.Remove($job)}
                }
            }
            Write-Progress -Activity 'Network discovery' -Status ("{0}/{1} addresses complete | B: stop and browse partial results" -f $rows.Count,$targets.Count) -PercentComplete (100*$rows.Count/$targets.Count)
            $key=Read-DiscoveryCancelKey
            if($key -eq 'B' -or $key -eq 'Escape'){$cancelled=$true;break}
            if($active.Count){Start-Sleep -Milliseconds 50}
        }
    }finally{
        foreach($job in $active){$job.Shell.Stop();$job.Shell.Dispose()}
        $pool.Close();$pool.Dispose();Write-Progress -Activity 'Network discovery' -Completed
    }
    [pscustomobject]@{Scope=$Scope;Requested=$targets.Count;Completed=$rows.Count;Cancelled=$cancelled;Rows=@($rows.ToArray() | Sort-Object {ConvertTo-DiscoveryNumber $_.Address})}
}
function New-NetworkDiscoveryMenuItem($Row,[switch]$ProbeView) {
    $open=if([string]::IsNullOrWhiteSpace([string]$Row.OpenTCP)){'none'}else{[string]$Row.OpenTCP}
    $labelParts=@(
        [pscustomobject]@{Text=([string]$Row.Address);Color='Cyan'}
        [pscustomobject]@{Text=' | TCP open: ';Color='DarkGray'}
        [pscustomobject]@{Text=$open;Color=$(if($open -eq 'none'){'DarkGray'}else{'Yellow'})}
    )
    if($ProbeView){
        $detail="Ping: $($Row.Ping) | $($Row.LatencyMs) ms | Open: $($Row.OpenTCP) | Closed: $($Row.ClosedTCP) | No response: $($Row.NoResponseTCP) | Errors: $($Row.ErrorTCP)"
        $pingColor=if($Row.Ping -eq 'Success'){'Green'}elseif($Row.Ping -eq 'Error'){'Red'}else{'DarkGray'}
        $detailParts=@(
            [pscustomobject]@{Text='Ping: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.Ping);Color=$pingColor}
            [pscustomobject]@{Text=(' | '+[string]$Row.LatencyMs+' ms | Open: ');Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.OpenTCP);Color='Yellow'}
            [pscustomobject]@{Text=' | Closed: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.ClosedTCP);Color='Gray'}
            [pscustomobject]@{Text=' | No response: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.NoResponseTCP);Color='DarkGray'}
            [pscustomobject]@{Text=' | Errors: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.ErrorTCP);Color='Red'}
        )
    }else{
        $detail="MAC: $($Row.MAC) | $($Row.Vendor) | $($Row.MacStatus)"
        $detailParts=@(
            [pscustomobject]@{Text='MAC: ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.MAC);Color='Magenta'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.Vendor);Color='Cyan'}
            [pscustomobject]@{Text=' | ';Color='DarkGray'},[pscustomobject]@{Text=([string]$Row.MacStatus);Color='Gray'}
        )
    }
    [pscustomobject]@{Id=$Row.Address;Label=($Row.Address+' | TCP open: '+$Row.OpenTCP);Detail=$detail;LabelParts=$labelParts;DetailParts=$detailParts;SearchText=($Row.MAC+' '+$Row.Vendor+' '+$Row.Ping);Data=$Row}
}
function Start-NetworkDiscovery {
    Write-Host 'NETWORK DISCOVERY | IPv4 ICMP + TCP connect | No administrator required' -ForegroundColor Cyan
    if(Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue){Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '127.*'} | Select-Object InterfaceAlias,IPAddress,PrefixLength | Format-Table -AutoSize | Out-Host}
    $scope=Read-PcInput 'Target CIDR, single IPv4 or startIPv4-endIPv4 (max 1024 addresses)'
    $targets=@(Get-DiscoveryTargets $scope)
    $text=Read-PcInput 'TCP ports [22,80,443,445,3389,9100; maximum 16]'
    if([string]::IsNullOrWhiteSpace($text)){$text='22,80,443,445,3389,9100'}
    $ports=@(Get-DiscoveryPorts $text)
    $timeout=400;$answer=Read-PcInput 'Probe timeout milliseconds [400; 100-2000]'
    if(-not [string]::IsNullOrWhiteSpace($answer)){
        if(-not [int]::TryParse($answer,[ref]$timeout) -or $timeout -lt 100 -or $timeout -gt 2000){throw 'Timeout must be 100-2000 milliseconds.'}
    }
    Write-Host ("Scanning {0} through {1}: {2} addresses; TCP ports {3}. B stops the scan." -f $targets[0],$targets[-1],$targets.Count,($ports -join ','))
    $result=Invoke-NetworkDiscovery -Scope $scope -Ports $ports -TimeoutMs $timeout
    $neighbors=@()
    try{if(Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue){$neighbors=@(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)}}catch{Write-Warning 'Neighbor cache unavailable; MAC addresses will be omitted.'}
    $database=Get-DiscoveryOuiDatabase
    Add-DiscoveryMacInfo $result.Rows $database $neighbors
    $state=@{};$showAll=$false;$probeView=$false
    while($true){
        $rows=@($result.Rows | Where-Object {$showAll -or $_.Responded})
        $menu=@(foreach($row in $rows){New-NetworkDiscoveryMenuItem $row -ProbeView:$probeView})
        $description="$($result.Completed)/$($result.Requested) checked | Partial/cancelled: $($result.Cancelled). No response does not mean offline; MAC/vendor are unverified cache observations."
        $choice=Show-PcMenu -Title 'Windows > Network > Discovery' -Items $menu -State $state -Filterable -Refreshable -Description $description -Commands @{A=('All/responding (all: '+$showAll+')');D='MAC/probe view';M='Lookup MAC';E='Export all scan rows to CSV';L='Scan and vendor-data notes'}
        switch($choice.Action){
            'Back'{return}
            'Select'{Show-PcListDetails $choice.Item.Data 'Device observations'}
            'Refresh'{
                Write-Host "Rescan the same scope: $scope; ports: $($ports -join ', ')"
                $result=Invoke-NetworkDiscovery -Scope $scope -Ports $ports -TimeoutMs $timeout
                $neighbors=@();try{if(Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue){$neighbors=@(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)}}catch{Write-Warning 'Neighbor cache unavailable.'}
                Add-DiscoveryMacInfo $result.Rows $database $neighbors
            }
            'Command'{switch($choice.Command){
                'A'{$showAll=-not $showAll}
                'D'{$probeView=-not $probeView}
                'L'{Show-PcListDetails ([pscustomobject]@{Scope=$scope;Completed=$result.Completed;Requested=$result.Requested;Cancelled=$result.Cancelled;IEEEStatus=$database.Status;RetrievedUTC=$database.RetrievedUtc;Notes='No response does not mean offline. Open ports do not identify services/device type. Closed means refused. MACs are exact-IP neighbor-cache observations, possibly stale/proxied. Routed targets usually have no MAC. Local/randomized MACs have no vendor attribution; vendor is the registered assignee, not verified identity.'}) 'Scan notes'}
                'M'{try{Show-PcListDetails (Resolve-DiscoveryOui (Read-PcInput 'MAC address') $database) 'MAC lookup'}catch [OperationCanceledException]{}}
                'E'{
                    try{$path=Read-PcInput 'New CSV file path';if(Test-Path -LiteralPath $path){throw 'Choose a new filename; existing files are not overwritten.'};$result.Rows | Select-Object *,@{n='ScanScope';e={$result.Scope}},@{n='ScanCancelled';e={$result.Cancelled}},@{n='AddressesRequested';e={$result.Requested}},@{n='AddressesCompleted';e={$result.Completed}} | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop;Write-Host "Saved: $path";Wait-PcMenuReturn}
                    catch [OperationCanceledException]{}catch{Write-Warning $_.Exception.Message;Wait-PcMenuReturn}
                }
            }}
        }
    }
}
