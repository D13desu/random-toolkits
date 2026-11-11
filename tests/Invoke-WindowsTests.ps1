[CmdletBinding()]
param(
    [ValidateSet('Safe','Live','Artifact','All')]
    [string]$Suite = 'Safe',
    [string]$PackagePath,
    [string]$ReportDirectory,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$safeTests = @(
    'Test-AdminTools.ps1'
    'Test-AdToolkit.ps1'
    'Test-CertificateTls.ps1'
    'Test-DiscoveryOui.ps1'
    'Test-DiskUsage.ps1'
    'Test-EventLogMenu.ps1'
    'Test-EventPreviews.ps1'
    'Test-HealthDashboard.ps1'
    'Test-MenuEngine.ps1'
    'Test-MenuMigration.ps1'
    'Test-MftScanner.ps1'
    'Test-NetworkConnections.ps1'
    'Test-NetworkDiscovery.ps1'
    'Test-NetworkMenus.ps1'
    'Test-NetworkRepairs.ps1'
    'Test-PowerToolkit.ps1'
    'Test-RegistryTweaks.ps1'
    'Test-SecurityUpdates.ps1'
    'Test-SqlSnippets.ps1'
    'Test-StartupTasks.ps1'
    'Test-SysinternalsLauncher.ps1'
    'Test-SystemMaintenance.ps1'
    'Test-ToolkitCleanup.ps1'
    'Test-WindowsToolkit.ps1'
)

$liveTests = @(
    'Test-MftAllocationLive.ps1'
    'Test-MftLive.ps1'
    'Test-MftWofLive.ps1'
)

$artifactTests = @(
    'Test-DiskHelperLauncher.ps1'
)

$nonWindowsTests = @(
    'Test-M365MenuEngine.ps1'
)

$classifiedTests = @($safeTests + $liveTests + $artifactTests)
$duplicates = @($classifiedTests | Group-Object | Where-Object { $_.Count -gt 1 })
if ($duplicates.Count) {
    throw "Tests are assigned to more than one Windows suite: $(($duplicates.Name) -join ', ')"
}

$testFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-*.ps1' -File | ForEach-Object { $_.Name })
$unclassified = @($testFiles | Where-Object { $_ -notin $classifiedTests -and $_ -notin $nonWindowsTests })
$missing = @($classifiedTests | Where-Object { $_ -notin $testFiles })
if ($unclassified.Count) {
    throw "Windows tests need a Safe, Live, or Artifact suite assignment: $($unclassified -join ', ')"
}
if ($missing.Count) {
    throw "Configured Windows tests are missing: $($missing -join ', ')"
}

$selectedTests = switch ($Suite) {
    'Safe' { $safeTests }
    'Live' { $liveTests }
    'Artifact' { $artifactTests }
    'All' { $safeTests + $liveTests + $artifactTests }
}

if ($List) {
    $selectedTests | ForEach-Object { Write-Output $_ }
    return
}

if ($Suite -in @('Artifact','All')) {
    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        throw '-PackagePath is required for the Artifact and All suites.'
    }
    $PackagePath = [IO.Path]::GetFullPath($PackagePath)
    if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
        throw "Disk-helper package not found: $PackagePath"
    }
}

if ($Suite -in @('Live','All')) {
    if ([string]::IsNullOrWhiteSpace($ReportDirectory)) {
        $ReportDirectory = Join-Path $env:TEMP 'random-toolkits-test-reports'
    }
    $ReportDirectory = [IO.Path]::GetFullPath($ReportDirectory)
    $null = New-Item -ItemType Directory -Path $ReportDirectory -Force
    Write-Host "Live-test reports: $ReportDirectory" -ForegroundColor Yellow
}

$engine = (Get-Process -Id $PID).Path
$results = New-Object 'Collections.Generic.List[object]'

foreach ($testName in $selectedTests) {
    $testPath = Join-Path $PSScriptRoot $testName
    if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
        throw "Configured test does not exist: $testPath"
    }

    Write-Host "`n=== $testName ===" -ForegroundColor Cyan
    $arguments = @('-NoLogo','-NoProfile','-File',$testPath)
    if ($testName -eq 'Test-DiskHelperLauncher.ps1') {
        $arguments += @('-PackagePath',$PackagePath)
    }
    if ($testName -eq 'Test-MftAllocationLive.ps1') {
        $arguments += @('-ReportPath',(Join-Path $ReportDirectory 'mft-allocation.json'))
    }
    if ($testName -eq 'Test-MftWofLive.ps1') {
        $arguments += @('-ReportPath',(Join-Path $ReportDirectory 'mft-wof.json'))
    }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    & $engine @arguments
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()

    $results.Add([pscustomobject]@{
        Test = $testName
        Passed = ($exitCode -eq 0)
        ExitCode = $exitCode
        Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds,2)
    })
}

Write-Host "`nWindows $Suite test summary" -ForegroundColor Cyan
$results | Format-Table Test,Passed,ExitCode,Seconds -AutoSize

$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count) {
    throw "$($failed.Count) of $($results.Count) Windows $Suite tests failed: $(($failed.Test) -join ', ')"
}

Write-Output "All $($results.Count) Windows $Suite tests passed on PowerShell $($PSVersionTable.PSVersion)."
