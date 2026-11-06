# Random Toolkits | M365 launcher 1.0.0
# Safe to invoke from a local file or through Invoke-RestMethod | Invoke-Expression.
& {
    $ErrorActionPreference = 'Stop'
    if ($PSVersionTable.PSVersion -lt [version]'7.4') {
        throw 'PowerShell 7.4+ is required. Open pwsh and run the launcher again.'
    }

    $expectedHash = '5C4BB3E5F1D02618F82B08E6211C1ABA7B2067E3AAD0AF926369FA351EC2CB74'
    $uri = 'https://tools.d0xd.com/m365/M365-Toolkit.ps1'
    $dataRoot = [Environment]::GetFolderPath('LocalApplicationData')
    if (-not $dataRoot) { $dataRoot = Join-Path $HOME '.local/share' }
    $directory = Join-Path $dataRoot 'Random-Toolkits/m365/0.4.0'
    $null = New-Item -ItemType Directory -Path $directory -Force
    $scriptPath = Join-Path $directory 'M365-Toolkit.ps1'
    $downloadPath = Join-Path $directory ('.download-' + [guid]::NewGuid().ToString('N') + '.ps1')

    try {
        Write-Host 'Downloading M365 Toolkit v0.4.0 from D13desu/random-toolkits...'
        Invoke-WebRequest -Uri $uri -OutFile $downloadPath -TimeoutSec 60
        if ((Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'Toolkit checksum mismatch. The downloaded script will not be executed.'
        }
        Move-Item -LiteralPath $downloadPath -Destination $scriptPath -Force
    } finally {
        if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force }
    }

    $modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Reports', 'ExchangeOnlineManagement')
    $missing = @($modules | Where-Object { -not (Get-Module -ListAvailable -Name $_) })
    if ($missing.Count) {
        Write-Host ('Missing PowerShell modules: ' + ($missing -join ', '))
        if ((Read-Host 'Install these modules from PSGallery for the current user? [y/N]') -notmatch '^(y|yes)$') {
            throw 'Required modules are missing. Run Install-Dependencies.ps1, then retry.'
        }
        foreach ($module in $missing) {
            Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
        }
    }

    Write-Host "Toolkit: $scriptPath"
    Write-Host ('Reports: ' + (Join-Path $directory 'reports'))
    & $scriptPath
}
