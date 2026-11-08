$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/modules/Certificate-Tls.ps1')
function Assert($Condition,[string]$Message){if(-not $Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}

function New-FixtureCertificate {
    param([datetime]$NotAfter=(Get-Date).AddDays(90),[bool]$HasPrivateKey=$true,[string]$Signature='sha256RSA',[int]$KeySize=2048,[string]$Subject='CN=fixture.example.test',[string]$Issuer='CN=Fixture CA')
    $certificate=[pscustomobject]@{
        NotBefore=(Get-Date).AddDays(-30);NotAfter=$NotAfter;HasPrivateKey=$HasPrivateKey;Subject=$Subject;Issuer=$Issuer
        Thumbprint='00112233445566778899AABBCCDDEEFF00112233';SignatureAlgorithm=[pscustomobject]@{FriendlyName=$Signature}
        PublicKey=[pscustomobject]@{Oid=[pscustomobject]@{FriendlyName='RSA'};Key=[pscustomobject]@{KeySize=$KeySize}}
        Extensions=@();DnsNameList=@([pscustomobject]@{Unicode='fixture.example.test'})
    }
    $certificate|Add-Member ScriptMethod GetNameInfo {param($type,$forIssuer)'fixture.example.test'}
    $certificate
}

$healthy=Get-PcCertificateAssessment (New-FixtureCertificate) LocalMachine My 30
Assert ($healthy.Status -eq 'PASS' -and $healthy.DnsNames -eq 'fixture.example.test' -and $healthy.KeySize -eq 2048) 'Healthy certificate metadata passes with DNS and key details'
$expiring=Get-PcCertificateAssessment (New-FixtureCertificate -NotAfter (Get-Date).AddDays(5)) LocalMachine My 30
Assert ($expiring.Status -eq 'WARN' -and $expiring.Finding -match 'Expires within 30 days') 'Soon-expiring certificate is actionable'
$legacy=Get-PcCertificateAssessment (New-FixtureCertificate -Signature sha1RSA -KeySize 1024 -HasPrivateKey $false) LocalMachine My 30
Assert ($legacy.Status -eq 'REVIEW' -and $legacy.Finding -match 'Legacy signature' -and $legacy.Finding -match 'No private key') 'Legacy algorithms and missing private keys are reported without mutation'
$selfSigned=Get-PcCertificateAssessment (New-FixtureCertificate -Subject 'CN=self' -Issuer 'CN=self') CurrentUser My 30
Assert ($selfSigned.Status -eq 'REVIEW' -and $selfSigned.Finding -match 'Self-signed') 'Self-signed leaf-store certificates are marked for review'

$fixtureLines=@(
    'SSL Certificate bindings:'
    '-------------------------'
    '    IP:port                      : 0.0.0.0:443'
    '    Certificate Hash             : 00112233445566778899AABBCCDDEEFF00112233'
    '    Application ID               : {00112233-4455-6677-8899-aabbccddeeff}'
    '    Certificate Store Name        : MY'
    '    Verify Client Certificate Revocation : Enabled'
    ''
    '    Hostname:port                : api.example.test:8443'
    '    Certificate Hash             : AABB'
    '    Application ID               : {11112233-4455-6677-8899-aabbccddeeff}'
    '    Certificate Store Name        : WebHosting'
)
$parsed=@(ConvertFrom-PcHttpSslBindingText $fixtureLines)
Assert ($parsed.Count -eq 2 -and $parsed[0].Binding -eq '0.0.0.0:443' -and $parsed[1].CertificateStore -eq 'WebHosting') 'HTTP.sys text parser separates IP and SNI bindings'

function Invoke-PcNetshHttp {[pscustomobject]@{ExitCode=0;Output=$fixtureLines}}
function Get-PcCertificateStoreItems {
    param($Location,$Store)
    if($Store -ieq 'MY'){New-FixtureCertificate}
}
$bindings=@(Get-PcHttpSslBindings)
Assert ($bindings.Count -eq 2 -and $bindings[0].Status -eq 'PASS' -and $bindings[1].Status -eq 'WARN') 'Binding audit correlates hashes and reports a missing certificate'

function Get-PcCertificateInventory {@([pscustomobject]@{Status='WARN';Location='LocalMachine';Store='My';Subject='CN=expiring';Finding='Expires soon'})}
function Get-PcHttpSslBindings {@([pscustomobject]@{Status='PASS';Binding='0.0.0.0:443';Finding='Binding certificate found.'})}
function Get-PcCertificateEventSummary {[pscustomobject]@{Status='PASS';Check='Recent Schannel events';Finding='No recent events.';Detail='Fixture'}}
$readiness=@(Get-PcCertificateReadiness)
Assert ($readiness.Count -eq 3 -and $readiness[0].Status -eq 'WARN' -and $readiness[1].Status -eq 'PASS') 'Readiness summary keeps certificate, binding, and event findings independent'

$ids=@((Get-PcCertificateChecks).Id)
$expected=@('cert-inventory','tls-endpoint','cert-chain','http-ssl-bindings','cert-readiness','schannel-summary','capi2-events','cert-lifecycle-system','cert-lifecycle-user')
Assert (@($expected|Where-Object{$_ -notin $ids}).Count -eq 0) 'All certificate and TLS tools are registered'
Assert (@((Get-PcCertificateChecks)|Where-Object{$_.Id -in @('capi2-events','cert-lifecycle-system','cert-lifecycle-user') -and $_.OpenMenu}).Count -eq 3) 'Event tools open the shared event browser'

$source=Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$embedded=($source -split '# BEGIN CERTIFICATE AND TLS DIAGNOSTICS',2)[1] -split '# END CERTIFICATE AND TLS DIAGNOSTICS',2
$module=Get-Content (Join-Path $PSScriptRoot '../win/modules/Certificate-Tls.ps1') -Raw
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq $module.Replace("`r`n","`n").Trim()) 'Embedded certificate diagnostics match the maintained module'
Assert ($source -match "New-PcMenuItem '16' 'Certificates and TLS'" -and $source -match "'16' \{ Start-PcCertificateMenu \}") 'Certificates and TLS is reachable from the main menu'

Write-Output "Certificate and TLS tests passed on PowerShell $($PSVersionTable.PSVersion)."
