# Embedded into Network-Toolkit.ps1 for the single-download launcher.
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
    $page=0;$showAll=$false
    while($true){
        $rows=@($result.Rows | Where-Object {$showAll -or $_.Responded})
        Write-Host ("`nDISCOVERY | {0}/{1} addresses checked | Cancelled: {2} | Displayed: {3}" -f $result.Completed,$result.Requested,$result.Cancelled,$rows.Count) -ForegroundColor Cyan
        Write-Host 'No response does not mean offline. Open ports do not identify services or device type. Closed = connection refused; Error = another connection error.'
        $rows | Select-Object -Skip ($page*20) -First 20 | Format-Table Address,Ping,LatencyMs,OpenTCP,ClosedTCP,NoResponseTCP,ErrorTCP -AutoSize | Out-Host
        $answer=Read-Host 'N/P: pages | A: toggle all/responding | E: export completed results CSV | B / 0: back'
        switch(([string]$answer).Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            'N'{if(($page+1)*20 -lt $rows.Count){$page++}} 'P'{$page=[math]::Max(0,$page-1)}
            'A'{$showAll=-not $showAll;$page=0}
            'E'{
                try{$path=Read-PcInput 'New CSV file path';if(Test-Path -LiteralPath $path){throw 'Choose a new filename; existing files are not overwritten.'};$result.Rows | Select-Object *,@{n='ScanScope';e={$result.Scope}},@{n='ScanCancelled';e={$result.Cancelled}},@{n='AddressesRequested';e={$result.Requested}},@{n='AddressesCompleted';e={$result.Completed}} | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop;Write-Host "Saved: $path"}
                catch [OperationCanceledException] {} catch{Write-Warning $_.Exception.Message}
            }
        }
    }
}
