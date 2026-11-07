$ErrorActionPreference='Stop'
$path=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1'))
$source=[IO.File]::ReadAllText($path);$start='# BEGIN SYSINTERNALS LAUNCHER';$end='# END SYSINTERNALS LAUNCHER'
$a=$source.IndexOf($start);$b=$source.IndexOf($end)
if($a -lt 0 -or $b -le $a){throw 'Sysinternals launcher markers missing'}
$modulePath=Join-Path $PSScriptRoot '../win/modules/Sysinternals-Launcher.ps1'
$tokens=$null;$errors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($modulePath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw "Sysinternals launcher has PowerShell parse errors:`n$($errors -join "`n")"}
$module=[IO.File]::ReadAllText($modulePath)
$source=$source.Substring(0,$a)+$start+"`r`n"+$module.TrimEnd()+"`r`n"+$source.Substring($b)
$launcherTokens=$null;$launcherErrors=$null
$null=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$launcherTokens,[ref]$launcherErrors)
if($launcherErrors.Count){throw "Generated Windows toolkit has PowerShell parse errors:`n$($launcherErrors -join "`n")"}
[IO.File]::WriteAllText($path,$source,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $path -Destination (Join-Path $PSScriptRoot '../win/index.html')
