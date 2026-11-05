$ErrorActionPreference='Stop'
$path=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../win/net/Network-Toolkit.ps1'))
$source=[IO.File]::ReadAllText($path);$start='# BEGIN SYSTEM MAINTENANCE';$end='# END SYSTEM MAINTENANCE'
$a=$source.IndexOf($start);$b=$source.IndexOf($end)
if($a -lt 0 -or $b -le $a){throw 'System maintenance markers missing'}
$module=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../win/net/System-Maintenance.ps1'))
$source=$source.Substring(0,$a)+$start+"`r`n"+$module.TrimEnd()+"`r`n"+$source.Substring($b)
[IO.File]::WriteAllText($path,$source,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $path -Destination (Join-Path $PSScriptRoot '../win/net/index.html')
Copy-Item -LiteralPath $path -Destination (Join-Path $PSScriptRoot '../win/index.html')

