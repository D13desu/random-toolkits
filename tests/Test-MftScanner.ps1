$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
Initialize-DiskScanner
function Assert($ok,$message) { if (-not $ok) { throw "FAIL: $message" }; Write-Output "PASS: $message" }
function Put($b,$offset,$value) { $bytes=[BitConverter]::GetBytes($value); [Array]::Copy($bytes,0,$b,$offset,$bytes.Length) }
function Record([int]$id,[string]$name,[uint64]$parent,[long]$size=0,[switch]$Directory,[switch]$Resident,[int]$Flags=0,[switch]$AttributeList,[int]$NameSpace=1,[switch]$StandardInfo,[uint32]$FileAttributes=0,[uint32]$ReparseTag=0,[uint64]$BaseReference=0,[uint16]$Links=1,[switch]$NoName,[switch]$NoData) {
    $b=[byte[]]::new(1024)
    Put $b 0 ([uint32]0x454c4946); Put $b 16 ([uint16]1); Put $b 20 ([uint16]56); Put $b 22 ([uint16](1+2*[int]$Directory.IsPresent))
    Put $b 18 $Links; Put $b 32 $BaseReference
    $p=56
    if (-not $NoName) {
    $nameBytes=[Text.Encoding]::Unicode.GetBytes($name); $len=[int]([math]::Ceiling((90+$nameBytes.Length)/8)*8)
    Put $b $p ([uint32]0x30); Put $b ($p+4) ([uint32]$len); Put $b ($p+16) ([uint32](66+$nameBytes.Length)); Put $b ($p+20) ([uint16]24)
    Put $b ($p+24) $parent; $b[$p+88]=$name.Length; $b[$p+89]=$NameSpace; [Array]::Copy($nameBytes,0,$b,$p+90,$nameBytes.Length); $p+=$len
    }
    if (-not $Directory -and -not $NoData) {
        $len=64; if ($Resident) { $len=[int]([math]::Ceiling((24+$size)/8)*8) }
        Put $b $p ([uint32]0x80); Put $b ($p+4) ([uint32]$len); Put $b ($p+12) ([uint16]$Flags)
        if ($Resident) { Put $b ($p+16) ([uint32]$size); Put $b ($p+20) ([uint16]24) }
        else { $b[$p+8]=1; Put $b ($p+32) ([uint16]64); Put $b ($p+40) ([long]4096); Put $b ($p+48) $size }
        $p+=$len
    }
    if ($StandardInfo) {
        Put $b $p ([uint32]0x10); Put $b ($p+4) ([uint32]96); Put $b ($p+16) ([uint32]72); Put $b ($p+20) ([uint16]24)
        Put $b ($p+56) $FileAttributes; $p+=96
    }
    if ($AttributeList) { Put $b $p ([uint32]0x20); Put $b ($p+4) ([uint32]24); Put $b ($p+20) ([uint16]24); $p+=24 }
    if ($ReparseTag -ne 0) { Put $b $p ([uint32]0xc0); Put $b ($p+4) ([uint32]32); Put $b ($p+16) ([uint32]8); Put $b ($p+20) ([uint16]24); Put $b ($p+24) $ReparseTag; $p+=32 }
    Put $b $p ([uint32]::MaxValue); Put $b 24 ([uint32]($p+4))
    return ,$b
}
$rootRef=[uint64]281474976710661 # sequence 1, record 5
$dirRef=[uint64]281474976710676 # sequence 1, record 20
$root=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 5 '.' $rootRef -Directory),5)
$dir=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 20 'folder' $rootRef -Directory),20)
$residentBytes=Record 21 'small.bin' $dirRef 17 -Resident
$small=[RandomToolkits.DiskV6.MftScanner]::Parse($residentBytes,21)
$sparse=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 22 'sparse.bin' $dirRef 1000000 -Flags 0x8000),22)
$compressed=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 23 'compressed.bin' $rootRef 10000 -Flags 1),23)
Assert ($small.Bytes -eq 17 -and $sparse.Bytes -eq 1000000 -and $compressed.Bytes -eq 10000) 'Resident, sparse and compressed data use logical length, not allocation or stale filename size'
$alias=New-Object RandomToolkits.DiskV6.MftName; $alias.Parent=$rootRef; $alias.Name='alias.bin'; $small.Names.Add($alias)
$scan=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($small,$compressed,$dir,$sparse,$root),$false)
Assert ($scan.Nodes['Z:\'].Bytes -eq 1010017 -and $scan.Files -eq 3 -and $scan.IssueCount -eq 0) 'Unordered records reconstruct folders and charge each hard-linked file once'
Assert ($scan.Nodes['Z:\folder'].Bytes -eq 1000000) 'Hardlink ownership is deterministic by ordinal full path'
Assert (@(Get-DiskChildren $scan 'Z:\folder' | Where-Object Kind -eq LINK).Count -eq 1) 'Uncharged hardlink remains visible as LINK'
$short=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 24 'SHORT~1' $rootRef 5 -NameSpace 2),24)
Assert ($short.Names.Count -eq 0) 'DOS-only short names are excluded'
$extended=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 25 'extended.bin' $rootRef 50 -AttributeList),25)
$partial=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$extended),$false)
Assert ($partial.Files -eq 0 -and $partial.IssueCount -eq 1 -and $partial.Nodes['Z:\'].Partial) 'Attribute-list files are explicitly excluded instead of silently undercounted'
# Reproduce the reported WindowsApps blocker: directory index extents do not
# prevent reconstructing a base filename with authoritative standard flags.
$windowsApps=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList -StandardInfo),40)
$package=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 41 'Package' $windowsApps.Reference -Directory),41)
$payload=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 42 'payload.bin' $package.Reference 4096),42)
$fixed=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($payload,$package,$windowsApps,$root),$false)
Assert ($windowsApps.HasAttributeList -and -not $windowsApps.Unsupported -and $fixed.Nodes['Z:\WindowsApps'].Bytes -eq 4096 -and $fixed.IssueCount -eq 0) 'WindowsApps-style attribute-list directory retains its entire descendant tree'
$reparseDir=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList -StandardInfo -FileAttributes 0x400),40)
$excluded=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($payload,$package,$reparseDir,$root),$false)
Assert ($reparseDir.Reparse -and $excluded.Nodes.Count -eq 1 -and $excluded.Files -eq 0 -and $excluded.MftOmittedDirectories -eq 2) 'Reparse flag in standard information excludes extension-backed directory and descendants even without a local reparse payload'
$missingFlags=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList),40)
Assert $missingFlags.Unsupported 'Attribute-list directory without authoritative base flags stays excluded'
$noBaseName=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 40 'WINDOW~1' $rootRef -Directory -AttributeList -StandardInfo -NameSpace 2),40)
Assert $noBaseName.Unsupported 'Attribute-list directory without a usable base name stays excluded'
$extentDir=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 60 '' $rootRef -Directory -NoName -AttributeList -StandardInfo),60)
$extentName=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 61 'restored' $rootRef -Directory -BaseReference $extentDir.Reference),61)
$extentFile=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 62 '' $extentDir.Reference -NoName -NoData -AttributeList -StandardInfo),62)
$extentData=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 63 'file.bin' $extentDir.Reference 12345 -BaseReference $extentFile.Reference),63)
$assembled=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($extentData,$extentName,$extentFile,$extentDir,$root),$false)
Assert ($assembled.Nodes['Z:\restored'].Bytes -eq 12345 -and $assembled.Files -eq 1 -and $assembled.IssueCount -eq 0) 'Names and unnamed data in extension records reconnect the tree and count only the base file'
$again=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData),$false)
Assert ($again.Nodes['Z:\'].Bytes -eq 12345 -and $extentDir.Names.Count -eq 0 -and $extentFile.Names.Count -eq 0) 'Extension assembly is order independent and leaves input records unchanged'
$staleExtent=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 64 'wrong' $rootRef -Directory -BaseReference ($extentDir.Reference+[uint64]281474976710656)),64)
$missingExtent=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$extentDir,$staleExtent),$false)
Assert ($missingExtent.Nodes.Count -eq 1 -and $missingExtent.MftOmittedDirectories -eq 1) 'Extension with stale base sequence is never attached to a reused record'
$extentFile.LinkCount=2
$incomplete=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData),$false)
Assert ($incomplete.Files -eq 0 -and $incomplete.MftOmittedFiles -eq 1) 'Incomplete extension names are detected against the base hard-link count'
$extentFile.LinkCount=1
$conflict=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 65 'other.bin' $extentDir.Reference 5 -BaseReference $extentFile.Reference),65)
$conflicted=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData,$conflict),$false)
Assert ($conflicted.Files -eq 0 -and $conflicted.IssueCount -gt 0) 'Conflicting initial data extents are not guessed'
$cloudTag=[Convert]::ToUInt32('9000001A',16); $wofTag=[Convert]::ToUInt32('80000017',16)
$cloudDir=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 70 'cloud' $rootRef -Directory -StandardInfo -ReparseTag $cloudTag),70)
$cloudFile=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 71 'online.bin' $cloudDir.Reference 4096 -ReparseTag ([Convert]::ToUInt32('9000F01A',16))),71)
$wof=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 72 'compressed.dll' $rootRef 2048 -ReparseTag $wofTag),72)
$known=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$cloudDir,$cloudFile,$wof),$false)
Assert ($known.Nodes['Z:\'].Bytes -eq 6144 -and $known.Files -eq 2 -and $known.IssueCount -eq 0 -and $known.MftCloudFiles -eq 1 -and $known.MftCloudBytes -eq 4096) 'Cloud directory/file and WOF data are included as logical metadata with separate cloud totals'
$wofBase=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 73 'extended-wof.dll' $rootRef 77 -AttributeList -StandardInfo -FileAttributes 0x400),73)
$wofExtent=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 74 '' $rootRef -NoName -NoData -BaseReference $wofBase.Reference -ReparseTag $wofTag),74)
$mergedTag=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$wofBase,$wofExtent),$false)
Assert ($mergedTag.Files -eq 1 -and $mergedTag.Nodes['Z:\'].Bytes -eq 77 -and $mergedTag.IssueCount -eq 0) 'Reparse tag stored in an extension record is classified after assembly'
foreach ($tag in @('A0000003','A000000C','8000FFFE')) {
    $link=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 70 'cloud' $rootRef -Directory -ReparseTag ([Convert]::ToUInt32($tag,16))),70)
    $skipped=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$link,$cloudFile),$false)
    Assert ($skipped.Nodes.Count -eq 1 -and $skipped.Files -eq 0 -and $skipped.IssueCounts.ContainsKey('DirectoryReparse-0x'+$tag)) "Junction/symlink/unknown tag $tag remains excluded with tag-specific diagnostics"
}
$stale=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 26 'stale.bin' ([uint64]562949953421332) 50),26)
$partial=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$dir,$stale),$false)
Assert ($partial.Files -eq 0 -and $partial.Nodes['Z:\folder'].Partial) 'Reused parent sequence is rejected and unresolved totals marked partial'
Assert ($partial.IssueCount -eq 1 -and $partial.MftOmittedFiles -eq 1 -and $partial.IssueCounts['FilePathUnresolved'] -eq 1) 'An unresolved file counts once, not once per link plus once per missing file'
$dir.Reparse=$true
$partial=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$dir,$sparse),$false)
Assert ($partial.Nodes.Count -eq 1 -and $partial.Files -eq 0 -and $partial.IssueCount -gt 0) 'Reparse directories and descendants are not traversed'
Assert ($partial.MftOmittedDirectories -eq 1 -and $partial.MftOmittedFiles -eq 1 -and $partial.Issues[0].Reason -match 'folder' -and $partial.IssueCounts['DirectoryReparse-UnknownTag'] -eq 1) 'Diagnostics identify the blocking ancestor and separate file and directory omissions'
$dir.Reparse=$false; $dir.Names[0].Parent=$dirRef
$partial=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$dir),$false)
Assert ($partial.Nodes.Count -eq 1 -and $partial.IssueCount -gt 0) 'Parent cycles terminate and are reported'
Assert ($partial.IssueCounts['DirectoryCycle'] -eq 1) 'Cycle has its own diagnostic cause'
$dir.Names[0].Parent=$rootRef
$partial=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$dir,$small),$true)
Assert ($partial.Cancelled -and $partial.Nodes['Z:\folder'].Partial) 'Cancellation flags every cached total incomplete'
$unicode=[RandomToolkits.DiskV6.MftScanner]::Parse((Record 27 ('file-'+[char]0x00f1) $rootRef 2),27)
Assert ($unicode.Names[0].Name -eq ('file-'+[char]0x00f1)) 'Unicode names decode correctly'
$duplicates=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',@($root,$compressed,$compressed),$false)
Assert ($duplicates.Nodes['Z:\'].Bytes -eq 10000 -and $duplicates.IssueCount -gt 0) 'Concurrent duplicate paths are reported without double charging'
$longRecords=New-Object 'System.Collections.Generic.List[RandomToolkits.DiskV6.MftRecord]'
$longRecords.Add($root); $parent=$rootRef
for ($i=30; $i -lt 34; $i++) {
    $entry=[RandomToolkits.DiskV6.MftScanner]::Parse((Record $i ('directory-'+('x'*100)) $parent -Directory),$i)
    $longRecords.Add($entry); $parent=$entry.Reference
}
$longRecords.Add([RandomToolkits.DiskV6.MftScanner]::Parse((Record 34 'leaf.bin' $parent 11),34))
$longScan=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',$longRecords.ToArray(),$false)
Assert ($longScan.Nodes['Z:\'].Bytes -eq 11 -and @($longScan.Nodes.Keys | Where-Object Length -gt 260).Count -gt 0 -and $longScan.IssueCount -eq 0) 'MFT tree reconstruction supports paths beyond MAX_PATH'
Assert ((Get-DiskMftUnavailableReason '\\server\share\') -like '*local drive root*') 'Network shares are rejected before raw-volume access'
$many=New-Object 'System.Collections.Generic.List[RandomToolkits.DiskV6.MftRecord]'
$many.Add($root);$many.Add($extended)
for ($i=100; $i -lt 120; $i++) { $many.Add([RandomToolkits.DiskV6.MftScanner]::Parse((Record $i ('lost-'+$i) ([uint64]562949953421332) 1),$i)) }
$summary=[RandomToolkits.DiskV6.MftScanner]::Build('Z:\',$many.ToArray(),$false)
Assert ($summary.IssueCount -eq 21 -and $summary.MftOmittedFiles -eq 21 -and $summary.Issues.Count -eq 5 -and $summary.IssueCounts.Count -eq 2) 'Repeated failures retain representative examples from each cause and exact unique-file omission count'
$sum=0; foreach ($count in $summary.IssueCounts.Values) { $sum+=$count }
Assert ($sum -eq $summary.IssueCount) 'Cause counts reconcile to total diagnostics'
foreach ($offset in @(0,20,24,60,72,76)) {
    $bad=[byte[]]$residentBytes.Clone(); Put $bad $offset ([uint32]0x7fffffff); $rejected=$false
    try { $null=[RandomToolkits.DiskV6.MftScanner]::Parse($bad,21) } catch { $rejected=$true }
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
