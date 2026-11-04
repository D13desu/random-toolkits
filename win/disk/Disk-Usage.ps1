# Random Toolkits | Disk Usage 0.2.0 | PowerShell 5.0+
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

function Measure-DiskTreeFallback {
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

function Initialize-DiskScanner {
    if ('RandomToolkits.DiskV2.Scanner' -as [type]) { return }
    Write-Host 'Preparing native scanner (compiled once per PowerShell process)...' -ForegroundColor DarkGray
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;
namespace RandomToolkits.DiskV2 {
 public class Node {
  public string Path, Parent; public long Bytes, Files, SeenBytes;
  public bool Partial; public List<string> Children = new List<string>();
  internal Node Top;
 }
 public class Issue { public string Path, Reason; }
 public class Row { public string Name, Path, Kind; public long Bytes; public bool Partial; }
 public class Scan {
  public string Root; public Dictionary<string,Node> Nodes = new Dictionary<string,Node>(StringComparer.OrdinalIgnoreCase);
  public long Files; public int IssueCount; public List<Issue> Issues = new List<Issue>();
  public DateTime Started = DateTime.Now, Finished; public string Engine = "Native Windows enumeration";
  public bool Cancelled;
 }
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] internal struct FindData {
  public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation, Access, Write;
  public uint SizeHigh, SizeLow, Reserved0, Reserved1;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string Name;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=14)] public string Alternate;
 }
 public class Scanner {
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr FindFirstFileExW(string path,int level,out FindData data,int search,IntPtr filter,int flags);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool FindNextFileW(IntPtr handle,out FindData data);
  [DllImport("kernel32.dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool FindClose(IntPtr handle);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFileAttributesW(string path);
  const uint Reparse=0x400, DirectoryFlag=0x10;
  static readonly IntPtr Invalid = new IntPtr(-1);
  public readonly Scan Result = new Scan();
  public volatile bool Done, CancelRequested;
  public string Error; public long FilesSeen, BytesSeen; public int DirectoriesSeen;
  readonly object gate = new object(); readonly List<Node> tops = new List<Node>();
  public static string NativePath(string path) {
   if(path.StartsWith(@"\\?\")) return path;
   if(path.StartsWith(@"\\")) return @"\\?\UNC\" + path.Substring(2);
   return @"\\?\" + path;
  }
  static string Child(string parent,string name) { return parent.TrimEnd('\\') + @"\" + name; }
  static IntPtr Open(string path,out FindData data) {
   IntPtr handle=FindFirstFileExW(Child(NativePath(path),"*"),1,out data,0,IntPtr.Zero,2);
   if(handle==Invalid && Marshal.GetLastWin32Error()==87)
    handle=FindFirstFileExW(Child(NativePath(path),"*"),1,out data,0,IntPtr.Zero,0);
   return handle;
  }
  void Issue(Node node,string path,string reason) {
   node.Partial=true; Result.IssueCount++;
   if(Result.Issues.Count<100) Result.Issues.Add(new Issue {Path=path,Reason=reason});
  }
  public static Scanner Start(string root) {
   Scanner scanner=new Scanner(); scanner.Result.Root=root;
   Thread thread=new Thread(scanner.Run); thread.IsBackground=true; thread.Start(); return scanner;
  }
  public Row[] Snapshot() {
   lock(gate) {
    List<Row> rows=new List<Row>();
    foreach(Node node in tops) rows.Add(new Row {Name=System.IO.Path.GetFileName(node.Path),Path=node.Path,Kind="DIR",Bytes=Interlocked.Read(ref node.SeenBytes),Partial=true});
    rows.Sort(delegate(Row a,Row b) {return b.Bytes.CompareTo(a.Bytes);});
    if(rows.Count>5) rows.RemoveRange(5,rows.Count-5); return rows.ToArray();
   }
  }
  void Run() {
   try {
    Node root=new Node {Path=Result.Root}; Result.Nodes.Add(root.Path,root);
    Stack<Node> pending=new Stack<Node>(); pending.Push(root); List<Node> order=new List<Node>();
    while(pending.Count>0 && !CancelRequested) {
     Node node=pending.Pop(); order.Add(node); Interlocked.Increment(ref DirectoriesSeen);
     uint attrs=GetFileAttributesW(NativePath(node.Path));
     if(attrs==0xffffffff) {Issue(node,node.Path,new Win32Exception(Marshal.GetLastWin32Error()).Message);continue;}
     if((attrs&Reparse)!=0) {Issue(node,node.Path,"Directory became a reparse point; skipped.");continue;}
     FindData data; IntPtr handle=Open(node.Path,out data);
     if(handle==Invalid) {int code=Marshal.GetLastWin32Error(); if(code!=2 && code!=18) Issue(node,node.Path,new Win32Exception(code).Message);continue;}
     try {
      do {
       if(CancelRequested) break;
       if(data.Name=="." || data.Name=="..") continue;
       string path=Child(node.Path,data.Name);
       if((data.Attributes&Reparse)!=0) {Issue(node,path,"Reparse point skipped (junction, symlink, or cloud placeholder).");continue;}
       if((data.Attributes&DirectoryFlag)!=0) {
        Node child=new Node {Path=path,Parent=node.Path}; child.Top=node.Top ?? child;
        Result.Nodes.Add(path,child); node.Children.Add(path); pending.Push(child);
        if(node==root) {lock(gate) {tops.Add(child);}}
       } else {
        long size=((long)data.SizeHigh<<32)|data.SizeLow;
        node.Bytes+=size; node.Files++;
       }
      } while(FindNextFileW(handle,out data));
      int code=Marshal.GetLastWin32Error();
      if(!CancelRequested && code!=18) Issue(node,node.Path,new Win32Exception(code).Message);
     } finally {FindClose(handle);}
     Interlocked.Add(ref FilesSeen,node.Files); Interlocked.Add(ref BytesSeen,node.Bytes);
     if(node.Top!=null) Interlocked.Add(ref node.Top.SeenBytes,node.Bytes);
    }
    if(CancelRequested) {
     Result.Cancelled=true;
     foreach(Node node in Result.Nodes.Values) node.Partial=true;
     Issue(root,root.Path,"Scan stopped early; unvisited folders have incomplete totals.");
    }
    for(int i=order.Count-1;i>=0;i--) {
     Node node=order[i]; if(node.Parent==null) continue;
     Node parent=Result.Nodes[node.Parent]; parent.Bytes+=node.Bytes; parent.Files+=node.Files;
     if(node.Partial) parent.Partial=true;
    }
    Result.Files=root.Files; Result.Finished=DateTime.Now;
   } catch(Exception ex) {Error=ex.ToString();}
   finally {Done=true;}
  }
  public static Row[] Children(Scan scan,string path) {
   Node node=scan.Nodes[path]; List<Row> rows=new List<Row>();
   foreach(string childPath in node.Children) {
    Node child=scan.Nodes[childPath]; rows.Add(new Row {Name=System.IO.Path.GetFileName(childPath),Path=childPath,Kind="DIR",Bytes=child.Bytes,Partial=child.Partial});
   }
   uint attrs=GetFileAttributesW(NativePath(path));
   if(attrs==0xffffffff) throw new Win32Exception(Marshal.GetLastWin32Error());
   if((attrs&Reparse)!=0) throw new IOException("Directory became a reparse point; rescan its parent.");
   FindData data; IntPtr handle=Open(path,out data);
   if(handle==Invalid) {int code=Marshal.GetLastWin32Error(); if(code!=2 && code!=18) throw new Win32Exception(code);}
   else try {
    do { if((data.Attributes&(Reparse|DirectoryFlag))==0) rows.Add(new Row {Name=data.Name,Path=Child(path,data.Name),Kind="FILE",Bytes=((long)data.SizeHigh<<32)|data.SizeLow}); }
    while(FindNextFileW(handle,out data));
    int code=Marshal.GetLastWin32Error(); if(code!=18) throw new Win32Exception(code);
   } finally {FindClose(handle);}
   rows.Sort(delegate(Row a,Row b) {int cmp=b.Bytes.CompareTo(a.Bytes); return cmp!=0?cmp:StringComparer.OrdinalIgnoreCase.Compare(a.Name,b.Name);});
   return rows.ToArray();
  }
 }
}
'@
}

function Measure-DiskTree {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath,
          [ValidateSet('Auto','Native','PowerShell')][string]$Engine='Auto')
    if ($Engine -eq 'PowerShell') { return Measure-DiskTreeFallback $LiteralPath }
    try { Initialize-DiskScanner }
    catch {
        if ($Engine -eq 'Native') { throw }
        Write-Warning ('Native scanner unavailable; using slower PowerShell fallback: '+$_.Exception.Message)
        return Measure-DiskTreeFallback $LiteralPath
    }
    $root=Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($root -isnot [IO.DirectoryInfo]) { throw 'Select a filesystem directory or drive root.' }
    if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Select the real directory, not a junction or symbolic link.' }
    $worker=[RandomToolkits.DiskV2.Scanner]::Start($root.FullName)
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $lastPreview=0L
    try {
        while (-not $worker.Done) {
            Write-Progress -Activity 'Fast disk scan (read-only)' -Status ("{0:N0} files | {1:N0} folders | {2} found | {3:N1}s" -f $worker.FilesSeen,$worker.DirectoriesSeen,(Format-DiskSize $worker.BytesSeen),$timer.Elapsed.TotalSeconds)
            if ($timer.ElapsedMilliseconds-$lastPreview -ge 3000) {
                Write-Host ("`nLIVE / INCOMPLETE: {0:N0} files, {1} found so far. Q stops and shows partial results." -f $worker.FilesSeen,(Format-DiskSize $worker.BytesSeen)) -ForegroundColor Cyan
                foreach ($row in $worker.Snapshot()) { Write-Host (' {0,12}  {1}' -f (Format-DiskSize $row.Bytes),$row.Name) }
                $lastPreview=$timer.ElapsedMilliseconds
            }
            try {
                if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
                    if ([Console]::ReadKey($true).Key -eq 'Q') { $worker.CancelRequested=$true }
                }
            } catch { } # Console key polling is unavailable in some remote hosts.
            Start-Sleep -Milliseconds 100
        }
        if ($worker.Error) { throw $worker.Error }
        return $worker.Result
    } finally {
        $worker.CancelRequested=$true
        Write-Progress -Activity 'Fast disk scan (read-only)' -Completed
        $timer.Stop()
    }
}

function Get-DiskChildren {
    param($Scan,[string]$LiteralPath)
    if ($Scan.GetType().FullName -eq 'RandomToolkits.DiskV2.Scan') {
        try { return [RandomToolkits.DiskV2.Scanner]::Children($Scan,$LiteralPath) }
        catch {
            Write-Warning ('Cannot read the current file listing; showing cached folders only: '+$_.Exception.Message)
            foreach ($childPath in $Scan.Nodes[$LiteralPath].Children) {
                $child=$Scan.Nodes[$childPath]
                [pscustomobject]@{Name=[IO.Path]::GetFileName($childPath);Path=$childPath;Kind='DIR';Bytes=$child.Bytes;Partial=$true}
            }
            return
        }
    }
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
    $loadedPath=$null
    :browse while ($true) {
        $node = $Scan.Nodes[$current]
        if ($loadedPath -ne $current) { $rows = @(Get-DiskChildren $Scan $current); $loadedPath=$current }
        $pages = [math]::Max(1,[math]::Ceiling($rows.Count/20.0))
        $page = [math]::Min($page,$pages-1)
        Write-Host "`n DISK USAGE | $current" -ForegroundColor Cyan
        Write-Host ("Logical size: {0} | Files: {1:N0} | Scan exclusions/errors: {2}" -f (Format-DiskSize $node.Bytes),$node.Files,$Scan.IssueCount)
        if ($node.Partial) { Write-Host 'PARTIAL TOTAL: inaccessible or excluded entries exist below this folder.' -ForegroundColor Yellow }
        Write-Host 'Folder totals and current listing are cached. Rescan after filesystem changes.' -ForegroundColor DarkGray
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
            'R' { $Scan=Measure-DiskTree $Scan.Root; $current=$Scan.Root; $page=0; $loadedPath=$null; continue browse }
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
        Write-Host "`n RANDOM TOOLKITS | DISK USAGE 0.2.0 | READ ONLY" -ForegroundColor Cyan
        for ($i=0; $i -lt $drives.Count; $i++) {
            $drive=$drives[$i]
            Write-Host (' [{0}] {1} {2} | Total {3} | Used {4} | Free {5} | {6}' -f ($i+1),$drive.Drive,$drive.Type,(Format-DiskSize $drive.Total),(Format-DiskSize $drive.Used),(Format-DiskSize $drive.Free),$drive.Detail)
        }
        Write-Host ' [F] Scan a folder path   [0] Exit'
        Write-Host 'Native metadata scan with live partial totals. Q: stop and browse partial results; Ctrl+C: exit. Links are skipped.' -ForegroundColor DarkGray
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
