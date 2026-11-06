$ErrorActionPreference='Stop'

$source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../m365/Launch-M365.ps1'))
$endpoint=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../m365/index.html'))
$toolkit=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../m365/M365-Toolkit.ps1'))
$menuEngine=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../m365/Menu-Engine.ps1'))

$menuTokens=$null
$menuParseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($menuEngine,[ref]$menuTokens,[ref]$menuParseErrors)
if($menuParseErrors.Count){
    throw "M365 menu engine has PowerShell parse errors:`n$($menuParseErrors -join "`n")"
}

$toolkitSource=[IO.File]::ReadAllText($toolkit)
$menuStart='# BEGIN M365 MENU ENGINE'
$menuEnd='# END M365 MENU ENGINE'
$startIndex=$toolkitSource.IndexOf($menuStart)
$endIndex=$toolkitSource.IndexOf($menuEnd)
if($startIndex -lt 0 -or $endIndex -le $startIndex){throw 'M365 menu engine markers are missing.'}
$menuSource=[IO.File]::ReadAllText($menuEngine).TrimEnd()
$toolkitSource=$toolkitSource.Substring(0,$startIndex)+$menuStart+"`r`n"+$menuSource+"`r`n"+$toolkitSource.Substring($endIndex)
[IO.File]::WriteAllText($toolkit,$toolkitSource,[Text.UTF8Encoding]::new($false))

$toolkitTokens=$null
$toolkitParseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($toolkit,[ref]$toolkitTokens,[ref]$toolkitParseErrors)
if($toolkitParseErrors.Count){
    throw "M365 toolkit has PowerShell parse errors:`n$($toolkitParseErrors -join "`n")"
}

$toolkitHash=(Get-FileHash -LiteralPath $toolkit -Algorithm SHA256).Hash
$launcher=[IO.File]::ReadAllText($source)
$hashPattern="(?m)^(?<prefix>\s*\`$expectedHash\s*=\s*')[A-Fa-f0-9]{64}(?<suffix>'.*)$"
$hashMatches=[regex]::Matches($launcher,$hashPattern)
if($hashMatches.Count -ne 1){throw 'Expected exactly one M365 launcher checksum assignment.'}
$launcher=[regex]::Replace($launcher,$hashPattern,{param($match) $match.Groups['prefix'].Value+$toolkitHash+$match.Groups['suffix'].Value})
[IO.File]::WriteAllText($source,$launcher,[Text.UTF8Encoding]::new($false))

$tokens=$null
$parseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){
    throw "M365 launcher has PowerShell parse errors:`n$($parseErrors -join "`n")"
}

Copy-Item -LiteralPath $source -Destination $endpoint -Force
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $endpoint -Algorithm SHA256).Hash){
    throw 'm365/index.html does not match Launch-M365.ps1 after synchronization.'
}

Write-Output 'M365 launcher and published endpoint are synchronized.'
