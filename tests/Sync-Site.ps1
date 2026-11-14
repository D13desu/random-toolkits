$ErrorActionPreference='Stop'

& (Join-Path $PSScriptRoot 'Sync-WindowsToolkit.ps1')
& (Join-Path $PSScriptRoot 'Sync-M365.ps1')
& (Join-Path $PSScriptRoot 'Sync-LinuxToolkit.ps1')

Write-Output 'All generated site endpoints are synchronized.'
