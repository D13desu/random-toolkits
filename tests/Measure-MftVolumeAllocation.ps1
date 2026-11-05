# Optional elevated read-only volume validation. Writes a compact report only.
[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath,[string]$CancelPath,[int]$TimeoutSeconds=600)
$ErrorActionPreference='Stop'
$timer=[Diagnostics.Stopwatch]::StartNew();$worker=$null
try {
    . (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
    $reason=Get-DiskMftUnavailableReason $Drive;if ($reason) {throw $reason}
    Initialize-DiskScanner
    $worker=[RandomToolkits.DiskV8.MftScanner]::Start([IO.Path]::GetFullPath($Drive))
    $last=0
    while (-not $worker.Done) {
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or ($CancelPath -and [IO.File]::Exists($CancelPath))) { $worker.CancelRequested=$true }
        if ($timer.Elapsed.TotalSeconds-$last -ge 10) {
            $status=@{Status='Running';Seconds=[int]$timer.Elapsed.TotalSeconds;Records=$worker.RecordsSeen;CancellationRequested=$worker.CancelRequested} | ConvertTo-Json
            [IO.File]::WriteAllText($ReportPath,$status,[Text.UTF8Encoding]::new($false));$last=$timer.Elapsed.TotalSeconds
        }
        Start-Sleep -Milliseconds 200
    }
    if ($worker.Error) {throw $worker.Error}
    $scan=$worker.Result;$root=$scan.Nodes[$scan.Root]
    $report=[ordered]@{
        Status='Complete';Cancelled=$scan.Cancelled;Seconds=[math]::Round($timer.Elapsed.TotalSeconds,1)
        Records=$scan.MftRecordsRead;Files=$scan.Files;Folders=$scan.Nodes.Count
        LogicalBytes=$root.Bytes;AccountedAllocation=$root.Allocated;WindowsUsed=$scan.VolumeUsed;Difference=($scan.VolumeUsed-$root.Allocated)
        UnknownAllocations=$scan.MftUnknownAllocations;OmittedFiles=$scan.MftOmittedFiles;OmittedDirectories=$scan.MftOmittedDirectories;ParseErrors=$scan.MftRecordErrors
        ContainerFiles=$scan.MftContainerFiles;ContainerLogical=$scan.MftContainerBytes;ContainerAllocated=$scan.MftContainerAllocated
        ReparseFiles=$scan.MftReparseFiles;ReparseDirectories=$scan.MftReparseDirectories;UnknownTags=$scan.MftUnknownTags
        CloudFiles=$scan.MftCloudFiles;CloudLogical=$scan.MftCloudBytes;Causes=$scan.IssueCounts
        Largest=@(Get-DiskChildren $scan $scan.Root | Select-Object -First 12 Name,Kind,Bytes,Allocated,AllocationUnknown,Partial)
        Examples=@($scan.Issues | Select-Object -First 32 Path,Reason,Category)
    }
    [IO.File]::WriteAllText($ReportPath,($report | ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
} catch {
    [IO.File]::WriteAllText($ReportPath,(@{Status='FAIL';Error=$_.Exception.ToString()} | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    exit 1
} finally {if ($worker) {$worker.CancelRequested=$true}}
