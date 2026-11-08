function Get-PcCertificateDnsNames($Certificate) {
    $names=New-Object 'Collections.Generic.List[string]'
    if($Certificate.PSObject.Properties['DnsNameList']){
        foreach($name in @($Certificate.DnsNameList)){
            $value=if($name.PSObject.Properties['Unicode']){[string]$name.Unicode}else{[string]$name}
            if($value -and -not $names.Contains($value)){$names.Add($value)}
        }
    }
    if(-not $names.Count){
        $simple=$Certificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::DnsName,$false)
        if($simple){$names.Add($simple)}
    }
    $names.ToArray()
}

function Get-PcCertificateEkus($Certificate) {
    $values=New-Object 'Collections.Generic.List[string]'
    foreach($extension in @($Certificate.Extensions)){
        if($extension.Oid.Value -ne '2.5.29.37'){continue}
        try{
            $eku=New-Object Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($extension,$extension.Critical)
            foreach($oid in $eku.EnhancedKeyUsages){$values.Add($(if($oid.FriendlyName){$oid.FriendlyName}else{$oid.Value}))}
        }catch{$values.Add('Unreadable EKU extension')}
    }
    $values.ToArray()
}

function Get-PcCertificateKeyInfo($Certificate) {
    $algorithm=$Certificate.PublicKey.Oid.FriendlyName
    $size=$null
    try{$size=$Certificate.PublicKey.Key.KeySize}catch{}
    [pscustomobject]@{Algorithm=$algorithm;Size=$size}
}

function Get-PcCertificateAssessment($Certificate,[string]$Location,[string]$Store,[int]$WarningDays=30) {
    $now=Get-Date;$status='PASS';$findings=New-Object 'Collections.Generic.List[string]'
    if($Certificate.NotAfter -lt $now){$status='WARN';$findings.Add('Expired')}
    elseif($Certificate.NotBefore -gt $now){$status='WARN';$findings.Add('Not yet valid')}
    elseif($Certificate.NotAfter -le $now.AddDays($WarningDays)){$status='WARN';$findings.Add("Expires within $WarningDays days")}
    $key=Get-PcCertificateKeyInfo $Certificate
    if([string]$Certificate.SignatureAlgorithm.FriendlyName -match '(?i)md5|sha1'){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('Legacy signature algorithm')
    }
    if($key.Algorithm -match '(?i)RSA' -and $key.Size -and $key.Size -lt 2048){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('RSA key shorter than 2048 bits')
    }
    if($Store -in @('My','WebHosting') -and -not $Certificate.HasPrivateKey){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('No private key')
    }
    if($Store -in @('My','WebHosting') -and $Certificate.Subject -eq $Certificate.Issuer){
        if($status -eq 'PASS'){$status='REVIEW'};$findings.Add('Self-signed certificate in a leaf store')
    }
    $ekus=@(Get-PcCertificateEkus $Certificate)
    [pscustomobject]@{
        Status=$status;Location=$Location;Store=$Store;Subject=$Certificate.Subject
        DnsNames=@(Get-PcCertificateDnsNames $Certificate) -join ', '
        Issuer=$Certificate.Issuer;NotBefore=$Certificate.NotBefore;NotAfter=$Certificate.NotAfter
        DaysRemaining=[math]::Floor(($Certificate.NotAfter-$now).TotalDays);Thumbprint=$Certificate.Thumbprint
        HasPrivateKey=$Certificate.HasPrivateKey;KeyAlgorithm=$key.Algorithm;KeySize=$key.Size
        SignatureAlgorithm=$Certificate.SignatureAlgorithm.FriendlyName;EnhancedKeyUsage=$ekus -join ', '
        Finding=$(if($findings.Count){$findings -join '; '}else{'No issue found by the local metadata checks.'})
        Detail='Metadata assessment only. Application bindings, chain trust, revocation and private-key permissions are separate checks.'
    }
}

function Get-PcCertificateStoreItems([string]$Location,[string]$Store) {
    @(Get-ChildItem -LiteralPath ("Cert:\{0}\{1}" -f $Location,$Store) -ErrorAction Stop)
}

function Get-PcCertificateInventory {
    param([int]$WarningDays=30)
    foreach($location in @('LocalMachine','CurrentUser')){
        foreach($store in @('My','WebHosting')){
            try{
                foreach($certificate in @(Get-PcCertificateStoreItems $location $store)){
                    Get-PcCertificateAssessment $certificate $location $store $WarningDays
                }
            }catch{
                [pscustomobject]@{Status='UNAVAILABLE';Location=$location;Store=$store;Subject='Certificate store unavailable';Finding=$_.Exception.Message;Detail='The toolkit continued with the remaining stores.'}
            }
        }
    }
}

function Find-PcCertificate {
    param([Parameter(Mandatory=$true)][string]$Thumbprint)
    $normalized=($Thumbprint -replace '[^0-9a-fA-F]','').ToUpperInvariant()
    if(-not $normalized){throw 'Enter a certificate thumbprint.'}
    foreach($location in @('LocalMachine','CurrentUser')){
        foreach($store in @('My','WebHosting','CA','Root','TrustedPeople')){
            try{
                $match=Get-PcCertificateStoreItems $location $store | Where-Object {($_.Thumbprint -replace '\s','').ToUpperInvariant() -eq $normalized} | Select-Object -First 1
                if($match){return [pscustomobject]@{Certificate=$match;Location=$location;Store=$store}}
            }catch{}
        }
    }
    throw "Certificate $normalized was not found in the inspected user or computer stores."
}

function Get-PcCertificateFromInput([string]$InputValue) {
    $value=$InputValue.Trim()
    if(-not $value){throw 'Enter a certificate thumbprint or a .cer/.crt file path.'}
    if(Test-Path -LiteralPath $value -PathType Leaf){
        $full=[IO.Path]::GetFullPath($value)
        if([IO.Path]::GetExtension($full).ToLowerInvariant() -notin @('.cer','.crt','.der')){throw 'Only public .cer, .crt, or .der certificate files are accepted. PFX/private-key files are not loaded.'}
        $certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2($full)
        return [pscustomobject]@{Certificate=$certificate;Source=$full;Disposable=$true}
    }
    $found=Find-PcCertificate $value
    [pscustomobject]@{Certificate=$found.Certificate;Source=("{0}\{1}" -f $found.Location,$found.Store);Disposable=$false}
}

function Test-PcCertificateChain {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Certificate,[switch]$OnlineRevocation,[string]$Source='Certificate')
    $chain=New-Object Security.Cryptography.X509Certificates.X509Chain
    try{
        $chain.ChainPolicy.RevocationMode=if($OnlineRevocation){[Security.Cryptography.X509Certificates.X509RevocationMode]::Online}else{[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck}
        $chain.ChainPolicy.RevocationFlag=[Security.Cryptography.X509Certificates.X509RevocationFlag]::EntireChain
        $chain.ChainPolicy.VerificationFlags=[Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
        $chain.ChainPolicy.UrlRetrievalTimeout=[timespan]::FromSeconds(10)
        $valid=$chain.Build($Certificate)
        $overall=@($chain.ChainStatus | ForEach-Object {$_.Status.ToString()+': '+$_.StatusInformation.Trim()}) -join '; '
        if(-not $overall){$overall='Chain built successfully.'}
        $index=0
        foreach($element in @($chain.ChainElements)){
            $statuses=@($element.ChainElementStatus | ForEach-Object {$_.Status.ToString()+': '+$_.StatusInformation.Trim()}) -join '; '
            if(-not $statuses){$statuses='OK'}
            [pscustomobject]@{Status=$(if($valid){'PASS'}else{'WARN'});Source=$Source;Position=$index;Subject=$element.Certificate.Subject;Issuer=$element.Certificate.Issuer;NotAfter=$element.Certificate.NotAfter;Thumbprint=$element.Certificate.Thumbprint;ChainStatus=$statuses;RevocationMode=$chain.ChainPolicy.RevocationMode;Detail=$overall}
            $index++
        }
        if(-not $chain.ChainElements.Count){[pscustomobject]@{Status='WARN';Source=$Source;Position=0;Subject=$Certificate.Subject;Thumbprint=$Certificate.Thumbprint;ChainStatus=$overall;RevocationMode=$chain.ChainPolicy.RevocationMode;Detail='Windows returned no chain elements.'}}
    }finally{$chain.Dispose()}
}

function Invoke-PcCertificateChainPrompt {
    $inputValue=Read-PcInput 'Certificate thumbprint or .cer/.crt path'
    $online=(Read-PcInput 'Check revocation online? [y/N]') -match '^(?i:y|yes)$'
    $selected=Get-PcCertificateFromInput $inputValue
    try{Test-PcCertificateChain -Certificate $selected.Certificate -OnlineRevocation:$online -Source $selected.Source}
    finally{if($selected.Disposable){$selected.Certificate.Dispose()}}
}

function Connect-PcTcpClient([string]$HostName,[int]$Port,[int]$TimeoutMilliseconds) {
    $client=New-Object Net.Sockets.TcpClient
    $pending=$client.BeginConnect($HostName,$Port,$null,$null)
    try{
        if(-not $pending.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)){$client.Dispose();throw "TCP connection timed out after $TimeoutMilliseconds ms."}
        try{$client.EndConnect($pending)}catch{$client.Dispose();throw}
    }finally{$pending.AsyncWaitHandle.Close()}
    $client
}

function Test-PcTlsEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$HostName,
        [ValidateRange(1,65535)][int]$Port=443,
        [ValidateSet('SystemDefault','Tls12','Tls11','Tls')][string]$Protocol='SystemDefault',
        [ValidateRange(1000,30000)][int]$TimeoutMilliseconds=8000,
        [switch]$OnlineRevocation
    )
    $dnsTask=[Net.Dns]::GetHostAddressesAsync($HostName)
    if(-not $dnsTask.Wait($TimeoutMilliseconds)){throw "DNS resolution timed out after $TimeoutMilliseconds ms."}
    $addresses=@($dnsTask.Result | ForEach-Object {$_.IPAddressToString})
    if(-not $addresses.Count){throw "DNS returned no addresses for $HostName."}
    $watch=[Diagnostics.Stopwatch]::StartNew();$client=$null;$stream=$null;$remote=$null;$policyErrors=$null
    try{
        $client=Connect-PcTcpClient $HostName $Port $TimeoutMilliseconds;$tcpMs=$watch.ElapsedMilliseconds;$watch.Restart()
        $client.ReceiveTimeout=$TimeoutMilliseconds;$client.SendTimeout=$TimeoutMilliseconds
        $callback=[Net.Security.RemoteCertificateValidationCallback]{param($sender,$certificate,$chain,$errors)$script:PcTlsRemoteCertificateBytes=$certificate.GetRawCertData();$script:PcTlsPolicyErrors=$errors;return $true}
        $script:PcTlsRemoteCertificateBytes=$null;$script:PcTlsPolicyErrors=$null
        $stream=New-Object Net.Security.SslStream($client.GetStream(),$false,$callback)
        $stream.ReadTimeout=$TimeoutMilliseconds;$stream.WriteTimeout=$TimeoutMilliseconds
        $requested=switch($Protocol){'Tls12'{[Security.Authentication.SslProtocols]::Tls12}'Tls11'{[Security.Authentication.SslProtocols]::Tls11}'Tls'{[Security.Authentication.SslProtocols]::Tls}default{[Security.Authentication.SslProtocols]::None}}
        $stream.AuthenticateAsClient($HostName,$null,$requested,$false);$tlsMs=$watch.ElapsedMilliseconds
        if(-not $script:PcTlsRemoteCertificateBytes){throw 'The peer did not present a certificate.'}
        $remote=New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$script:PcTlsRemoteCertificateBytes)
        $policyErrors=[string]$script:PcTlsPolicyErrors
        $chainRows=@(Test-PcCertificateChain -Certificate $remote -OnlineRevocation:$OnlineRevocation -Source ("{0}:{1}" -f $HostName,$Port))
        $chainValid=-not @($chainRows | Where-Object Status -ne 'PASS').Count
        $status=if($policyErrors -eq 'None' -and $chainValid -and $remote.NotBefore -le (Get-Date) -and $remote.NotAfter -ge (Get-Date)){'PASS'}else{'WARN'}
        [pscustomobject]@{
            Status=$status;Host=$HostName;Port=$Port;Addresses=$addresses -join ', ';RequestedProtocol=$Protocol
            NegotiatedProtocol=$stream.SslProtocol;Cipher=$stream.CipherAlgorithm;CipherStrength=$stream.CipherStrength
            Hash=$stream.HashAlgorithm;HashStrength=$stream.HashStrength;KeyExchange=$stream.KeyExchangeAlgorithm;KeyExchangeStrength=$stream.KeyExchangeStrength
            TcpMilliseconds=$tcpMs;TlsMilliseconds=$tlsMs;Subject=$remote.Subject;DnsNames=@(Get-PcCertificateDnsNames $remote) -join ', '
            Issuer=$remote.Issuer;NotBefore=$remote.NotBefore;NotAfter=$remote.NotAfter;Thumbprint=$remote.Thumbprint
            PolicyErrors=$policyErrors;ChainStatus=($chainRows | Select-Object -ExpandProperty Detail -First 1)
            Detail='The diagnostic accepted the presented certificate only to inspect it and sent no application data. PolicyErrors and ChainStatus remain authoritative findings.'
        }
    }finally{
        $script:PcTlsRemoteCertificateBytes=$null;$script:PcTlsPolicyErrors=$null
        if($remote){$remote.Dispose()};if($stream){$stream.Dispose()};if($client){$client.Dispose()}
    }
}

function Invoke-PcTlsEndpointPrompt {
    $hostName=(Read-PcInput 'TLS host name').Trim();if(-not $hostName){throw 'Enter a TLS host name.'}
    $portText=(Read-PcInput 'Port [443]').Trim();$port=443
    if($portText -and (-not [int]::TryParse($portText,[ref]$port) -or $port -lt 1 -or $port -gt 65535)){throw 'Port must be from 1 to 65535.'}
    $protocolText=(Read-PcInput 'Protocol: system, tls12, tls11 or tls [system]').Trim().ToLowerInvariant()
    $protocol=switch($protocolText){'tls12'{'Tls12'}'tls11'{'Tls11'}'tls'{'Tls'}default{'SystemDefault'}}
    $online=(Read-PcInput 'Check certificate revocation online? [y/N]') -match '^(?i:y|yes)$'
    Test-PcTlsEndpoint -HostName $hostName -Port $port -Protocol $protocol -OnlineRevocation:$online
}

function Invoke-PcNetshHttp([string[]]$Arguments) {
    $output=@(& netsh.exe @Arguments 2>&1);$exit=$LASTEXITCODE
    [pscustomobject]@{ExitCode=$exit;Output=@($output | ForEach-Object {[string]$_})}
}

function ConvertFrom-PcHttpSslBindingText([string[]]$Lines) {
    $rows=New-Object 'Collections.Generic.List[object]';$current=$null
    foreach($line in $Lines){
        if($line -match '^\s*(IP:port|Hostname:port|Central Certificate Store)\s*:\s*(.+?)\s*$'){
            if($current){$rows.Add([pscustomobject]$current)}
            $current=[ordered]@{Binding=$Matches[2].Trim();BindingType=$Matches[1];CertificateHash='';CertificateStore='';ApplicationId='';Raw=New-Object 'Collections.Generic.List[string]'}
        }
        if($current){
            $current.Raw.Add($line.Trim())
            if($line -match '^\s*Certificate Hash\s*:\s*(.+?)\s*$'){$current.CertificateHash=($Matches[1] -replace '\s','')}
            elseif($line -match '^\s*Certificate Store Name\s*:\s*(.+?)\s*$'){$current.CertificateStore=$Matches[1].Trim()}
            elseif($line -match '^\s*Application ID\s*:\s*(.+?)\s*$'){$current.ApplicationId=$Matches[1].Trim()}
        }
    }
    if($current){$rows.Add([pscustomobject]$current)}
    $rows.ToArray()
}

function Get-PcHttpSslBindings {
    $result=Invoke-PcNetshHttp @('http','show','sslcert')
    if($result.ExitCode -ne 0){throw ('netsh http show sslcert failed: '+($result.Output -join ' '))}
    $bindings=@(ConvertFrom-PcHttpSslBindingText $result.Output)
    if(-not $bindings.Count){return [pscustomobject]@{Status='INFO';Binding='None found';Finding='No parseable HTTP.sys SSL bindings were returned.';Detail=($result.Output -join "`n")}}
    foreach($binding in $bindings){
        $status='PASS';$finding='Binding certificate found.';$certificate=$null
        if(-not $binding.CertificateHash){$status='WARN';$finding='Binding has no certificate hash.'}
        else{
            $store=if($binding.CertificateStore){$binding.CertificateStore}else{'My'}
            try{$certificate=Get-PcCertificateStoreItems LocalMachine $store | Where-Object {($_.Thumbprint -replace '\s','') -eq ($binding.CertificateHash -replace '\s','')} | Select-Object -First 1}catch{}
            if(-not $certificate){$status='WARN';$finding="Certificate was not found in LocalMachine\$store."}
            elseif($certificate.NotAfter -lt (Get-Date)){$status='WARN';$finding='Bound certificate is expired.'}
            elseif($certificate.NotAfter -le (Get-Date).AddDays(30)){$status='WARN';$finding='Bound certificate expires within 30 days.'}
            elseif(-not $certificate.HasPrivateKey){$status='WARN';$finding='Bound certificate has no accessible private-key association.'}
        }
        [pscustomobject]@{Status=$status;Binding=$binding.Binding;BindingType=$binding.BindingType;ApplicationId=$binding.ApplicationId;CertificateStore=$(if($binding.CertificateStore){$binding.CertificateStore}else{'My'});CertificateHash=$binding.CertificateHash;Subject=$(if($certificate){$certificate.Subject}else{$null});NotAfter=$(if($certificate){$certificate.NotAfter}else{$null});Finding=$finding;Detail=($binding.Raw -join '; ')}
    }
}

function Get-PcCertificateEventSummary {
    param([int]$Hours=168)
    $events=@(Get-PcEventRecords -LogName System -Hours $Hours -Provider Schannel -Limit 100)
    if(-not $events.Count){return [pscustomobject]@{Status='PASS';Log='System';Provider='Schannel';Count=0;Finding="No Schannel events were found in the last $Hours hours.";Detail='Event logging level and log retention affect this result.'}}
    [pscustomobject]@{Status='REVIEW';Log='System';Provider='Schannel';Count=$events.Count;Finding="Schannel events found in the last $Hours hours.";Recent=($events | Select-Object -First 5 | ForEach-Object {"$($_.Time): $($_.Id) $($_.Message)"}) -join "`n";Detail='Historical events are evidence to inspect, not proof of a current fault.'}
}

function Get-PcCertificateReadiness {
    $rows=New-Object 'Collections.Generic.List[object]'
    $certificates=@(Get-PcCertificateInventory)
    $attention=@($certificates | Where-Object Status -in @('WARN','REVIEW','UNAVAILABLE'))
    $rows.Add([pscustomobject]@{Status=$(if(@($certificates|Where-Object Status -eq 'WARN').Count){'WARN'}elseif($attention.Count){'REVIEW'}else{'PASS'});Check='Local certificate metadata';Finding=$(if($attention.Count){"$($attention.Count) certificate/store findings need review."}else{"$($certificates.Count) certificates checked; no metadata finding."});Detail=($attention | Select-Object -First 10 | ForEach-Object {"$($_.Location)\$($_.Store) $($_.Subject): $($_.Finding)"}) -join "`n"})
    try{
        $bindings=@(Get-PcHttpSslBindings);$bindingAttention=@($bindings|Where-Object Status -in @('WARN','REVIEW','UNAVAILABLE'))
        $rows.Add([pscustomobject]@{Status=$(if(@($bindings|Where-Object Status -eq 'WARN').Count){'WARN'}elseif($bindingAttention.Count){'REVIEW'}else{'PASS'});Check='HTTP.sys SSL bindings';Finding=$(if($bindingAttention.Count){"$($bindingAttention.Count) binding findings need review."}else{"$($bindings.Count) binding results checked."});Detail=($bindingAttention|ForEach-Object{"$($_.Binding): $($_.Finding)"}) -join "`n"})
    }catch{$rows.Add([pscustomobject]@{Status='UNAVAILABLE';Check='HTTP.sys SSL bindings';Finding=$_.Exception.Message;Detail='The readiness check continued.'})}
    try{$rows.Add((Get-PcCertificateEventSummary))}catch{$rows.Add([pscustomobject]@{Status='UNAVAILABLE';Check='Recent Schannel events';Finding=$_.Exception.Message;Detail='The readiness check continued.'})}
    $rows.ToArray()
}

function Get-PcCertificateChecks {
    @(
        [pscustomobject]@{Key='1';Id='cert-inventory';Name='Local certificate health';MinPS='5.0';Commands=@('Get-ChildItem');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateInventory}}
        [pscustomobject]@{Key='2';Id='tls-endpoint';Name='Remote TLS endpoint test';MinPS='5.0';Commands=@();Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Invoke-PcTlsEndpointPrompt}}
        [pscustomobject]@{Key='3';Id='cert-chain';Name='Certificate chain validator';MinPS='5.0';Commands=@('Get-ChildItem');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Invoke-PcCertificateChainPrompt}}
        [pscustomobject]@{Key='4';Id='http-ssl-bindings';Name='HTTP.sys SSL binding audit';MinPS='5.0';Commands=@('netsh.exe');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcHttpSslBindings}}
        [pscustomobject]@{Key='5';Id='cert-readiness';Name='Certificate readiness summary';MinPS='5.0';Commands=@('Get-ChildItem','netsh.exe','Get-WinEvent');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateReadiness}}
        [pscustomobject]@{Key='6';Id='schannel-summary';Name='Recent Schannel event summary';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$false;ConfirmRun=$false;Action={Get-PcCertificateEventSummary}}
        [pscustomobject]@{Key='7';Id='capi2-events';Name='CAPI2 certificate event browser';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CAPI2/Operational'}}
        [pscustomobject]@{Key='8';Id='cert-lifecycle-system';Name='Machine certificate lifecycle events';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CertificateServicesClient-Lifecycle-System/Operational'}}
        [pscustomobject]@{Key='9';Id='cert-lifecycle-user';Name='User certificate lifecycle events';MinPS='5.0';Commands=@('Get-WinEvent');Admin=$false;OpenMenu=$true;ConfirmRun=$false;Action={Start-PcEventBrowser 'Microsoft-Windows-CertificateServicesClient-Lifecycle-User/Operational'}}
    )
}

function Start-PcCertificateMenu { Start-PcDiagnosticMenu 'Windows > Certificates and TLS' @(Get-PcCertificateChecks) }
