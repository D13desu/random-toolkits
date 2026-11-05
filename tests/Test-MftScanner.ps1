$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
Initialize-DiskScanner
function Assert($ok,$message) { if (-not $ok) { throw "FAIL: $message" }; Write-Output "PASS: $message" }
function Put($b,$offset,$value) { $bytes=[BitConverter]::GetBytes($value); [Array]::Copy($bytes,0,$b,$offset,$bytes.Length) }
function Record([int]$id,[string]$name,[uint64]$parent,[long]$size=0,[switch]$Directory,[switch]$Resident,[int]$Flags=0,[switch]$AttributeList,[int]$NameSpace=1,[switch]$StandardInfo,[uint32]$FileAttributes=0,[uint32]$ReparseTag=0,[uint64]$BaseReference=0,[uint16]$Links=1,[switch]$NoName,[switch]$NoData,[long]$Allocated=4096,[string]$StreamName,[long]$StreamAllocated=8192,[string]$ExpectNamedStream,[switch]$NonresidentList) {
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
        $len=64; if ($Flags -band 0x8001) { $len=80 }; if ($Resident) { $len=[int]([math]::Ceiling((24+$size)/8)*8) }
        Put $b $p ([uint32]0x80); Put $b ($p+4) ([uint32]$len); Put $b ($p+12) ([uint16]$Flags)
        if ($Resident) { Put $b ($p+16) ([uint32]$size); Put $b ($p+20) ([uint16]24) }
        else { $b[$p+8]=1; Put $b ($p+32) ([uint16]$(if ($Flags -band 0x8001) {72}else{64})); Put $b ($p+40) ([long]4096); Put $b ($p+48) $size; if ($Flags -band 0x8001) { Put $b ($p+64) $Allocated } else { Put $b ($p+40) $Allocated } }
        $p+=$len
    }
    if ($StandardInfo) {
        Put $b $p ([uint32]0x10); Put $b ($p+4) ([uint32]96); Put $b ($p+16) ([uint32]72); Put $b ($p+20) ([uint16]24)
        Put $b ($p+56) $FileAttributes; $p+=96
    }
    if ($StreamName) {
        $sn=[Text.Encoding]::Unicode.GetBytes($StreamName); $len=[int]([math]::Ceiling((72+$sn.Length)/8)*8)
        Put $b $p ([uint32]0x80); Put $b ($p+4) ([uint32]$len);$b[$p+8]=1;$b[$p+9]=$StreamName.Length
        Put $b ($p+10) ([uint16]64); Put $b ($p+32) ([uint16]($len-8)); Put $b ($p+40) $StreamAllocated; Put $b ($p+48) ([long]4097)
        [Array]::Copy($sn,0,$b,$p+64,$sn.Length);$p+=$len
    }
    if ($AttributeList) {
        if ($NonresidentList) {Put $b $p ([uint32]0x20);Put $b ($p+4) ([uint32]64);$b[$p+8]=1;Put $b ($p+32) ([uint16]64);$p+=64}
        else {
            $extraLength=0; if ($ExpectNamedStream) { $extraLength=[int]([math]::Ceiling((26+$ExpectNamedStream.Length*2)/8)*8) }
            Put $b $p ([uint32]0x20); Put $b ($p+4) ([uint32](56+$extraLength)); Put $b ($p+16) ([uint32](32+$extraLength)); Put $b ($p+20) ([uint16]24)
            Put $b ($p+24) ([uint32]$(if ($Directory) {0x30}else{0x80}));Put $b ($p+28) ([uint16]32);Put $b ($p+40) ([uint64](281474976710656+$id))
            if ($ExpectNamedStream) {
                $q=$p+56;Put $b $q ([uint32]0x80);Put $b ($q+4) ([uint16]$extraLength);$b[$q+6]=$ExpectNamedStream.Length;$b[$q+7]=26
                Put $b ($q+16) ([uint64](281474976710656+$id));$sn=[Text.Encoding]::Unicode.GetBytes($ExpectNamedStream);[Array]::Copy($sn,0,$b,$q+26,$sn.Length)
            }
            $p+=56+$extraLength
        }
    }
    if ($ReparseTag -ne 0) { Put $b $p ([uint32]0xc0); Put $b ($p+4) ([uint32]32); Put $b ($p+16) ([uint32]8); Put $b ($p+20) ([uint16]24); Put $b ($p+24) $ReparseTag; $p+=32 }
    Put $b $p ([uint32]::MaxValue); Put $b 24 ([uint32]($p+4))
    return ,$b
}
$rootRef=[uint64]281474976710661 # sequence 1, record 5
$dirRef=[uint64]281474976710676 # sequence 1, record 20
$root=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 5 '.' $rootRef -Directory),5)
$dir=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 20 'folder' $rootRef -Directory),20)
$residentBytes=Record 21 'small.bin' $dirRef 17 -Resident
$small=[RandomToolkits.DiskV10.MftScanner]::Parse($residentBytes,21)
$sparse=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 22 'sparse.bin' $dirRef 1000000 -Flags 0x8000),22)
$compressed=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 23 'compressed.bin' $rootRef 10000 -Flags 1),23)
Assert ($small.Bytes -eq 17 -and $sparse.Bytes -eq 1000000 -and $compressed.Bytes -eq 10000) 'Resident, sparse and compressed data use logical length, not allocation or stale filename size'
$alias=New-Object RandomToolkits.DiskV10.MftName; $alias.Parent=$rootRef; $alias.Name='alias.bin'; $small.Names.Add($alias)
$scan=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($small,$compressed,$dir,$sparse,$root),$false)
Assert ($scan.Nodes['Z:\'].Bytes -eq 1010017 -and $scan.Files -eq 3 -and $scan.IssueCount -eq 0) 'Unordered records reconstruct folders and charge each hard-linked file once'
Assert ($scan.Nodes['Z:\folder'].Bytes -eq 1000000) 'Hardlink ownership is deterministic by ordinal full path'
Assert (@(Get-DiskChildren $scan 'Z:\folder' | Where-Object Kind -eq LINK).Count -eq 1) 'Uncharged hardlink remains visible as LINK'
$short=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 24 'SHORT~1' $rootRef 5 -NameSpace 2),24)
Assert ($short.Names.Count -eq 0) 'DOS-only short names are excluded'
$extended=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 25 'extended.bin' $rootRef 50 -AttributeList),25)
$partial=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$extended),$false)
Assert ($partial.Files -eq 0 -and $partial.IssueCount -eq 1 -and $partial.Nodes['Z:\'].Partial) 'Attribute-list files are explicitly excluded instead of silently undercounted'
# Reproduce the reported WindowsApps blocker: directory index extents do not
# prevent reconstructing a base filename with authoritative standard flags.
$windowsApps=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList -StandardInfo),40)
$package=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 41 'Package' $windowsApps.Reference -Directory),41)
$payload=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 42 'payload.bin' $package.Reference 4096),42)
$fixed=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($payload,$package,$windowsApps,$root),$false)
Assert ($windowsApps.HasAttributeList -and -not $windowsApps.Unsupported -and $fixed.Nodes['Z:\WindowsApps'].Bytes -eq 4096 -and $fixed.IssueCount -eq 0) 'WindowsApps-style attribute-list directory retains its entire descendant tree'
$reparseDir=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList -StandardInfo -FileAttributes 0x400),40)
$excluded=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($payload,$package,$reparseDir,$root),$false)
Assert ($reparseDir.Reparse -and $excluded.Files -eq 1 -and $excluded.MftReparseDirectories -eq 1 -and $excluded.MftUnknownTags -eq 1) 'Unknown-tag directory retains its own MFT children without consulting any reparse target'
$missingFlags=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 40 'WindowsApps' $rootRef -Directory -AttributeList),40)
Assert $missingFlags.Unsupported 'Attribute-list directory without authoritative base flags stays excluded'
$noBaseName=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 40 'WINDOW~1' $rootRef -Directory -AttributeList -StandardInfo -NameSpace 2),40)
Assert $noBaseName.Unsupported 'Attribute-list directory without a usable base name stays excluded'
$extentDir=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 60 '' $rootRef -Directory -NoName -AttributeList -StandardInfo),60)
$extentName=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 61 'restored' $rootRef -Directory -BaseReference $extentDir.Reference),61)
$extentDir.ExpectedNames.Clear();$extentDir.ExpectedNames.Add($extentName.Reference,1);$extentDir.ExtensionReferences.Add($extentName.Reference)
$extentFile=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 62 '' $extentDir.Reference -NoName -NoData -AttributeList -StandardInfo),62)
$extentData=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 63 'file.bin' $extentDir.Reference 12345 -BaseReference $extentFile.Reference),63)
$assembled=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($extentData,$extentName,$extentFile,$extentDir,$root),$false)
Assert ($assembled.Nodes['Z:\restored'].Bytes -eq 12345 -and $assembled.Files -eq 1 -and $assembled.IssueCount -eq 0) 'Names and unnamed data in extension records reconnect the tree and count only the base file'
$again=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData),$false)
Assert ($again.Nodes['Z:\'].Bytes -eq 12345 -and $extentDir.Names.Count -eq 0 -and $extentFile.Names.Count -eq 0) 'Extension assembly is order independent and leaves input records unchanged'
$staleExtent=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 64 'wrong' $rootRef -Directory -BaseReference ($extentDir.Reference+[uint64]281474976710656)),64)
$missingExtent=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$extentDir,$staleExtent),$false)
Assert ($missingExtent.Nodes.Count -eq 1 -and $missingExtent.MftOmittedDirectories -eq 1) 'Extension with stale base sequence is never attached to a reused record'
$extentFile.LinkCount=2
$incomplete=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData),$false)
Assert ($incomplete.Files -eq 0 -and $incomplete.MftOmittedFiles -eq 1) 'Incomplete extension names are detected against the base hard-link count'
$extentFile.LinkCount=1
$conflict=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 65 'other.bin' $extentDir.Reference 5 -BaseReference $extentFile.Reference),65)
$conflicted=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$extentDir,$extentName,$extentFile,$extentData,$conflict),$false)
Assert ($conflicted.Files -eq 0 -and $conflicted.IssueCount -gt 0) 'Conflicting initial data extents are not guessed'
$cloudTag=[Convert]::ToUInt32('9000001A',16); $wofTag=[Convert]::ToUInt32('80000017',16)
$cloudDir=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 70 'cloud' $rootRef -Directory -StandardInfo -ReparseTag $cloudTag),70)
$cloudFile=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 71 'online.bin' $cloudDir.Reference 4096 -ReparseTag ([Convert]::ToUInt32('9000F01A',16))),71)
$wof=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 72 'compressed.dll' $rootRef 2048 -ReparseTag $wofTag),72)
$known=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$cloudDir,$cloudFile,$wof),$false)
Assert ($known.Nodes['Z:\'].Bytes -eq 6144 -and $known.Files -eq 2 -and $known.IssueCount -eq 0 -and $known.MftCloudFiles -eq 1 -and $known.MftCloudBytes -eq 4096) 'Cloud directory/file and WOF data are included as logical metadata with separate cloud totals'
$wofBase=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 73 'extended-wof.dll' $rootRef 77 -AttributeList -StandardInfo -FileAttributes 0x400),73)
$wofExtent=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 74 '' $rootRef -NoName -NoData -BaseReference $wofBase.Reference -ReparseTag $wofTag),74)
$mergedTag=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$wofBase,$wofExtent),$false)
Assert ($mergedTag.Files -eq 1 -and $mergedTag.Nodes['Z:\'].Bytes -eq 77 -and $mergedTag.IssueCount -eq 0) 'Reparse tag stored in an extension record is classified after assembly'
foreach ($tag in @('A0000003','A000000C','8000FFFE')) {
    $link=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 70 'cloud' $rootRef -Directory -ReparseTag ([Convert]::ToUInt32($tag,16))),70)
    $skipped=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$link,$cloudFile),$false)
    Assert ($skipped.Nodes.Count -eq 2 -and $skipped.Files -eq 1 -and $skipped.Nodes['Z:\cloud'].ReparseTag -eq ('0x'+$tag)) "Tag $tag preserves only supplied local MFT records without following any target"
}
$stale=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 26 'stale.bin' ([uint64]562949953421332) 50),26)
$partial=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$dir,$stale),$false)
Assert ($partial.Files -eq 0 -and $partial.Nodes['Z:\folder'].Partial) 'Reused parent sequence is rejected and unresolved totals marked partial'
Assert ($partial.IssueCount -eq 1 -and $partial.MftOmittedFiles -eq 1 -and $partial.IssueCounts['FilePathUnresolved'] -eq 1) 'An unresolved file counts once, not once per link plus once per missing file'
$dir.Reparse=$true
$partial=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$dir,$sparse),$false)
Assert ($partial.Nodes.Count -eq 2 -and $partial.Files -eq 1 -and $partial.IssueCount -eq 0) 'MFT reparse rows contain their own metadata instead of causing an exclusion cascade'
Assert ($partial.MftUnknownTags -eq 1 -and $partial.MftReparseDirectories -eq 1 -and @(Get-DiskChildren $partial 'Z:\folder').Count -eq 1) 'Unknown tags are disclosed; cached navigation works even on a nonexistent drive without resolving a target'
$dir.Reparse=$false; $dir.Names[0].Parent=$dirRef
$partial=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$dir),$false)
Assert ($partial.Nodes.Count -eq 1 -and $partial.IssueCount -gt 0) 'Parent cycles terminate and are reported'
Assert ($partial.IssueCounts['DirectoryCycle'] -eq 1) 'Cycle has its own diagnostic cause'
$dir.Names[0].Parent=$rootRef
$partial=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$dir,$small),$true)
Assert ($partial.Cancelled -and $partial.Nodes['Z:\folder'].Partial) 'Cancellation flags every cached total incomplete'
$unicode=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 27 ('file-'+[char]0x00f1) $rootRef 2),27)
Assert ($unicode.Names[0].Name -eq ('file-'+[char]0x00f1)) 'Unicode names decode correctly'
$duplicates=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$compressed,$compressed),$false)
Assert ($duplicates.Nodes['Z:\'].Bytes -eq 10000 -and $duplicates.IssueCount -gt 0) 'Concurrent duplicate paths are reported without double charging'
$longRecords=New-Object 'System.Collections.Generic.List[RandomToolkits.DiskV10.MftRecord]'
$longRecords.Add($root); $parent=$rootRef
for ($i=30; $i -lt 34; $i++) {
    $entry=[RandomToolkits.DiskV10.MftScanner]::Parse((Record $i ('directory-'+('x'*100)) $parent -Directory),$i)
    $longRecords.Add($entry); $parent=$entry.Reference
}
$longRecords.Add([RandomToolkits.DiskV10.MftScanner]::Parse((Record 34 'leaf.bin' $parent 11),34))
$longScan=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',$longRecords.ToArray(),$false)
Assert ($longScan.Nodes['Z:\'].Bytes -eq 11 -and @($longScan.Nodes.Keys | Where-Object Length -gt 260).Count -gt 0 -and $longScan.IssueCount -eq 0) 'MFT tree reconstruction supports paths beyond MAX_PATH'
Assert ((Get-DiskMftUnavailableReason '\\server\share\') -like '*local drive root*') 'Network shares are rejected before raw-volume access'
$many=New-Object 'System.Collections.Generic.List[RandomToolkits.DiskV10.MftRecord]'
$many.Add($root);$many.Add($extended)
for ($i=100; $i -lt 120; $i++) { $many.Add([RandomToolkits.DiskV10.MftScanner]::Parse((Record $i ('lost-'+$i) ([uint64]562949953421332) 1),$i)) }
$summary=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',$many.ToArray(),$false)
Assert ($summary.IssueCount -eq 21 -and $summary.MftOmittedFiles -eq 21 -and $summary.Issues.Count -eq 5 -and $summary.IssueCounts.Count -eq 2) 'Repeated failures retain representative examples from each cause and exact unique-file omission count'
$sum=0; foreach ($count in $summary.IssueCounts.Values) { $sum+=$count }
Assert ($sum -eq $summary.IssueCount) 'Cause counts reconcile to total diagnostics'
Assert ($small.AllocationKnown -and $small.Allocated -eq 24 -and $sparse.Allocated -eq 4096 -and $compressed.Allocated -eq 4096) 'Resident data counts its padded MFT slot; sparse/compressed data use TotalAllocated'
Assert ($scan.Nodes['Z:\'].Allocated -eq 8216) 'Hard-linked resident file allocation is charged exactly once'
$ads=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 80 'streams.bin' $rootRef 20 -StreamName 'extra'),80)
Assert ($ads.AllocationKnown -and $ads.Allocated -eq 12288) 'Named DATA streams contribute to allocation independently of logical unnamed size'
$largeAllocated=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 81 'preallocated.bin' $rootRef 2 -Allocated 16384),81)
$allocationView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$largeAllocated,$sparse,$dir),$false)
Assert ($allocationView.CachedRows['Z:\'][0].Name -eq 'preallocated.bin' -and $allocationView.Nodes['Z:\'].Allocated -eq 20480) 'MFT rows sort by allocation and directory allocation sums children'
$unknownBytes=Record 82 'unknown.bin' $rootRef 9000 -Flags 0x8000
$attributeOffset=[BitConverter]::ToUInt16($unknownBytes,20);$dataOffset=$attributeOffset+[BitConverter]::ToUInt32($unknownBytes,$attributeOffset+4)
Put $unknownBytes ($dataOffset+32) ([uint16]64)
$unknown=[RandomToolkits.DiskV10.MftScanner]::Parse($unknownBytes,82)
Assert (-not $unknown.AllocationKnown -and (Format-DiskAllocation $unknown.Allocated $true) -eq 'Unknown') 'Unavailable compressed/sparse allocation never displays as zero'
$unknownScan=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$unknown),$false)
Assert ($unknownScan.MftUnknownAllocations -eq 1 -and $unknownScan.Nodes['Z:\'].AllocationUnknown) 'Unknown allocation propagates to folder totals and diagnostics'
$nonresidentList=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 83 'partial.bin' $rootRef 9000 -AttributeList -NonresidentList -StandardInfo),83)
Assert (-not $nonresidentList.AllocationKnown -and $nonresidentList.Allocated -eq 4096 -and (Format-DiskAllocation 4096 $true) -like '>=*') 'Unverified stream completeness preserves known allocation only as a lower bound'
$owner=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 84 'owner.bin' $rootRef -NoData -AttributeList -StandardInfo -ExpectNamedStream 'extra'),84)
$dataPart=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 85 '' $rootRef 10 -NoName -BaseReference $owner.Reference),85)
$adsPart=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 86 '' $rootRef -NoName -NoData -BaseReference $owner.Reference -StreamName 'extra'),86)
$streamJoin=[RandomToolkits.DiskV10.MftScanner]::Assemble(@($owner,$dataPart,$adsPart))[0]
Assert ($streamJoin.AllocationKnown -and $streamJoin.Allocated -eq 12288) 'Named stream allocation joins extensions and reconciles to the resident attribute list'
$streamMissing=[RandomToolkits.DiskV10.MftScanner]::Assemble(@($owner,$dataPart))[0]
Assert (-not $streamMissing.AllocationKnown -and $streamMissing.Allocated -eq 4096) 'A missing named stream remains unknown instead of silently claiming complete allocation'
$wciTag=[Convert]::ToUInt32('80000018',16)
$containerDir=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 87 'container' $rootRef -Directory -ReparseTag $wciTag),87)
$containerFile=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 88 'projected.bin' $containerDir.Reference 100000000 -Allocated 0 -Flags 0x8000 -ReparseTag ([Convert]::ToUInt32('90001018',16))),88)
$containerView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$containerDir,$containerFile),$false)
Assert ($containerView.MftContainerFiles -eq 1 -and $containerView.MftContainerBytes -eq 100000000 -and $containerView.Nodes['Z:\'].Allocated -eq 0 -and $containerView.IssueCount -eq 0) 'Container logical projection is identified separately and never substituted for local allocation'
$dosOwner=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 89 'long-name.bin' $rootRef 99 -AttributeList -StandardInfo -Links 2),89)
$dosAlias=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 90 'LONG-N~1.BIN' $rootRef -NameSpace 2 -BaseReference $dosOwner.Reference -NoData),90)
$dosView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$dosOwner,$dosAlias),$false)
Assert ($dosView.Files -eq 1 -and $dosView.Nodes['Z:\'].Allocated -eq 4096 -and $dosView.IssueCount -eq 0 -and $dosView.CachedRows['Z:\'].Count -eq 1) 'DOS aliases satisfy the MFT attribute count without being displayed or charged as extra hard links'
$runs=[RandomToolkits.DiskV10.MftScanner]::DecodeAttributeListRuns([byte[]]@(0x11,2,10,0x11,1,0xfd,0),2,100)
Assert ($runs.Count -eq 2 -and $runs[0].Cluster -eq 10 -and $runs[1].Cluster -eq 7) 'Fragmented attribute-list runs decode signed negative cluster deltas'
foreach($mapping in @(@(0x01,1,0),@(0x11,0,1,0),@(0x11,1,101,0),@(0x11,1,1),@(0x91,1,1,0),@(0x11,2,1,0))) {
    $rejected=$false;try { $null=[RandomToolkits.DiskV10.MftScanner]::DecodeAttributeListRuns([byte[]]$mapping,0,100) } catch {$rejected=$true}
    Assert $rejected 'Reject sparse, zero-length, out-of-volume, truncated or inconsistent metadata run'
}
$external=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 91 'external-list.bin' $rootRef 99 -AttributeList -StandardInfo -NonresidentList),91)
$list=[byte[]]::new(32);Put $list 0 ([uint32]0x80);Put $list 4 ([uint16]32);Put $list 16 $external.Reference
[RandomToolkits.DiskV10.MftScanner]::ParseAttributeList($external,$list)
$assembled=[RandomToolkits.DiskV10.MftScanner]::Assemble(@($external))[0]
Assert ($assembled.AllocationKnown -and $assembled.Allocated -eq 4096 -and -not $assembled.Unsupported) 'Decoded external list resolves stream completeness without changing allocation'
$verified=[byte[]]::new(64);[Array]::Copy($list,0,$verified,0,32);Put $verified 32 ([uint32]0x30);Put $verified 36 ([uint16]32);Put $verified 48 $external.Reference
[RandomToolkits.DiskV10.MftScanner]::ParseAttributeList($external,$verified);$external.LinkCount=2
$verifiedView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$external),$false)
Assert ($verifiedView.Files -eq 1 -and $verifiedView.IssueCounts['IncludedLinkCountMismatch'] -eq 1) 'Verified name list includes a header-count mismatch with an explicit diagnostic'
Put $verified 48 ([uint64]281474976710755)
[RandomToolkits.DiskV10.MftScanner]::ParseAttributeList($external,$verified)
$missingView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$external),$false)
Assert ($missingView.Files -eq 0 -and $missingView.MftOmittedFiles -eq 1) 'Missing referenced filename extension cannot bypass completeness checks'
$badList=[byte[]]$list.Clone();Put $badList 4 ([uint16]40);$rejected=$false
try {[RandomToolkits.DiskV10.MftScanner]::ParseAttributeList($external,$badList)}catch{$rejected=$true}
Assert $rejected 'Attribute list rejects an entry extending beyond its logical length'
$metadata=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 92 'metadata' ([uint64]281474976710667) -Directory),92)
$metadataFile=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 93 'log' $metadata.Reference 4096),93)
$metadataView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$metadata,$metadataFile),$false)
Assert ($metadataView.IssueCounts['FileSystemMetadata'] -eq 1 -and -not $metadataView.IssueCounts.ContainsKey('FilePathUnresolved')) 'Metadata descendants are classified as intentional exclusions'
foreach ($offset in @(0,20,24,60,72,76)) {
    $bad=[byte[]]$residentBytes.Clone(); Put $bad $offset ([uint32]0x7fffffff); $rejected=$false
    try { $null=[RandomToolkits.DiskV10.MftScanner]::Parse($bad,21) } catch { $rejected=$true }
    Assert $rejected "Malformed record at offset $offset rejected"
}
$apiRecord=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 96 'api.bin' $rootRef 99 -AttributeList -StandardInfo -NonresidentList -Links 2),96)
$api=[RandomToolkits.DiskV10.MftApi]::new();$api.ReturnedReference=$apiRecord.Reference;$api.Logical=99;$api.Links=1;$api.Names.Add('\api.bin')
$stream=[RandomToolkits.DiskV10.MftApi+StreamRow]::new();$stream.Name='::$DATA';$stream.Logical=99;$stream.Allocated=4096;$api.Streams.Add($stream)
Assert ($null -eq [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'API validation accepts matching identity, paths, streams and allocation'
$api.ReturnedReference++
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'API validation rejects reused file references'
$api.ReturnedReference=$apiRecord.Reference;$api.Names[0]='\other.bin'
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Equal link counts cannot hide a changed path'
$api.Names[0]='\api.bin';$stream.Allocated=8192
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'API validation rejects allocation discrepancies'
$stream.Allocated=4096;$api.Streams.Add($stream)
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Unexpected or duplicate streams cannot establish completeness'
$api.Streams.RemoveAt(1)
$api.Names.Clear();$api.LinkError='FindFirstFileName: 50';$api.LinkErrorCode=50;$api.Path='\\?\Z:\api.bin'
Assert ($null -eq [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Single-link error 50 accepts the identical opened-handle path'
$api.Path='\\?\Z:\other.bin'
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Single-link fallback rejects a different handle path'
$api.Path='\\?\Z:\api.bin';$api.LinkErrorCode=5
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Access denied cannot use the single-link exception'
$api.LinkErrorCode=50;$api.Links=2
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin','Z:\alias.bin'))) 'Multiple links still require full enumeration'
$api.Links=1;$apiRecord.Reparse=$true;$apiRecord.ReparseTag=[Convert]::ToUInt32('80000017',16)
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'WOF records cannot use the ordinary single-link exception'
$api.Names.Add('\api.bin');$api.GetType().GetField('LinkError').SetValue($api,$null);$api.LinkErrorCode=0
Assert ($null -eq [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'Known WOF metadata accepts complete matching API enumeration'
$apiRecord.UnnamedAllocated=0;$apiRecord.NamedStreams=[Collections.Generic.List[RandomToolkits.DiskV10.MftStream]]::new()
$backing=[RandomToolkits.DiskV10.MftStream]::new();$backing.Name='WofCompressedData';$backing.Known=$true;$backing.Allocated=4096;$apiRecord.NamedStreams.Add($backing)
Assert ($null -eq [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'WOF hidden backing stream maps to the API unnamed allocation without double charging'
$stream.Allocated=8192
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'WOF normalization rejects a different allocated size'
$stream.Allocated=4096;$extra=[RandomToolkits.DiskV10.MftStream]::new();$extra.Name='extra';$extra.Known=$true;$extra.Allocated=1024;$apiRecord.NamedStreams.Add($extra)
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'WOF normalization cannot hide a missing unrelated named stream'
$apiRecord.NamedStreams.Clear();$apiRecord.UnnamedAllocated=4096
$api.Attributes=0x400
Assert ($null -ne [RandomToolkits.DiskV10.MftApi]::Validate($api,$apiRecord,[string[]]@('Z:\api.bin'))) 'A handle still reporting a reparse point stays ineligible'
$api.Attributes=0
foreach($tag in @('80000018','90001018','A000000C','00000000')) {
    $apiRecord.ReparseTag=[Convert]::ToUInt32($tag,16)
    Assert (-not [RandomToolkits.DiskV10.MftApi]::Eligible($apiRecord)) "Container, symlink and unknown tags remain blocked: $tag"
}
$apiRecord.Reparse=$false
$callbackType=([RandomToolkits.DiskV10.MftScanner].GetMethods() | Where-Object {$_.Name -eq 'Build' -and $_.GetParameters().Count -eq 4}).GetParameters()[3].ParameterType
$verifyBlock={param($record,$paths) [RandomToolkits.DiskV10.MftApi]::Validate($api,$record,$paths)}
$verify=[Management.Automation.LanguagePrimitives]::ConvertTo($verifyBlock,$callbackType)
$apiView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$apiRecord),$false,$verify)
Assert ($apiView.Files -eq 1 -and $apiView.MftApiVerified -eq 1 -and $apiView.MftUnknownAllocations -eq 0 -and $apiView.Nodes['Z:\'].Allocated -eq 4096) 'Verified fallback recovers an unsupported file without double charging'
Assert $apiRecord.Unsupported 'Fallback leaves input records unchanged'
$apiRecord.Reparse=$true;$apiRecord.ReparseTag=[Convert]::ToUInt32('80000017',16)
$wofView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$apiRecord),$false,$verify)
Assert ($wofView.Files -eq 1 -and $wofView.MftApiVerified -eq 1) 'Verified WOF records reach the fallback and are charged once'
$apiRecord.Reparse=$false
$failedVerify=[Management.Automation.LanguagePrimitives]::ConvertTo({param($record,$paths) 'Access denied'},$callbackType)
$failedView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$apiRecord),$false,$failedVerify)
Assert ($failedView.Files -eq 0 -and $failedView.IssueCounts['ApiVerificationFailed'] -eq 1) 'Failed API verification preserves the exclusion'
$apiRecord.Reparse=$true
$apiRecord.ReparseTag=0
$never=[Management.Automation.LanguagePrimitives]::ConvertTo({throw 'Reparse callback must never run'},$callbackType)
$reparseView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$apiRecord),$false,$never)
Assert (-not $reparseView.IssueCounts.ContainsKey('ApiVerificationFailed') -and $reparseView.Files -eq 0) 'Unrecognized reparse records never invoke the API fallback'
$systemFile=[RandomToolkits.DiskV10.MftScanner]::Parse((Record 97 '$Quota' ([uint64]281474976710667) -NoData -StandardInfo),97)
$systemView=[RandomToolkits.DiskV10.MftScanner]::Build('Z:\',@($root,$systemFile),$false,$never)
Assert ($systemView.IssueCounts['FileSystemMetadata'] -eq 1 -and -not $systemView.IssueCounts.ContainsKey('FileUnsupported')) 'System metadata without DATA is intentionally excluded before validation'
$source=Get-Content (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -Raw
$embedded=($source -split '// BEGIN EMBEDDED MFT SCANNER',2)[1] -split '// END EMBEDDED MFT SCANNER',2
Assert ($embedded[0].Replace("`r`n","`n").Trim() -eq (Get-Content (Join-Path $PSScriptRoot '../win/disk/MftScanner.cs') -Raw).Replace("`r`n","`n").Trim()) 'Embedded C# matches maintained source'
# Test fallback without initiating a production drive scan.
function Get-DiskMftUnavailableReason { 'Simulated unavailable elevation or filesystem' }
function Measure-DiskTreeFallback { [pscustomobject]@{Fallback=$true} }
function Initialize-DiskScanner { throw 'Simulated compilation restriction' }
$fallback=Measure-DiskTree 'Z:\' -Engine Mft
Assert $fallback.Fallback 'Unavailable MFT and restricted compilation fall back to PowerShell'
Write-Output "MFT tests passed on PowerShell $($PSVersionTable.PSVersion)"
