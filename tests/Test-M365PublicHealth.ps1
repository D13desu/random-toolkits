$ErrorActionPreference='Stop'
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message};Write-Output "PASS: $Message"}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '../m365/M365-Toolkit.ps1'),[ref]$tokens,[ref]$errors)
Assert (-not $errors.Count) 'Toolkit parses successfully'
foreach($name in @('Convert-M365PublicText','ConvertFrom-M365PublicFeed','Get-M365PublicHealthSnapshot')){
 $node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
 . ([scriptblock]::Create($node.Extent.Text))
}
# Neither authentication nor Graph functions are loaded: this path must be independent.
$script:Content=@'
<?xml version="1.0"?><rss version="2.0"><channel><title>Microsoft Admin Center Status</title>
<item><title>Microsoft 365</title><status>Available</status><pubDate>Sun, 15 Nov 2026 09:58:00 Z</pubDate><description>&lt;div&gt;Status &amp;amp; details&lt;/div&gt;</description><link>https://status.cloud.microsoft/</link></item>
<item><title>Update</title><status>Service degradation</status><description>Investigating</description></item>
</channel></rss>
'@
$script:Fail=$false
function Invoke-WebRequest {
 param($Uri,$TimeoutSec,$MaximumRetryCount,$ErrorAction)
 Assert ($Uri -eq 'https://status.cloud.microsoft/api/feed/mac' -and $TimeoutSec -eq 30 -and $MaximumRetryCount -eq 0) 'Fetch uses official feed and bounded timeout' | Out-Host
 if($script:Fail){throw 'Network unavailable'}
 [pscustomobject]@{Content=$script:Content}
}
$snapshot=Get-M365PublicHealthSnapshot
Assert ($snapshot.Items.Count -eq 2 -and -not $snapshot.Error) 'Public RSS parsed without a Graph session'
Assert ($snapshot.Items[0].Status -eq 'Available' -and $snapshot.Items[1].Status -eq 'Service degradation') 'Source statuses preserved without inferring worldwide health'
Assert ($snapshot.Items[0].Description -eq 'Status & details') 'HTML rendered as readable text'
Assert ($snapshot.Items[0].Published -like 'Sun,*' -and $snapshot.FetchedAtUtc -and $snapshot.Source) 'Source publication and retrieval metadata retained'
$script:Content='<rss><channel/></rss>'
$snapshot=Get-M365PublicHealthSnapshot
Assert ($snapshot.Items.Count -eq 0 -and -not $snapshot.Error) 'Empty feed remains an empty result'
$script:Content='<html>Unexpected response</html>'
Assert ((Get-M365PublicHealthSnapshot).Error -like '*RSS channel missing*') 'Non-RSS response is a failure'
$script:Content='<!DOCTYPE rss [<!ENTITY external SYSTEM "file:///etc/hostname">]><rss><channel><item><title>&external;</title></item></channel></rss>'
Assert ([bool](Get-M365PublicHealthSnapshot).Error) 'DTD and external entities are rejected'
$script:Fail=$true
$snapshot=Get-M365PublicHealthSnapshot
Assert ($snapshot.Error -like '*Network unavailable*' -and $snapshot.Items.Count -eq 0) 'Failed refresh reports error without keeping prior entries'
Assert ((Convert-M365PublicText "Text$([char]27)[31m$([char]0)end") -notmatch '[\x00-\x1f\x7f-\x9f]') 'Feed text cannot inject terminal control characters'
