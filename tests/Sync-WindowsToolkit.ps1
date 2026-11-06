$ErrorActionPreference='Stop'

$syncScripts=@(
    'Sync-DiskMft.ps1'
    'Sync-NetworkDiscovery.ps1'
    'Sync-NetworkConnections.ps1'
    'Sync-ToolkitCleanup.ps1'
    'Sync-HealthDashboard.ps1'
    'Sync-StartupTasks.ps1'
    'Sync-SystemMaintenance.ps1'
    'Sync-SysinternalsLauncher.ps1'
    'Sync-MenuEngine.ps1'
    'Sync-RegistryTweaks.ps1'
)

foreach($syncScript in $syncScripts){
    & (Join-Path $PSScriptRoot $syncScript)
}

$launcher=Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1'
$launcherHash=(Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
foreach($endpoint in @('../win/index.html','../win/net/index.html')){
    $endpointPath=Join-Path $PSScriptRoot $endpoint
    if((Get-FileHash -LiteralPath $endpointPath -Algorithm SHA256).Hash -ne $launcherHash){
        throw "$endpoint does not match Network-Toolkit.ps1 after synchronization."
    }
}

$diskSource=Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1'
$diskEndpoint=Join-Path $PSScriptRoot '../win/disk/index.html'
if((Get-FileHash -LiteralPath $diskSource -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $diskEndpoint -Algorithm SHA256).Hash){
    throw 'win/disk/index.html does not match Disk-Usage.ps1 after synchronization.'
}

Write-Output 'Windows toolkit modules and published endpoints are synchronized.'
