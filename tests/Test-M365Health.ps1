$ErrorActionPreference='Stop'
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message};Write-Output "PASS: $Message"}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '../m365/M365-Toolkit.ps1'),[ref]$tokens,[ref]$errors)
Assert (-not $errors.Count) 'Toolkit parses successfully'
foreach($name in @('Get-M365HealthState','Get-M365HealthSnapshot','Get-GraphPaged')){
 $node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
 . ([scriptblock]::Create($node.Extent.Text))
}
function Graph-Ready {}
function Get-MgContext {[pscustomobject]@{Scopes=@('ServiceHealth.Read.All');TenantId='test-tenant'}}
$script:FailOverview=$false;$script:FailIssues=$false;$script:NoIssues=$false;$script:Status='serviceOperational';$script:PageCalls=0
function Get-GraphRaw($uri){
 $script:PageCalls++
 if($uri -like '*healthOverviews*'){
  if($script:FailOverview){throw '403 Forbidden'}
  return (@{value=@(@{id='exchange';service='Exchange Online';status=$script:Status});'@odata.nextLink'='https://graph.microsoft.com/test-next'} | ConvertTo-Json)
 }
 if($uri -like '*test-next'){return '{"value":[{"id":"teams","service":"Microsoft Teams","status":"serviceOperational"}]}'}
 if($script:FailIssues){throw '503 unavailable'}
 if($script:NoIssues){return '{"value":[]}'}
 return '{"value":[{"id":"resolved","isResolved":true},{"id":"active","isResolved":false,"service":"Exchange Online"}]}'
}
$snapshot=Get-M365HealthSnapshot
Assert ($snapshot.Services.Count -eq 2 -and $script:PageCalls -eq 3) 'All service pages and issues are fetched'
Assert ($snapshot.ActiveIssues.Count -eq 1 -and $snapshot.ActiveIssues[0].id -eq 'active') 'Resolved incidents are excluded'
Assert ($snapshot.Overall -eq 'Attention required') 'Active incident prevents all-clear even with operational services'
$script:NoIssues=$true
Assert ((Get-M365HealthSnapshot).Overall -eq 'All reported services operational') 'Complete operational snapshot without active issues reports healthy'
$script:NoIssues=$false
$script:Status='serviceInterruption'
Assert ((Get-M365HealthSnapshot).Overall -eq 'Service interruption') 'Interruption determines overall severity'
$script:Status='futureUnknownValue'
Assert ((Get-M365HealthSnapshot).Overall -eq 'Unknown / incomplete') 'Unrecognized status never becomes healthy'
$script:Status='serviceOperational';$script:FailIssues=$true
$snapshot=Get-M365HealthSnapshot
Assert ($snapshot.Overall -eq 'Unknown / incomplete' -and $snapshot.Services.Count -eq 2 -and $snapshot.Errors.Count -eq 1) 'Incident request failure retains services and marks overall incomplete'
$script:FailIssues=$false;$script:FailOverview=$true
$snapshot=Get-M365HealthSnapshot
Assert ($snapshot.Services.Count -eq 0 -and $snapshot.Overall -eq 'Unknown / incomplete') 'Refresh failure does not reuse old healthy services'
function Get-MgContext {[pscustomobject]@{Scopes=@();TenantId='test-tenant'}}
$before=$script:PageCalls;$caught=$false
try{Get-M365HealthSnapshot}catch{$caught=$_.Exception.Message -like '*ServiceHealth.Read.All*'}
Assert ($caught -and $before -eq $script:PageCalls) 'Missing scope fails before any health requests'
