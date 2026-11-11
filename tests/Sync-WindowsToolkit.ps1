$ErrorActionPreference='Stop'

$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$launcher=Join-Path $repoRoot 'win/Windows-Toolkit.ps1'
$endpointPath=Join-Path $repoRoot 'win/index.html'
$versionFile=Join-Path $repoRoot 'win/VERSION'
$toolkitVersion=(Get-Content -LiteralPath $versionFile -Raw).Trim()

if($toolkitVersion -notmatch '^\d+\.\d+\.\d+$'){
    throw "Invalid Windows Toolkit version: $toolkitVersion"
}

$utf8NoBom=[Text.UTF8Encoding]::new($false)

function Set-PcFileContent {
    param([string]$Path,[string]$Content)
    if(-not [IO.File]::Exists($Path) -or [IO.File]::ReadAllText($Path) -cne $Content){
        [IO.File]::WriteAllText($Path,$Content,$utf8NoBom)
    }
}

# Repair the previous build's misplaced version declaration BEFORE the
# individual sync scripts parse or validate Windows-Toolkit.ps1.
# Remove only a standalone generated declaration, not menu-module defaults.
$declarationPattern='(?m)^[ \t]*\$script:PcToolkitVersion[ \t]*=[^\r\n]*(?:\r?\n)?'
foreach($path in @($launcher,$endpointPath)){
    if([IO.File]::Exists($path)){
        $original=[IO.File]::ReadAllText($path)
        $clean=[regex]::Replace($original,$declarationPattern,'')
        Set-PcFileContent -Path $path -Content $clean
    }
}

$syncScripts=@(
    'Sync-DiskMft.ps1'
    'Sync-NetworkDiscovery.ps1'
    'Sync-NetworkConnections.ps1'
    'Sync-ToolkitCleanup.ps1'
    'Sync-HealthDashboard.ps1'
    'Sync-CertificateTls.ps1'
    'Sync-StartupTasks.ps1'
    'Sync-SystemMaintenance.ps1'
    'Sync-SysinternalsLauncher.ps1'
    'Sync-MenuEngine.ps1'
    'Sync-SqlSnippets.ps1'
    'Sync-RegistryTweaks.ps1'
)

foreach($syncScript in $syncScripts){
    & (Join-Path $PSScriptRoot $syncScript)
}

$content=[IO.File]::ReadAllText($launcher)
$content=[regex]::Replace($content,$declarationPattern,'')

$versionHeader="# Random Toolkits | Windows Toolkit $toolkitVersion"
$headerPattern='\A# Random Toolkits \| Windows Toolkit [^\r\n]+'
if(-not [regex]::IsMatch($content,$headerPattern)){
    throw 'Windows Toolkit version header not found.'
}
$content=[regex]::Replace($content,$headerPattern,$versionHeader)

# Parse the script to find the actual END of its script-level param() block.
# An executable assignment before [CmdletBinding()] / param() breaks parsing.
$tokens=$null
$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput(
    $content,[ref]$tokens,[ref]$parseErrors
)
if($parseErrors.Count){
    throw "Windows toolkit has parse errors before version injection: $($parseErrors[0].Message)"
}
if($null -eq $ast.ParamBlock){
    throw 'Windows Toolkit script-level param() block not found.'
}

$newline=if($content.Contains("`r`n")){"`r`n"}else{"`n"}
$versionDeclaration='$script:PcToolkitVersion=' + "'$toolkitVersion'"
$content=$content.Insert($ast.ParamBlock.Extent.EndOffset,$newline+$versionDeclaration)

# Verify the final generated launcher parses before publishing it.
$tokens=$null
$parseErrors=$null
$null=[System.Management.Automation.Language.Parser]::ParseInput(
    $content,[ref]$tokens,[ref]$parseErrors
)
if($parseErrors.Count){
    throw "Windows toolkit has parse errors after version injection: $($parseErrors[0].Message)"
}

Set-PcFileContent -Path $launcher -Content $content
Set-PcFileContent -Path $endpointPath -Content $content

$launcherHash=(Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
if((Get-FileHash -LiteralPath $endpointPath -Algorithm SHA256).Hash -ne $launcherHash){
    throw 'win/index.html does not match Windows-Toolkit.ps1 after synchronization.'
}

$diskSource=Join-Path $repoRoot 'win/disk/Disk-Usage.ps1'
$diskEndpoint=Join-Path $repoRoot 'win/disk/index.html'
if((Get-FileHash -LiteralPath $diskSource -Algorithm SHA256).Hash -ne
   (Get-FileHash -LiteralPath $diskEndpoint -Algorithm SHA256).Hash){
    throw 'win/disk/index.html does not match Disk-Usage.ps1 after synchronization.'
}

Write-Output "Windows Toolkit $toolkitVersion synchronized successfully."
