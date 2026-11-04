# Run using PowerShell 7.4+; installs modules only for the current user.
# No tenant settings or accounts are modified.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'PowerShell 7.4+ required' }
$names = @('Microsoft.Graph.Authentication','Microsoft.Graph.Users','Microsoft.Graph.Reports','ExchangeOnlineManagement')
foreach ($name in $names) {
 if (Get-Module -ListAvailable -Name $name) {
  Write-Host "Already installed: $name"
 } else {
  Write-Host "Installing: $name"
  Install-Module -Name $name -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
 }
}
Write-Host 'Dependency check complete.'
