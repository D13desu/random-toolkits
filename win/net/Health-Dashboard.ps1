function New-PcHealthFinding($Status,$Title,$Detail,$Target) {
    [pscustomobject]@{Status=$Status;Title=$Title;Detail=[string]$Detail;Target=$Target}
}
function Get-PcHealthProbes {
    param([switch]$IncludeNetwork)
    @(
        [pscustomobject]@{Name='Disk space';Target='storage';Run={
            $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -OperationTimeoutSec 5 -ErrorAction Stop)
            if(-not $disks.Count){throw 'No fixed logical disks were reported.'}
            foreach($disk in $disks){
                if($disk.Size -le 0){New-PcHealthFinding UNAVAILABLE ($disk.DeviceID+' capacity') 'Capacity was not reported.' storage;continue}
                $percent=100*$disk.FreeSpace/$disk.Size;$status=if($percent -lt 10){'WARN'}else{'PASS'}
                New-PcHealthFinding $status ($disk.DeviceID+' free space') ('{0:N1} GiB free ({1:N1}%). Warning threshold: below 10% free.' -f ($disk.FreeSpace/1GB),$percent) storage
            }
        }}
        [pscustomobject]@{Name='Storage health';Target='storage';Run={
            $disks=@(Get-PhysicalDisk -ErrorAction Stop)
            if(-not $disks.Count){throw 'The storage provider reported no physical disks.'}
            foreach($disk in $disks){
                $health=[string]$disk.HealthStatus
                $status=if($health -eq 'Healthy'){'PASS'}elseif($health -in @('Warning','Unhealthy')){'WARN'}else{'UNAVAILABLE'}
                if($status -eq 'PASS' -and @($disk.OperationalStatus | Where-Object {[string]$_ -ne 'OK'}).Count){$status='REVIEW'}
                New-PcHealthFinding $status ('Storage: '+$disk.FriendlyName) ("Provider health: $health; operation: $($disk.OperationalStatus -join ', '). This is the Windows storage-provider assessment, not a complete surface/SMART test.") storage
            }
        }}
        [pscustomobject]@{Name='Pending reboot';Target='power';Run={
            $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
            $present=@($paths | Where-Object {Test-Path -LiteralPath $_ -ErrorAction Stop})
            if($present.Count){New-PcHealthFinding WARN 'Restart requested by Windows servicing' ($present -join "`n") power}
            else{New-PcHealthFinding PASS 'Servicing reboot indicators' 'Neither of the two servicing reboot markers is present. Other applications may still need a restart.' power}
        }}
        [pscustomobject]@{Name='Automatic services';Target='log:System';Run={
            $stopped=@(Get-CimInstance Win32_Service -Filter "StartMode = 'Auto' AND State <> 'Running'" -OperationTimeoutSec 5 -ErrorAction Stop)
            if(-not $stopped.Count){New-PcHealthFinding PASS 'Automatic services' 'No automatic service is currently outside the Running state.' 'log:System'}
            else{
                $failed=@($stopped | Where-Object {$_.ExitCode -notin @(0,1077,$null)})
                $status=if($failed.Count){'WARN'}else{'REVIEW'}
                $detail=($stopped | ForEach-Object {"$($_.Name): $($_.State), exit code $($_.ExitCode)"}) -join "`n"
                New-PcHealthFinding $status ("{0} automatic services not running" -f $stopped.Count) ("Trigger-start, delayed-start and idle services can legitimately stop. Nonzero exit codes are evidence to inspect, not an instruction to start every service.`n"+$detail) 'log:System'
            }
        }}
        [pscustomobject]@{Name='Recent application crashes';Target='log:Application';Run={
            $events=@(Get-PcEventRecords -LogName Application -Hours 24 -Ids 1000 -Provider 'Application Error' -Limit 100)
            $detail=if($events.Count){($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Message)"}) -join "`n"}else{'No Application Error / 1000 events found in the last 24 hours. Other crash records may use different providers.'}
            $status=if($events.Count){'REVIEW'}else{'PASS'}
            New-PcHealthFinding $status ("Application crash events: {0}{1}" -f $events.Count,$(if($events.Count -eq 100){' (query cap reached)'}else{''})) $detail 'log:Application'
        }}
        [pscustomobject]@{Name='Recent Windows Update failures';Target='log:Microsoft-Windows-WindowsUpdateClient/Operational';Run={
            $events=@(Get-PcEventRecords -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' -Hours 168 -Ids 20 -Limit 100)
            $detail=if($events.Count){($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Message)"}) -join "`n"}else{'No update-install failure events (ID 20) in this channel over seven days. This does not check for missing updates.'}
            $status=if($events.Count){'REVIEW'}else{'PASS'}
            New-PcHealthFinding $status ("Update failure events: {0}{1}" -f $events.Count,$(if($events.Count -eq 100){' (query cap reached)'}else{''})) $detail 'log:Microsoft-Windows-WindowsUpdateClient/Operational'
        }}
        [pscustomobject]@{Name='Power plan';Target='power';Run={
            $power=@(Get-PcPowerOverview);$overview=$power | Where-Object {$_.PSObject.Properties['ActivePlan']} | Select-Object -First 1
            if(-not $overview -or -not $overview.ActivePlan){throw 'Active power plan could not be determined.'}
            New-PcHealthFinding INFO ('Power plan: '+$overview.ActivePlan) ($overview.Device+"`n"+$overview.Assessment+' Balanced is not automatically a fault; choose settings appropriate to AC/battery use.') power
        }}
        [pscustomobject]@{Name='NIC sleep settings';Target='power';Run={
            $nics=@(Get-PcNicPower)
            if(-not $nics.Count){New-PcHealthFinding INFO 'NIC power settings' 'No physical adapters were reported.' power}
            foreach($nic in $nics){
                $status=if($nic.Status -eq 'UNAVAILABLE'){'UNAVAILABLE'}elseif(@($nic.AllowComputerToTurnOffDevice,$nic.SelectiveSuspend,$nic.DeviceSleepOnDisconnect) -contains 'Enabled'){'REVIEW'}else{'INFO'}
                New-PcHealthFinding $status ('NIC sleep: '+$nic.Adapter) ("Power off: $($nic.AllowComputerToTurnOffDevice); selective suspend: $($nic.SelectiveSuspend); disconnect sleep: $($nic.DeviceSleepOnDisconnect). $($nic.Detail)") power
            }
        }}
        [pscustomobject]@{Name='Network configuration';Target='connectivity';Run={
            $adapters=@(Get-NetworkOverview | Where-Object {$_.State -eq 'Up' -and $_.Type -ne 'Loopback'})
            if(-not $adapters.Count){New-PcHealthFinding WARN 'Network adapters' 'No non-loopback adapter reports Up. This does not test external connectivity.' connectivity}
            $addressed=@($adapters | Where-Object Addresses);$unaddressed=@($adapters | Where-Object {-not $_.Addresses})
            if($unaddressed.Count){
                $status=if($addressed.Count){'INFO'}else{'REVIEW'}
                New-PcHealthFinding $status ("{0} active interfaces without IP addresses" -f $unaddressed.Count) ('Virtual/filter interfaces can legitimately lack addresses; they are not separate network failures. Interfaces: '+($unaddressed.Adapter -join ', ')) connectivity
            }
            foreach($adapter in $addressed){
                $status=if(-not $adapter.Gateways -or -not $adapter.DNS){'REVIEW'}else{'INFO'}
                New-PcHealthFinding $status ('Network: '+$adapter.Adapter) ("Addresses: $($adapter.Addresses)`nGateways: $($adapter.Gateways)`nDNS servers: $($adapter.DNS)`nVirtual/VPN/local-only adapters may legitimately have no gateway or DNS. Open connectivity checks to test reachability.") connectivity
            }
        }}
        [pscustomobject]@{Name='AD domain context';Target='ad';Run={
            $context=Get-AdContext
            $status=if($context.Role -eq 'Unknown'){'UNAVAILABLE'}else{'INFO'}
            $detail="$($context.Computer): $($context.Role); domain: $($context.Domain). $($context.Detail)"
            if($context.Role -eq 'Domain member'){$detail+=' Membership alone does not validate trust. Run the live checks or open AD tools to verify trust and DNS.'}
            elseif($context.Role -eq 'Domain controller'){$detail+=' Member-computer secure-channel tests are not appropriate for a domain controller.'}
            else{$detail+=' AD secure-channel checks are not applicable to a workgroup PC.'}
            New-PcHealthFinding $status 'Domain membership / trust scope' $detail ad
        }}
    )
    if($IncludeNetwork){
        [pscustomobject]@{Name='Gateway reachability';Target='connectivity';Run={
            $gateways=@(Get-NetworkOverview | Where-Object State -eq Up | ForEach-Object {$_.Gateways -split ',\s*'} | Where-Object {$_ -and $_ -notin @('0.0.0.0','::')} | Select-Object -Unique -First 3)
            if(-not $gateways.Count){New-PcHealthFinding REVIEW 'Gateway reachability' 'No gateway was reported. VPN or local-only routing may still work.' connectivity}
            foreach($gateway in $gateways){$reply=Test-NetworkPing $gateway;New-PcHealthFinding $reply.Status ('Gateway: '+$gateway) ($reply.Detail+'. ICMP can be blocked; failure does not prove the network is down. At most three configured gateways are checked.') connectivity}
        }}
        [pscustomobject]@{Name='DNS resolution';Target='dns';Run={
            $context=Get-AdContext;$name=if($context.Role -in @('Domain member','Domain controller')){$context.Domain}else{'example.com'}
            try{
                $task=[Net.Dns]::GetHostAddressesAsync($name)
                if(-not $task.Wait(2000)){throw 'Resolver exceeded the two-second wait; the underlying OS lookup may finish later.'}
                $addresses=@($task.Result | ForEach-Object {$_.ToString()});if(-not $addresses.Count){throw 'No addresses returned.'}
                New-PcHealthFinding PASS ('DNS: '+$name) ("System resolver returned: $($addresses -join ', '). Cached results may be used; this does not test AD SRV records or every configured DNS server.") dns
            }catch{New-PcHealthFinding WARN ('DNS: '+$name) $_.Exception.Message dns}
        }}
        [pscustomobject]@{Name='AD secure channel';Target='ad';Run={
            $context=Get-AdContext
            if($context.Role -eq 'Domain member'){
                $result=Test-AdSecureChannel
                New-PcHealthFinding $result.Status 'AD secure channel' ($result.Detail+' A failure can reflect DC reachability; inspect before repairing.') ad
            }else{$status=if($context.Role -eq 'Unknown'){'UNAVAILABLE'}else{'INFO'};New-PcHealthFinding $status 'AD secure channel not run' ("Detected role: $($context.Role). Only domain-member computers use this check; DCs and workgroups are not tested.") ad}
        }}
    }
}
function Get-PcHealthDashboard {
    param([switch]$IncludeNetwork)
    $rows=New-Object 'Collections.Generic.List[object]';$probes=@(Get-PcHealthProbes -IncludeNetwork:$IncludeNetwork);$index=0
    try{
        foreach($probe in $probes){
            Write-Progress -Activity 'Windows health dashboard (read-only)' -Status $probe.Name -PercentComplete (100*$index/$probes.Count)
            try{foreach($row in @(& $probe.Run)){$rows.Add($row)}}catch{$rows.Add((New-PcHealthFinding UNAVAILABLE $probe.Name $_.Exception.Message $probe.Target))}
            $index++
        }
    }finally{Write-Progress -Activity 'Windows health dashboard (read-only)' -Completed}
    $rank=@{WARN=0;REVIEW=1;UNAVAILABLE=2;INFO=3;PASS=4}
    [pscustomobject]@{CollectedAt=(Get-Date);Rows=@($rows.ToArray() | Sort-Object @{Expression={$rank[$_.Status]}},Title)}
}
function Open-PcHealthTarget([string]$Target) {
    if($Target.StartsWith('log:')){Start-PcEventBrowser -DefaultLog $Target.Substring(4) -Quick}
    elseif($Target -in @('storage','power','connectivity','dns','ad')){Start-NetworkCategory $Target}
    else{throw 'Unknown dashboard target.'}
}
function Show-PcHealthFinding($Finding) {
    Write-Host ("`n[{0}] {1}" -f $Finding.Status,$Finding.Title) -ForegroundColor Cyan
    Write-Host $Finding.Detail
    Write-Host 'Related checks/repair menus retain their requirements and yes/no confirmation. No repair is run by opening this finding.'
    while($true){
        $answer=Read-Host '1: open related tools | B / 0 / Enter: back'
        if([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim() -in @('B','0')){return}
        if($answer.Trim() -eq '1'){try{Open-PcHealthTarget $Finding.Target}catch{Write-Warning $_.Exception.Message};return}
    }
}
function Start-PcHealthDashboard {
    $network=$false;$snapshot=Get-PcHealthDashboard;$selected=0;$keyboard=Test-PcEventKeyboard;$pageSize=8
    while($true){
        if($keyboard){Clear-Host}
        $rows=@($snapshot.Rows);$page=[int][math]::Floor($selected/[double]$pageSize)
        Write-Host ("`nWINDOWS HEALTH | {0} | READ ONLY" -f $snapshot.CollectedAt) -ForegroundColor Cyan
        Write-Host 'Snapshot, not a full health certificate. C runs live gateway, DNS and domain-member trust checks (no repair).'
        Write-Host ('Live network checks included: '+$network)
        $counts=($rows | Group-Object Status | ForEach-Object {"$($_.Name): $($_.Count)"}) -join ' | ';Write-Host $counts
        for($i=$page*$pageSize;$i -lt [math]::Min($rows.Count,($page+1)*$pageSize);$i++){
            $marker=if($i -eq $selected){'>'}else{' '};$color=if($rows[$i].Status -eq 'WARN'){'Yellow'}elseif($i -eq $selected){'Cyan'}else{'Gray'}
            Write-Host ('{0}[{1}] {2,-11} {3}' -f $marker,($i+1),$rows[$i].Status,$rows[$i].Title) -ForegroundColor $color
        }
        Write-Host ('Page {0}/{1} | Up/Down: select | Enter: findings/tools | N/P: pages | R: refresh | C: live network checks | B/Esc: back' -f ($page+1),[math]::Max(1,[math]::Ceiling($rows.Count/[double]$pageSize)))
        $answer=Read-PcEventChoice $keyboard 'Number: finding/tools | N/P: pages | R: refresh | C: live checks | B / 0: back'
        switch(([string]$answer).Trim().ToUpperInvariant()){
            'B'{return} '0'{return}
            '@UP'{$selected=[math]::Max(0,$selected-1)}
            '@DOWN'{$selected=[math]::Max(0,[math]::Min($rows.Count-1,$selected+1))}
            '@HOME'{$selected=0} '@END'{$selected=[math]::Max(0,$rows.Count-1)}
            'N'{if(($page+1)*$pageSize -lt $rows.Count){$selected=($page+1)*$pageSize}}
            'P'{$selected=[math]::Max(0,($page-1)*$pageSize)}
            'R'{$snapshot=Get-PcHealthDashboard -IncludeNetwork:$network;$selected=0}
            'C'{$network=$true;$snapshot=Get-PcHealthDashboard -IncludeNetwork;$selected=0}
            '@ENTER'{if($rows.Count){Show-PcHealthFinding $rows[$selected]}}
            default{$number=0;if([int]::TryParse($answer,[ref]$number) -and $number -ge 1 -and $number -le $rows.Count){$selected=$number-1;Show-PcHealthFinding $rows[$selected]}}
        }
    }
}
