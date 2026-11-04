$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
Initialize-DiskScanner
function Assert($ok,$message) { if (-not $ok) { throw "FAIL: $message" }; Write-Output "PASS: $message" }
function Put($b,$offset,$value) { $bytes=[BitConverter]::GetBytes($value); [Array]::Copy($bytes,0,$b,$offset,$bytes.Length) }
function Record([int]$id,[string]$name,[uint64]$parent,[long]$size=0,[switch]$Directory,[switch]$Resident,[int]$Flags=0,[switch]$AttributeList,[int]$NameSpace=1) {
    $b=[byte[]]::new(1024)
    Put $b 0 ([uint32]0x454c4946); Put $b 16 ([uint16]1); Put $b 20 ([uint16]56); Put $b 22 ([uint16](1+2*[int]$Directory.IsPresent))
    $p=56; $nameBytes=[Text.Encoding]::Unicode.GetBytes($name); $len=[int]([math]::Ceiling((90+$nameBytes.Length)/8)*8)
    Put $b $p ([uint32]0x30); Put $b ($p+4) ([uint32]$len); Put $b ($p+16) ([uint32](66+$nameBytes.Length)); Put $b ($p+20) ([uint16]24)
    Put $b ($p+24) $parent; $b[$p+88]=$name.Length; $b[$p+89]=$NameSpace; [Array]::Copy($nameBytes,0,$b,$p+90,$nameBytes.Length); $p+=$len
    if (-not $Directory) {
        $len=64; if ($Resident) { $len=[int]([math]::Ceiling((24+$size)/8)*8) }
        Put $b $p ([uint32]0x80); Put $b ($p+4) ([uint32]$len); Put $b ($p+12) ([uint16]$Flags)
        if ($Resident) { Put $b ($p+16) ([uint32]$size); Put $b ($p+20) ([uint16]24) }
        else { $b[$p+8]=1; Put $b ($p+32) ([uint16]64); Put $b ($p+40) ([long]4096); Put $b ($p+48) $size }
        $p+=$len
    }
    if ($AttributeList) { Put $b $p ([uint32]0x20); Put $b ($p+4) ([uint32]24); Put $b ($p+20) ([uint16]24); $p+=24 }
    Put $b $p ([uint32]::MaxValue); Put $b 24 ([uint32]($p+4))
    return ,$b
}
$rootRef=[uint64]281474976710661 # sequence 1, record 5
$dirRef=[uint64]281474976710676 # sequence 1, record 20
$root=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 5 '.' $rootRef -Directory),5)
$dir=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 20 'folder' $rootRef -Directory),20)
$residentBytes=Record 21 'small.bin' $dirRef 17 -Resident
$small=[RandomToolkits.DiskV3.MftScanner]::Parse($residentBytes,21)
$sparse=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 22 'sparse.bin' $dirRef 1000000 -Flags 0x8000),22)
$compressed=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 23 'compressed.bin' $rootRef 10000 -Flags 1),23)
Assert ($small.Bytes -eq 17 -and $sparse.Bytes -eq 1000000 -and $compressed.Bytes -eq 10000) 'Resident, sparse and compressed data use logical length, not allocation or stale filename size'
$alias=New-Object RandomToolkits.DiskV3.MftName; $alias.Parent=$rootRef; $alias.Name='alias.bin'; $small.Names.Add($alias)
$scan=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($small,$compressed,$dir,$sparse,$root),$false)
Assert ($scan.Nodes['Z:\'].Bytes -eq 1010017 -and $scan.Files -eq 3 -and $scan.IssueCount -eq 0) 'Unordered records reconstruct folders and charge each hard-linked file once'
Assert ($scan.Nodes['Z:\folder'].Bytes -eq 1000000) 'Hardlink ownership is deterministic by ordinal full path'
Assert (@(Get-DiskChildren $scan 'Z:\folder' | Where-Object Kind -eq LINK).Count -eq 1) 'Uncharged hardlink remains visible as LINK'
$short=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 24 'SHORT~1' $rootRef 5 -NameSpace 2),24)
Assert ($short.Names.Count -eq 0) 'DOS-only short names are excluded'
$extended=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 25 'extended.bin' $rootRef 50 -AttributeList),25)
$partial=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$extended),$false)
Assert ($partial.Files -eq 0 -and $partial.IssueCount -eq 1 -and $partial.Nodes['Z:\'].Partial) 'Attribute-list files are explicitly excluded instead of silently undercounted'
$stale=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 26 'stale.bin' ([uint64]562949953421332) 50),26)
$partial=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$dir,$stale),$false)
Assert ($partial.Files -eq 0 -and $partial.Nodes['Z:\folder'].Partial) 'Reused parent sequence is rejected and unresolved totals marked partial'
$dir.Reparse=$true
$partial=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$dir,$sparse),$false)
Assert ($partial.Nodes.Count -eq 1 -and $partial.Files -eq 0 -and $partial.IssueCount -gt 0) 'Reparse directories and descendants are not traversed'
$dir.Reparse=$false; $dir.Names[0].Parent=$dirRef
$partial=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$dir),$false)
Assert ($partial.Nodes.Count -eq 1 -and $partial.IssueCount -gt 0) 'Parent cycles terminate and are reported'
$dir.Names[0].Parent=$rootRef
$partial=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$dir,$small),$true)
Assert ($partial.Cancelled -and $partial.Nodes['Z:\folder'].Partial) 'Cancellation flags every cached total incomplete'
$unicode=[RandomToolkits.DiskV3.MftScanner]::Parse((Record 27 ('file-'+[char]0x00f1) $rootRef 2),27)
Assert ($unicode.Names[0].Name -eq ('file-'+[char]0x00f1)) 'Unicode names decode correctly'
$duplicates=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',@($root,$compressed,$compressed),$false)
Assert ($duplicates.Nodes['Z:\'].Bytes -eq 10000 -and $duplicates.IssueCount -gt 0) 'Concurrent duplicate paths are reported without double charging'
$longRecords=New-Object 'System.Collections.Generic.List[RandomToolkits.DiskV3.MftRecord]'
$longRecords.Add($root); $parent=$rootRef
for ($i=30; $i -lt 34; $i++) {
    $entry=[RandomToolkits.DiskV3.MftScanner]::Parse((Record $i ('directory-'+('x'*100)) $parent -Directory),$i)
    $longRecords.Add($entry); $parent=$entry.Reference
}
$longRecords.Add([RandomToolkits.DiskV3.MftScanner]::Parse((Record 34 'leaf.bin' $parent 11),34))
$longScan=[RandomToolkits.DiskV3.MftScanner]::Build('Z:\',$longRecords.ToArray(),$false)
Assert ($longScan.Nodes['Z:\'].Bytes -eq 11 -and @($longScan.Nodes.Keys | Where-Object Length -gt 260).Count -gt 0 -and $longScan.IssueCount -eq 0) 'MFT tree reconstruction supports paths beyond MAX_PATH'
Assert ((Get-DiskMftUnavailableReason '\\server\share\') -like '*local drive root*') 'Network shares are rejected before raw-volume access'
foreach ($offset in @(0,20,24,60,72,76)) {
    $bad=[byte[]]$residentBytes.Clone(); Put $bad $offset ([uint32]0x7fffffff); $rejected=$false
    try { $null=[RandomToolkits.DiskV3.MftScanner]::Parse($bad,21) } catch { $rejected=$true }
    Assert $rejected "Malformed record at offset $offset rejected"
}
$source=Get-Content (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -Raw
$embedded=($source -split '// BEGIN EMBEDDED MFT SCANNER',2)[1] -split '// END EMBEDDED MFT SCANNER',2
Assert ($embedded[0].Trim() -eq (Get-Content (Join-Path $PSScriptRoot '../win/disk/MftScanner.cs') -Raw).Trim()) 'Embedded C# matches maintained source'
# Test fallback without initiating a production drive scan.
function Get-DiskMftUnavailableReason { 'Simulated unavailable elevation or filesystem' }
function Measure-DiskTreeFallback { [pscustomobject]@{Fallback=$true} }
function Initialize-DiskScanner { throw 'Simulated compilation restriction' }
$fallback=Measure-DiskTree 'Z:\' -Engine Mft
Assert $fallback.Fallback 'Unavailable MFT and restricted compilation fall back to PowerShell'
Write-Output "MFT tests passed on PowerShell $($PSVersionTable.PSVersion)"
