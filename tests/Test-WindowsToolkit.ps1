$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1'
$endpoint = Join-Path $PSScriptRoot '../win/index.html'
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile((Resolve-Path $source), [ref]$tokens, [ref]$parseErrors)
Assert-True ($parseErrors.Count -eq 0) 'Source parses on this PowerShell version'
Assert-True ((Get-FileHash $source).Hash -eq (Get-FileHash $endpoint).Hash) 'Pages endpoint matches source byte-for-byte'
. $source -NoMenu
foreach ($targetValue in @('localhost','example.com','127.0.0.1','::1')) { Test-NetworkTarget $targetValue }
foreach ($targetValue in @('https://example.com','-bad','host;whoami','', 'two hosts')) {
    $rejected = $false
    try { Test-NetworkTarget $targetValue } catch { $rejected = $true }
    Assert-True $rejected "Reject invalid target: $targetValue"
}
$future = [pscustomobject]@{MinPS='7.4'; Commands=@(); Admin=$false}
$result = Get-NetworkAvailability $future -Version '5.1'
Assert-True (-not $result.Available -and $result.Reason -match 'Requires PowerShell 7.4') 'Newer tools marked unavailable on older PowerShell'
$missing = [pscustomobject]@{MinPS='5.0'; Commands=@('Missing-NetworkToolkitTestCommand'); Admin=$false}
Assert-True (-not (Get-NetworkAvailability $missing).Available) 'Missing command is marked unavailable'
# Override registry locally to confirm invocation is gated, not only the display.
$registryFunction = (Get-Item Function:Get-NetworkChecks).ScriptBlock
function Get-NetworkChecks {
    [pscustomobject]@{Id='blocked'; MinPS='99.0'; Commands=@(); Admin=$false; Action={throw 'ACTION MUST NOT RUN'}}
}
$blocked = $false
try { Invoke-NetworkCheck blocked } catch { $blocked = $_.Exception.Message -match 'Requires PowerShell 99.0' }
Assert-True $blocked 'Unsupported check cannot be executed'
Set-Item Function:Get-NetworkChecks $registryFunction

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $testPort = $listener.LocalEndpoint.Port
    $result = Test-NetworkTcp '127.0.0.1' $testPort
    Assert-True ($result.Status -eq 'PASS') 'TCP detects an open local port'
} finally { $listener.Stop() }
$result = Test-NetworkTcp '127.0.0.1' $testPort -TimeoutMs 500
Assert-True ($result.Status -eq 'WARN') 'TCP failure is a warning with details'
Assert-True (@(Get-NetworkOverview).Count -gt 0) 'Adapter overview returns structured data'
Assert-True (@(Get-NetworkDns localhost).Count -gt 0) 'Local DNS resolution works'
# Exercise the actual IEX entry point without network probes or user interaction.
# The first response proves 0 no longer quits the root; null then simulates a closed input stream.
$script:IexPromptCount=0
function Read-Host { param($Prompt) $script:IexPromptCount++;if($script:IexPromptCount -eq 1){'0'}else{$null} }
Get-Content -Raw $endpoint | Invoke-Expression
Assert-True ($script:IexPromptCount -ge 2) 'IEX root ignores 0 and only returns when its input stream closes'
Write-Host "All checks passed on PowerShell $($PSVersionTable.PSVersion)."
