# Random Toolkits | Disk Usage 0.1.0 | PowerShell 5.0+
[CmdletBinding()]
param([switch]$NoMenu, [string]$Path)

function Format-DiskSize {
    param([double]$Bytes)
    foreach ($unit in @('B','KiB','MiB','GiB','TiB','PiB')) {
        if ($Bytes -lt 1024 -or $unit -eq 'PiB') { return ('{0:N1} {1}' -f $Bytes,$unit) }
        $Bytes /= 1024
    }
}

function Get-DiskDrives {
    foreach ($drive in [IO.DriveInfo]::GetDrives()) {
        try {
            if (-not $drive.IsReady) { [pscustomobject]@{Drive=$drive.Name;Type=[string]$drive.DriveType;Ready=$false;Total=0L;Used=0L;Free=0L;Detail='Not ready'}; continue }
            [pscustomobject]@{Drive=$drive.Name;Type=[string]$drive.DriveType;Ready=$true;Total=$drive.TotalSize;Used=($drive.TotalSize-$drive.TotalFreeSpace);Free=$drive.TotalFreeSpace;Detail=$drive.VolumeLabel}
        } catch { [pscustomobject]@{Drive=$drive.Name;Type=[string]$drive.DriveType;Ready=$false;Total=0L;Used=0L;Free=0L;Detail=$_.Exception.Message} }
    }
}

function Add-DiskScanIssue {
    param($Scan,[string]$ItemPath,[string]$Reason)
    $Scan.IssueCount++
    if ($Scan.Issues.Count -lt 100) { $Scan.Issues.Add([pscustomobject]@{Path=$ItemPath;Reason=$Reason}) }
}

function Measure-DiskTree {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    $root = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($root -isnot [IO.DirectoryInfo]) { throw 'Select a filesystem directory or drive root.' }
    if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Select the real directory, not a junction or symbolic link.' }
    $scan = [pscustomobject]@{Root=$root.FullName;Nodes=@{};Files=0L;IssueCount=0;Issues=(New-Object 'System.Collections.Generic.List[object]');Started=(Get-Date);Finished=$null}
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $order = New-Object 'System.Collections.Generic.List[string]'
    $scan.Nodes[$root.FullName] = [pscustomobject]@{Path=$root.FullName;Parent=$null;Bytes=0L;Files=0L;Partial=$false;Children=(New-Object 'System.Collections.Generic.List[string]')}
    $pending.Push($root.FullName)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($pending.Count -gt 0) {
            $directory = $pending.Pop()
            $node = $scan.Nodes[$directory]
            $order.Add($directory)
            $enumerator = $null
            try {
                # Recheck links before descent in case the tree changed during the scan.
                if (([IO.File]::GetAttributes($directory) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Directory changed into a reparse point; skipped.' }
                $enumerator = [IO.Directory]::EnumerateFileSystemEntries($directory).GetEnumerator()
                while ($enumerator.MoveNext()) {
                    $itemPath = $enumerator.Current
                    try {
                        $attributes = [IO.File]::GetAttributes($itemPath)
                        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                            $node.Partial = $true
                            Add-DiskScanIssue $scan $itemPath 'Reparse point skipped (junction, symlink, or cloud placeholder).'
                            continue
                        }
                        if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                            $scan.Nodes[$itemPath] = [pscustomobject]@{Path=$itemPath;Parent=$directory;Bytes=0L;Files=0L;Partial=$false;Children=(New-Object 'System.Collections.Generic.List[string]')}
                            $node.Children.Add($itemPath)
                            $pending.Push($itemPath)
                        } else {
                            $file = New-Object IO.FileInfo($itemPath)
                            $node.Bytes += $file.Length
                            $node.Files++
                            $scan.Files++
                        }
                    } catch { $node.Partial=$true; Add-DiskScanIssue $scan $itemPath $_.Exception.Message }
                    if ($timer.ElapsedMilliseconds -ge 250) {
                        Write-Progress -Activity 'Scanning disk usage (read-only)' -Status ("{0:N0} files | {1:N0} folders | {2}" -f $scan.Files,$scan.Nodes.Count,$directory)
                        $timer.Restart()
                    }
                }
            } catch { $node.Partial=$true; Add-DiskScanIssue $scan $directory $_.Exception.Message }
            finally { if ($null -ne $enumerator -and $enumerator -is [IDisposable]) { $enumerator.Dispose() } }
        }
        for ($i=$order.Count-1; $i -ge 0; $i--) {
            $node = $scan.Nodes[$order[$i]]
            if ($node.Parent) {
                $parent = $scan.Nodes[$node.Parent]
                $parent.Bytes += $node.Bytes
                $parent.Files += $node.Files
                if ($node.Partial) { $parent.Partial=$true }
            }
        }
        $scan.Finished = Get-Date
        return $scan
    } finally { Write-Progress -Activity 'Scanning disk usage (read-only)' -Completed; $timer.Stop() }
}

function Get-DiskChildren {
    param($Scan,[string]$LiteralPath)
    $node = $Scan.Nodes[$LiteralPath]
    if (-not $node) { throw 'Directory is outside this scan.' }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($childPath in $node.Children) {
        $child = $Scan.Nodes[$childPath]
        $rows.Add([pscustomobject]@{Name=[IO.Path]::GetFileName($childPath);Path=$childPath;Kind='DIR';Bytes=$child.Bytes;Partial=$child.Partial})
    }
    # Cache directory totals only. Read direct file metadata on navigation to avoid retaining every file in RAM.
    try {
        foreach ($file in ([IO.DirectoryInfo]::new($LiteralPath)).EnumerateFiles()) {
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            $rows.Add([pscustomobject]@{Name=$file.Name;Path=$file.FullName;Kind='FILE';Bytes=$file.Length;Partial=$false})
        }
    } catch { Write-Warning ('Some files cannot be listed: ' + $_.Exception.Message) }
    $rows | Sort-Object -Property @{Expression='Bytes';Descending=$true},Name
}

function Show-DiskScan {
    param($Scan)
    $current = $Scan.Root
    $page = 0
    :browse while ($true) {
        $node = $Scan.Nodes[$current]
        $rows = @(Get-DiskChildren $Scan $current)
        $pages = [math]::Max(1,[math]::Ceiling($rows.Count/20.0))
        $page = [math]::Min($page,$pages-1)
        Write-Host "`n DISK USAGE | $current" -ForegroundColor Cyan
        Write-Host ("Logical size: {0} | Files: {1:N0} | Scan exclusions/errors: {2}" -f (Format-DiskSize $node.Bytes),$node.Files,$Scan.IssueCount)
        if ($node.Partial) { Write-Host 'PARTIAL TOTAL: inaccessible or excluded entries exist below this folder.' -ForegroundColor Yellow }
        Write-Host 'Folder totals are cached; direct file sizes are current. Rescan after filesystem changes.' -ForegroundColor DarkGray
        for ($i=($page*20); $i -lt [math]::Min($rows.Count,($page+1)*20); $i++) {
            $row = $rows[$i]
            $flag = ''
            if ($row.Partial) { $flag = ' [partial]' }
            Write-Host (' [{0}] {1,12}  {2,-4}  {3}{4}' -f ($i+1),(Format-DiskSize $row.Bytes),$row.Kind,$row.Name,$flag)
        }
        Write-Host ("Page {0}/{1} | Number: open folder | U: up | N/P: pages | R: rescan root | E: exclusions | 0: drives" -f ($page+1),$pages)
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        switch ($answer.Trim().ToUpperInvariant()) {
            'U' { if ($node.Parent) { $current=$node.Parent; $page=0 }; continue browse }
            'N' { $page=[math]::Min($pages-1,$page+1); continue browse }
            'P' { $page=[math]::Max(0,$page-1); continue browse }
            'E' { $Scan.Issues | Format-List | Out-Host; Write-Host "Showing up to 100 of $($Scan.IssueCount) exclusions/errors."; continue browse }
            'R' { $Scan=Measure-DiskTree $Scan.Root; $current=$Scan.Root; $page=0; continue browse }
        }
        $number=0
        if ([int]::TryParse($answer,[ref]$number) -and $number -gt 0 -and $number -le $rows.Count) {
            $row=$rows[$number-1]
            if ($row.Kind -eq 'DIR') { $current=$row.Path; $page=0 }
            else { Write-Host ("{0} | {1} | Read-only: no file open/delete actions." -f $row.Path,(Format-DiskSize $row.Bytes)) }
        } else { Write-Warning 'Choose an entry number or navigation command.' }
    }
}

function Start-DiskUsage {
    param([string]$InitialPath)
    if ($InitialPath) { Show-DiskScan (Measure-DiskTree $InitialPath) }
    while ($true) {
        $drives = @(Get-DiskDrives | Sort-Object Used -Descending)
        Write-Host "`n RANDOM TOOLKITS | DISK USAGE 0.1.0 | READ ONLY" -ForegroundColor Cyan
        for ($i=0; $i -lt $drives.Count; $i++) {
            $drive=$drives[$i]
            Write-Host (' [{0}] {1} {2} | Total {3} | Used {4} | Free {5} | {6}' -f ($i+1),$drive.Drive,$drive.Type,(Format-DiskSize $drive.Total),(Format-DiskSize $drive.Used),(Format-DiskSize $drive.Free),$drive.Detail)
        }
        Write-Host ' [F] Scan a folder path   [0] Exit'
        Write-Host 'A full-drive scan can take minutes. Junctions/symlinks are skipped; Ctrl+C cancels.' -ForegroundColor DarkGray
        $answer=Read-Host 'Select drive or F'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        try {
            $scanPath=$null
            if ($answer.Trim() -eq 'F') { $scanPath=Read-Host 'Folder path'; if ([string]::IsNullOrWhiteSpace($scanPath)) { continue } }
            else {
                $number=0
                if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $drives.Count) { throw 'Choose a listed drive.' }
                if (-not $drives[$number-1].Ready) { throw 'Drive is not ready.' }
                $scanPath=$drives[$number-1].Drive
            }
            Show-DiskScan (Measure-DiskTree $scanPath)
        } catch { Write-Warning $_.Exception.Message }
    }
}

if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'PowerShell 5.0+ is required.' }
if (-not $NoMenu) { Start-DiskUsage $Path }
