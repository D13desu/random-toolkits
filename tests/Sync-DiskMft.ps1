$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1'
$source=Get-Content -LiteralPath $path -Raw
$mft=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../win/disk/MftScanner.cs') -Raw
$start='// BEGIN EMBEDDED MFT SCANNER'
$end='// END EMBEDDED MFT SCANNER'
$a=$source.IndexOf($start); $b=$source.IndexOf($end)
if ($a -lt 0 -or $b -lt $a) { throw 'Embedded source markers missing' }
$source=$source.Substring(0,$a)+$start+"`r`n"+$mft.TrimEnd()+"`r`n"+$source.Substring($b)
[IO.File]::WriteAllText($path,$source.Replace("`r`n","`n"),[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $path -Destination (Join-Path $PSScriptRoot '../win/disk/index.html')
