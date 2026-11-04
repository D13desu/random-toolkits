# Random Toolkits | Disk Usage 0.4.0 | PowerShell 5.0+
[CmdletBinding()]
param([switch]$NoMenu, [string]$Path)

function Format-DiskSize {
    param([double]$Bytes)
    if ($Bytes -lt 0) { return ('-'+(Format-DiskSize (-$Bytes))) }
    foreach ($unit in @('B','KiB','MiB','GiB','TiB','PiB')) {
        if ($Bytes -lt 1024 -or $unit -eq 'PiB') { return ('{0:N1} {1}' -f $Bytes,$unit) }
        $Bytes /= 1024
    }
}

function Format-DiskAllocation {
    param([long]$Bytes,[bool]$Unknown)
    if ($Unknown -and $Bytes -eq 0) { return 'Unknown' }
    if ($Unknown) { return ('>= '+(Format-DiskSize $Bytes)) }
    return Format-DiskSize $Bytes
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

function Read-DiskDriveRoot {
    param([string]$DefaultDrive)
    $prompt='NTFS drive root (for example C:\)'
    if ($DefaultDrive) { $prompt="NTFS drive root [Enter = $DefaultDrive]" }
    $answer=Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultDrive }
    return $answer.Trim()
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
    if ('RandomToolkits.DiskV7.Scanner' -as [type]) { return }
    Write-Host 'Preparing native scanner (compiled once per PowerShell process)...' -ForegroundColor DarkGray
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;
namespace RandomToolkits.DiskV7 {
 public class Node {
  public string ReparseTag;
  public long Allocated; public bool AllocationUnknown;
  public string Path, Parent; public long Bytes, Files, SeenBytes;
  public bool Partial; public List<string> Children = new List<string>();
  internal Node Top;
 }
 public class Issue { public string Path, Reason, Category; }
 public class Row { public string Name, Path, Kind, ReparseTag; public long Bytes, Allocated; public bool Partial, AllocationUnknown; }
 public class Scan {
  public Dictionary<string,int> IssueCounts = new Dictionary<string,int>();
  public long MftOmittedFiles, MftOmittedDirectories, MftRecordErrors, MftRecordsRead;
  public long MftCloudFiles, MftCloudBytes;
  public long MftContainerFiles, MftContainerBytes, MftContainerAllocated, MftUnknownAllocations;
  public long MftReparseFiles, MftReparseDirectories, MftUnknownTags;
  public long VolumeUsed=-1;
  public Dictionary<string,List<Row>> CachedRows;
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
// BEGIN EMBEDDED MFT SCANNER
// Embedded into Disk-Usage.ps1 by tests/Sync-DiskMft.ps1. No runtime download.
// Read-only Windows FSCTL_GET_NTFS_FILE_RECORD prototype; not a raw-sector reader.
namespace RandomToolkits.DiskV7 {
 public class MftStream { public string Name; public long Allocated; public bool Known; }
 public class MftName { public ulong Parent; public string Name; }
 public class MftRecord {
  public ulong Reference; public bool Directory, Reparse, Unsupported, HasData;
  public bool HasAttributeList, HasStandardInformation;
  public ulong BaseReference; public ushort LinkCount; public uint ReparseTag;
  public int NameAttributeCount;
  public string ExtensionIssue;
  public long UnnamedAllocated, Allocated;
  public bool UnnamedAllocationKnown=true, AllocationKnown, AllocationListKnown;
  public string AllocationIssue;
  public System.Collections.Generic.List<MftStream> NamedStreams;
  public System.Collections.Generic.List<string> ExpectedStreams;
  public System.Collections.Generic.List<ulong> ExtensionReferences;
  public long Bytes; public System.Collections.Generic.List<MftName> Names = new System.Collections.Generic.List<MftName>();
 }
 public class MftScanner {
  [System.Runtime.InteropServices.DllImport("kernel32.dll",CharSet=System.Runtime.InteropServices.CharSet.Unicode,SetLastError=true)]
  static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(string path,uint access,uint share,System.IntPtr security,uint creation,uint flags,System.IntPtr template);
  [System.Runtime.InteropServices.DllImport("kernel32.dll",SetLastError=true)]
  [return:System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
  static extern bool DeviceIoControl(Microsoft.Win32.SafeHandles.SafeFileHandle handle,uint code,byte[] input,int inputSize,byte[] output,int outputSize,out int returned,System.IntPtr overlapped);
  const ulong IndexMask=0x0000ffffffffffffUL;
  public Scan Result=new Scan(); public volatile bool Done, CancelRequested;
  public string Error; public long FilesSeen, BytesSeen, RecordsSeen; public int DirectoriesSeen;
  public Row[] Snapshot() { return new Row[0]; }
  static ushort U16(byte[] b,int p) { return System.BitConverter.ToUInt16(b,p); }
  static uint U32(byte[] b,int p) { return System.BitConverter.ToUInt32(b,p); }
  static ulong U64(byte[] b,int p) { return System.BitConverter.ToUInt64(b,p); }
  static void Need(bool valid) { if(!valid) throw new System.IO.InvalidDataException("Invalid or unsupported NTFS record bounds."); }
  // The FSCTL returns a filesystem-managed record. It does not require raw-sector USA fixups.
  public static MftRecord Parse(byte[] b,ulong index) {
   Need(b!=null && b.Length>=48 && U32(b,0)==0x454c4946);
   if((U16(b,22)&1)==0) return null;
   int used=checked((int)U32(b,24)), p=U16(b,20);
   Need(used<=b.Length && used>=48 && p>=48 && p<=used-4);
   MftRecord r=new MftRecord {Reference=(index&IndexMask)|((ulong)U16(b,16)<<48),Directory=(U16(b,22)&2)!=0,BaseReference=U64(b,32),LinkCount=U16(b,18)};
   bool end=false;
   while(p<=used-4) {
    uint type=U32(b,p); if(type==0xffffffff) {end=true;break;}
    Need(p<=used-16); int length=checked((int)U32(b,p+4));
    Need(length>=24 && length%8==0 && length<=used-p && b[p+8]<=1);
    bool nonresident=b[p+8]==1; int min=nonresident?64:24; Need(length>=min);
    if(b[p+9]!=0) {int no=U16(b,p+10);Need(no>=min && no+b[p+9]*2<=length);}
    int value=0, size=0;
    if(!nonresident) {size=checked((int)U32(b,p+16));value=U16(b,p+20);Need(value>=24 && value<=length && size<=length-value);}
    if(type==0x10) {
     // Standard information is resident in the base record. Its file attributes
     // identify reparses even when the reparse payload is in an extension record.
     Need(!nonresident && b[p+9]==0 && size>=36 && !r.HasStandardInformation);
     r.HasStandardInformation=true;
     if((U32(b,p+value+32)&0x400)!=0) r.Reparse=true;
    }
    if(type==0x20) {
     r.HasAttributeList=true;
     if(!nonresident && size>0) {
      r.ExpectedStreams=new System.Collections.Generic.List<string>();int q=p+value, limit=q+size;
      r.ExtensionReferences=new System.Collections.Generic.List<ulong>();
      while(q<limit) {
       Need(limit-q>=26);int entryLength=U16(b,q+4), chars=b[q+6], nameOffset=b[q+7];
       Need(entryLength>=26 && entryLength%8==0 && entryLength<=limit-q);
       Need(chars==0 || (nameOffset>=26 && nameOffset+chars*2<=entryLength));
       if(U32(b,q)==0x80 && U64(b,q+8)==0) r.ExpectedStreams.Add(chars==0?"":System.Text.Encoding.Unicode.GetString(b,q+nameOffset,chars*2));
       ulong reference=U64(b,q+16);if(reference!=r.Reference && !r.ExtensionReferences.Contains(reference)) r.ExtensionReferences.Add(reference);
       q+=entryLength;
      }
      r.AllocationListKnown=true;
     }
    }
    if(type==0xc0) {
     r.Reparse=true;
     if(!nonresident) {Need(size>=8 && U16(b,p+value+4)<=size-8);r.ReparseTag=U32(b,p+value);}
    }
    if(type==0x30) {
     Need(!nonresident && size>=66); int v=p+value, chars=b[v+64];
     Need(chars>0 && 66+chars*2<=size && b[v+65]<=3);
     r.NameAttributeCount++;
     if(b[v+65]!=2) { // DOS-only short name is an alias, not another hard link
      string name=System.Text.Encoding.Unicode.GetString(b,v+66,chars*2);
      Need(name.IndexOfAny(new char[]{'\\','/',':','\0'})<0 && name!="..");
      r.Names.Add(new MftName {Parent=U64(b,v),Name=name});
     }
    }
    if(type==0x80) {
     if(!nonresident || U64(b,p+16)==0) {
      string streamName=b[p+9]==0?"":System.Text.Encoding.Unicode.GetString(b,p+U16(b,p+10),b[p+9]*2);
      // Resident DATA consumes its padded payload slot inside the MFT record.
      // Windows reports that slot as stream allocation even without separate clusters.
      long allocation=nonresident?0:length-value;bool known=true;
      if(nonresident) {
       ushort flags=U16(b,p+12);bool packed=(flags&0x8001)!=0;
       if((flags&0xff)!=0 && (flags&0xff)!=1) known=false;
       else if(packed && (length<72 || U16(b,p+32)<72)) known=false;
       else {allocation=System.BitConverter.ToInt64(b,p+(packed?64:40));if(allocation<0) {known=false;allocation=0;}}
      }
      if(streamName.Length==0) {
       Need(!r.HasData); r.HasData=true;
       r.Bytes=nonresident?System.BitConverter.ToInt64(b,p+48):size; Need(r.Bytes>=0);
       r.UnnamedAllocated=allocation;r.UnnamedAllocationKnown=known;
      } else {
       if(r.NamedStreams==null) r.NamedStreams=new System.Collections.Generic.List<MftStream>();
       r.NamedStreams.Add(new MftStream {Name=streamName,Allocated=allocation,Known=known});
      }
     }
    }
    p+=length;
   }
   Need(end);
   // Directory sizes come from child records, not the directory's index extents.
   // A usable base filename plus authoritative reparse flags is sufficient to
   // connect this directory to the tree, even when its index spans extensions.
   // This is the base-only view; Assemble validates and joins extension metadata.
   r.Unsupported=r.HasAttributeList && (!r.Directory || !r.HasStandardInformation || r.Names.Count!=1);
   if(!r.Directory && !r.HasData) r.Unsupported=true;
   CalculateAllocation(r);
   return r;
  }
  public static void CalculateAllocation(MftRecord r) {
   r.Allocated=0;r.AllocationKnown=true;r.AllocationIssue=null;
   if(!r.HasAttributeList && r.NamedStreams==null) {
    r.AllocationKnown=r.UnnamedAllocationKnown && (r.Directory || r.HasData);
    if(r.HasData && r.UnnamedAllocationKnown) r.Allocated=r.UnnamedAllocated;
    if(!r.AllocationKnown) r.AllocationIssue="Unnamed stream allocation unavailable.";
    return;
   }
   var streams=new System.Collections.Generic.Dictionary<string,MftStream>(System.StringComparer.Ordinal);
   if(r.HasData) streams.Add("",new MftStream {Name="",Allocated=r.UnnamedAllocated,Known=r.UnnamedAllocationKnown});
   if(r.NamedStreams!=null) foreach(MftStream stream in r.NamedStreams) {
    if(streams.ContainsKey(stream.Name)) {streams[stream.Name]=new MftStream {Name=stream.Name,Known=false};}
    else streams.Add(stream.Name,stream);
   }
   foreach(MftStream stream in streams.Values) {
    if(stream.Known) r.Allocated=checked(r.Allocated+stream.Allocated);
    else {r.AllocationKnown=false;r.AllocationIssue="Missing, conflicting or unsupported stream allocation header.";}
   }
   if(r.HasAttributeList) {
    if(!r.AllocationListKnown || r.ExpectedStreams==null) {r.AllocationKnown=false;r.AllocationIssue="Attribute list is nonresident or unavailable; stream completeness is unknown.";}
    else {
     var expected=new System.Collections.Generic.HashSet<string>(r.ExpectedStreams,System.StringComparer.Ordinal);
     if(expected.Count!=r.ExpectedStreams.Count || !expected.SetEquals(streams.Keys)) {r.AllocationKnown=false;r.AllocationIssue="Data stream list does not match the assembled initial extents.";}
    }
   }
   if(!r.Directory && !r.HasData) {r.AllocationKnown=false;r.AllocationIssue="Unnamed data metadata unavailable.";}
  }
  public static bool IsContainer(MftRecord r) {return r.Reparse && (r.ReparseTag==0x80000018U || r.ReparseTag==0x90001018U);}
  static string Tag(MftRecord r) {return r.ReparseTag==0?"UnknownTag":"0x"+r.ReparseTag.ToString("X8");}
  public static MftRecord[] Assemble(MftRecord[] records) {
   var result=new System.Collections.Generic.List<MftRecord>();
   var bases=new System.Collections.Generic.Dictionary<ulong,MftRecord>();
   foreach(MftRecord r in records) {
    if(r==null || r.BaseReference!=0 || bases.ContainsKey(r.Reference)) continue;
    if(!r.HasAttributeList) {result.Add(r);continue;}
    // Clone only records being assembled; repeated builds must not append names twice.
    var copy=new MftRecord {Reference=r.Reference,Directory=r.Directory,Reparse=r.Reparse,Unsupported=r.Unsupported,HasData=r.HasData,HasAttributeList=true,HasStandardInformation=r.HasStandardInformation,LinkCount=r.LinkCount,NameAttributeCount=r.NameAttributeCount,ReparseTag=r.ReparseTag,Bytes=r.Bytes,UnnamedAllocated=r.UnnamedAllocated,UnnamedAllocationKnown=r.UnnamedAllocationKnown,AllocationListKnown=r.AllocationListKnown,ExpectedStreams=r.ExpectedStreams};
    if(r.NamedStreams!=null) copy.NamedStreams=new System.Collections.Generic.List<MftStream>(r.NamedStreams);
    copy.Names.AddRange(r.Names);bases.Add(copy.Reference,copy);result.Add(copy);
   }
   foreach(MftRecord extra in records) {
    if(extra==null || extra.BaseReference==0) continue;
    MftRecord owner;
    // Match the entire reference including sequence; never attach a stale extent
    // to a reused record slot. Missing data/names are detected below.
    if(!bases.TryGetValue(extra.BaseReference,out owner) || !owner.HasAttributeList) continue;
    owner.Names.AddRange(extra.Names);owner.NameAttributeCount+=extra.NameAttributeCount;owner.Reparse|=extra.Reparse;
    if(extra.ReparseTag!=0) {
     if(owner.ReparseTag!=0 && owner.ReparseTag!=extra.ReparseTag) owner.ExtensionIssue="Conflicting reparse tags in extension records.";
     owner.ReparseTag=extra.ReparseTag;
    }
    if(extra.HasStandardInformation) owner.ExtensionIssue="Unexpected standard information in an extension record.";
    if(extra.HasData) {
     if(owner.HasData) owner.ExtensionIssue="Multiple initial unnamed data attributes.";
     else {owner.HasData=true;owner.Bytes=extra.Bytes;owner.UnnamedAllocated=extra.UnnamedAllocated;owner.UnnamedAllocationKnown=extra.UnnamedAllocationKnown;}
    }
    if(extra.NamedStreams!=null) {if(owner.NamedStreams==null) owner.NamedStreams=new System.Collections.Generic.List<MftStream>();owner.NamedStreams.AddRange(extra.NamedStreams);}
   }
   foreach(MftRecord r in bases.Values) {
    if(!r.HasAttributeList) continue;
    var unique=new System.Collections.Generic.HashSet<string>(System.StringComparer.Ordinal);
    var names=new System.Collections.Generic.List<MftName>();
    foreach(MftName n in r.Names) if(unique.Add(n.Parent.ToString()+":"+n.Name)) names.Add(n);
    r.Names=names;
    // NTFS's header count includes separate DOS FILE_NAME attributes. Retain
    // those in the completeness check but never display/count them as extra files.
    r.Unsupported=r.ExtensionIssue!=null || !r.HasStandardInformation || r.Names.Count==0 ||
      (r.Directory ? r.Names.Count!=1 : (!r.HasData || r.LinkCount==0 || r.NameAttributeCount!=r.LinkCount));
    CalculateAllocation(r);
    if(r.ExtensionIssue!=null) {r.AllocationKnown=false;r.AllocationIssue=r.ExtensionIssue;}
   }
   return result.ToArray();
  }
  static void Issue(Scan scan,string path,string reason,string category="Other") {
   scan.IssueCount++; scan.Nodes[scan.Root].Partial=true;
   int count;scan.IssueCounts.TryGetValue(category,out count);scan.IssueCounts[category]=count+1;
   // Reserve examples for every cause instead of filling all slots with one repeated failure.
   if(count<4 && scan.Issues.Count<100) scan.Issues.Add(new Issue {Path=path,Reason=reason,Category=category});
  }
  static string Describe(MftRecord r) {
   return "MFT #"+(r.Reference&IndexMask)+" (sequence "+(r.Reference>>48)+", name: "+(r.Names.Count==0?"<none>":r.Names[0].Name)+")";
  }
  // Deterministic ownership: a hard-linked file is charged to its first ordinal path only.
  // Other links remain visible with zero charged bytes, labelled LINK.
  public static Scan Build(string root,MftRecord[] records,bool cancelled) {
   // This is a graph of local MFT parent IDs. Reparse payloads and target paths
   // are never followed. Their own local DATA allocation can therefore be counted
   // even when the tag is unknown, without traversing a junction or hydrating data.
   records=Assemble(records);
   Scan s=new Scan {Root=root,Engine="Experimental NTFS MFT records",Cancelled=cancelled};
   s.CachedRows=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.List<Row>>(System.StringComparer.OrdinalIgnoreCase);
   s.Nodes.Add(root,new Node {Path=root}); s.CachedRows.Add(root,new System.Collections.Generic.List<Row>());
   var dirs=new System.Collections.Generic.Dictionary<ulong,MftRecord>();
   var paths=new System.Collections.Generic.Dictionary<ulong,string>();
   var pending=new System.Collections.Generic.List<MftRecord>();
   var blocked=new System.Collections.Generic.Dictionary<ulong,Issue>();
   foreach(MftRecord r in records) {
    if(r==null) continue;
    if((r.Reference&IndexMask)==5) {paths[r.Reference]=root;continue;}
    if((r.Reference&IndexMask)<16) continue; // NTFS system records are not user file totals
    if(r.Directory) {if(!dirs.ContainsKey(r.Reference)) {dirs.Add(r.Reference,r);pending.Add(r);}}
   }
   if(paths.Count==0) Issue(s,root,"Root record missing; paths cannot be reconstructed.");
   // Resolve paths without recursive stack growth. Reject missing/reused parents and cycles.
   foreach(MftRecord start in pending) {
    if(paths.ContainsKey(start.Reference)) continue;
    var chain=new System.Collections.Generic.List<MftRecord>(); var seen=new System.Collections.Generic.HashSet<ulong>();
    MftRecord cur=start; bool valid=true;Issue failure=null;
    while(!paths.ContainsKey(cur.Reference)) {
     if(blocked.TryGetValue(cur.Reference,out failure)) {valid=false;break;}
     if(!seen.Add(cur.Reference)) failure=new Issue {Category="DirectoryCycle",Reason="Parent cycle at "+Describe(cur)};
     else if(cur.Unsupported) failure=new Issue {Category="DirectoryAttributeList",Reason="Incomplete/conflicting extension metadata: "+Describe(cur)+"; "+(cur.ExtensionIssue??"missing name or base standard flags")};
     else if(cur.Names.Count!=1) failure=new Issue {Category="DirectoryNames",Reason="Expected one directory name; found "+cur.Names.Count+" on "+Describe(cur)};
     if(failure!=null) {blocked[cur.Reference]=failure;valid=false;break;}
     chain.Add(cur); ulong parent=cur.Names[0].Parent;
     if(paths.ContainsKey(parent)) break;
     MftRecord parentRecord;
     if(!dirs.TryGetValue(parent,out parentRecord)) {
      bool metadata=(parent&IndexMask)<16;
      failure=new Issue {Category=metadata?"DirectorySystemMetadata":"DirectoryParentMissing",Reason=Describe(cur)+" requires parent MFT #"+(parent&IndexMask)+" (sequence "+(parent>>48)+"). "+(metadata?"NTFS system metadata tree intentionally excluded.":"Parent absent, changed or unparsed.")};valid=false;break;
     }
     cur=parentRecord;
    }
    if(!valid) {
     foreach(MftRecord r in chain) blocked[r.Reference]=failure;
     blocked[start.Reference]=failure;s.MftOmittedDirectories++;
     Issue(s,Describe(start),failure.Reason,failure.Category);continue;
    }
    for(int i=chain.Count-1;i>=0;i--) {
     MftRecord r=chain[i]; string parent=paths[r.Names[0].Parent]; string path=parent.TrimEnd('\\')+"\\"+r.Names[0].Name;
     if(s.Nodes.ContainsKey(path)) {valid=false;break;}
     paths.Add(r.Reference,path); s.Nodes.Add(path,new Node {Path=path,Parent=parent,Allocated=r.Allocated,AllocationUnknown=!r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null});
     s.Nodes[parent].Children.Add(path); s.CachedRows.Add(path,new System.Collections.Generic.List<Row>());
     if(r.Reparse) {s.MftReparseDirectories++;if(r.ReparseTag==0) s.MftUnknownTags++;}
     if(!r.AllocationKnown) {s.MftUnknownAllocations++;Issue(s,Describe(r),r.AllocationIssue,"AllocationUnknown");}
    }
    if(!valid) {s.MftOmittedDirectories++;Issue(s,Describe(start),"Duplicate directory path; volume may have changed during scan.","DuplicateDirectory");}
   }
   var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);
   foreach(MftRecord r in records) {
    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;
    if(r.Unsupported) {s.MftOmittedFiles++;Issue(s,Describe(r),"Incomplete/conflicting metadata: data="+r.HasData+", standardInfo="+r.HasStandardInformation+", name attributes="+r.NameAttributeCount+", header count="+r.LinkCount+"; "+r.ExtensionIssue,"FileUnsupported");continue;}
    var names=new System.Collections.Generic.SortedDictionary<string,string>(System.StringComparer.Ordinal);
    string linkFailure=null;
    foreach(MftName n in r.Names) {
     string parent; if(!paths.TryGetValue(n.Parent,out parent)) {
      Issue cause;
      if(linkFailure==null) linkFailure="Unresolved parent MFT #"+(n.Parent&IndexMask)+" (sequence "+(n.Parent>>48)+") for "+n.Name+(blocked.TryGetValue(n.Parent,out cause)?"; "+cause.Reason:"; parent absent or changed.");
      continue;
     }
     string path=parent.TrimEnd('\\')+"\\"+n.Name; names[path]=parent;
    }
    bool charged=false;
    foreach(var pair in names) {
     if(!occupied.Add(pair.Key)) {if(linkFailure==null) linkFailure="Duplicate path: "+pair.Key+"; file may have changed during scanning.";continue;}
     long bytes=charged?0:r.Bytes; var node=s.Nodes[pair.Value]; node.Bytes=checked(node.Bytes+bytes);
     long allocated=charged?0:r.Allocated;node.Allocated=checked(node.Allocated+allocated);
     if(!charged) {
      node.Files++;s.Files++;
      if(r.Reparse && (r.ReparseTag&0xffff0fffU)==0x9000001aU) {s.MftCloudFiles++;s.MftCloudBytes=checked(s.MftCloudBytes+r.Bytes);}
      if(IsContainer(r)) {s.MftContainerFiles++;s.MftContainerBytes=checked(s.MftContainerBytes+r.Bytes);s.MftContainerAllocated=checked(s.MftContainerAllocated+r.Allocated);}
      if(r.Reparse) {s.MftReparseFiles++;if(r.ReparseTag==0) s.MftUnknownTags++;}
      if(!r.AllocationKnown) {node.AllocationUnknown=true;s.MftUnknownAllocations++;Issue(s,Describe(r),r.AllocationIssue,"AllocationUnknown");}
     }
     s.CachedRows[pair.Value].Add(new Row {Name=System.IO.Path.GetFileName(pair.Key),Path=pair.Key,Kind=charged?"LINK":(IsContainer(r)?"WCI":(r.Reparse?"RP":"FILE")),Bytes=bytes,Allocated=allocated,AllocationUnknown=!charged && !r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null}); charged=true;
    }
    if(!charged) s.MftOmittedFiles++;
    // At most one diagnostic per file: do not count each missing parent and then count the file again.
    if(linkFailure!=null || !charged) Issue(s,Describe(r),linkFailure??"No resolvable filename; file omitted.",charged?"PartialFileLinks":"FilePathUnresolved");
   }
   var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);
   order.Sort(delegate(Node a,Node b){return b.Path.Length.CompareTo(a.Path.Length);});
   foreach(Node n in order) if(n.Parent!=null) {Node parent=s.Nodes[n.Parent];parent.Bytes=checked(parent.Bytes+n.Bytes);parent.Allocated=checked(parent.Allocated+n.Allocated);parent.AllocationUnknown|=n.AllocationUnknown;parent.Files+=n.Files;}
   // Unresolved records cannot reliably be attributed to a folder: conservatively flag all totals.
   if(cancelled) Issue(s,root,"Cancelled: only records read so far are included; unresolved paths are omitted.");
   if(s.IssueCount>0) foreach(Node n in s.Nodes.Values) n.Partial=true;
   foreach(Node n in s.Nodes.Values) {
    foreach(string p in n.Children) {Node child=s.Nodes[p];s.CachedRows[n.Path].Add(new Row {Name=System.IO.Path.GetFileName(p),Path=p,Kind="DIR",Bytes=child.Bytes,Allocated=child.Allocated,AllocationUnknown=child.AllocationUnknown,Partial=child.Partial,ReparseTag=child.ReparseTag});}
    s.CachedRows[n.Path].Sort(delegate(Row a,Row b){int c=b.Allocated.CompareTo(a.Allocated);return c!=0?c:System.StringComparer.Ordinal.Compare(a.Name,b.Name);});
   }
   s.Finished=System.DateTime.Now; return s;
  }
  public static MftScanner Start(string root) {
   MftScanner w=new MftScanner();w.Result.Root=root;
   var t=new System.Threading.Thread(w.Run);t.IsBackground=true;t.Start();return w;
  }
  // Targeted validation of newly created fixture files, not a whole-volume scan.
  public static MftRecord[] ReadRecordsForValidation(string root,ulong[] references) {
   if(root.Length!=3 || root[1]!=':' || root[2]!='\\' || references.Length>128) throw new System.ArgumentException("Invalid bounded record request.");
   var records=new System.Collections.Generic.List<MftRecord>();var seen=new System.Collections.Generic.HashSet<ulong>();
   var queue=new System.Collections.Generic.Queue<ulong>(references);
   using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
    if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    byte[] volume=new byte[128];int returned;
    if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    Need(returned>=104 && U16(volume,100)==3 && U16(volume,102)<=1);
    int recordSize=checked((int)U32(volume,48));Need(recordSize>=512 && recordSize<=65536);byte[] output=new byte[recordSize+16];
    while(queue.Count>0) {
     ulong reference=queue.Dequeue();if(!seen.Add(reference)) continue;Need(seen.Count<=128);
     byte[] input=System.BitConverter.GetBytes(reference&IndexMask);
     if(!DeviceIoControl(handle,0x90068,input,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12 && (U64(output,0)&IndexMask)==(reference&IndexMask));int size=checked((int)U32(output,8));Need(size>=48 && size<=recordSize && size<=returned-12);
     byte[] bytes=new byte[size];System.Buffer.BlockCopy(output,12,bytes,0,size);MftRecord r=Parse(bytes,reference&IndexMask);
     Need(r!=null && ((reference>>48)==0 || r.Reference==reference));records.Add(r);
     if(r.ExtensionReferences!=null) foreach(ulong extra in r.ExtensionReferences) queue.Enqueue(extra);
    }
   }
   return Assemble(records.ToArray());
  }
  // Bounded read-only diagnostic: inspect one record and its parent chain, not a full scan.
  public static string[] Inspect(string root,ulong index) {
   if(root.Length!=3 || root[1]!=':' || root[2]!='\\') throw new System.ArgumentException("Select a local drive root.");
   var lines=new System.Collections.Generic.List<string>();var seen=new System.Collections.Generic.HashSet<ulong>();
   using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
    if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    byte[] volume=new byte[128];int returned;
    if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    Need(returned>=104 && U16(volume,100)==3 && U16(volume,102)<=1);
    int recordSize=checked((int)U32(volume,48));Need(recordSize>=512 && recordSize<=65536);
    byte[] output=new byte[recordSize+16];ulong expectedReference=0;
    for(int depth=0;depth<64;depth++) {
     if(!seen.Add(index)) {lines.Add("Parent cycle detected.");break;}
     byte[] input=System.BitConverter.GetBytes(index);
     if(!DeviceIoControl(handle,0x90068,input,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12);ulong actual=U64(output,0)&IndexMask;int size=checked((int)U32(output,8));Need(size>=48 && size<=recordSize && size<=returned-12);
     byte[] record=new byte[size];System.Buffer.BlockCopy(output,12,record,0,size);
     lines.Add("Requested #"+index+"; returned #"+actual+"; header record number="+U32(record,44)+"; flags="+U16(record,22)+"; base reference="+U64(record,32));
     if(actual!=index) {lines.Add("Requested record no longer in use; stopping at nearest record returned by Windows.");break;}
     MftRecord r;
     try {r=Parse(record,actual);} catch(System.Exception ex) {lines.Add("Parse failed: "+ex.Message);break;}
     if(r==null) {lines.Add("Extension or unused record; no standalone path.");break;}
     lines.Add(Describe(r)+"; directory="+r.Directory+"; reparse="+r.Reparse+"; tag="+Tag(r)+"; baseOnlyUnsupported="+r.Unsupported+"; attributeList="+r.HasAttributeList+"; standardInfo="+r.HasStandardInformation+"; data="+r.HasData+"; names="+r.Names.Count+"; links="+r.LinkCount);
     if(r.HasAttributeList) lines.Add("Base-record view only: a full scan assembles names/data from matching extension records.");
     foreach(MftName n in r.Names) lines.Add("  Name="+n.Name+"; parent #"+(n.Parent&IndexMask)+"; parent sequence="+(n.Parent>>48));
     if(expectedReference!=0 && r.Reference!=expectedReference) {lines.Add("Parent sequence mismatch: record was reused or changed.");break;}
     if(actual==5 || r.Names.Count!=1) break;
     expectedReference=r.Names[0].Parent;index=expectedReference&IndexMask;
     if(depth==63) lines.Add("Stopped at diagnostic depth limit (64).");
    }
   }
   return lines.ToArray();
  }
  void Run() {
   string root=Result.Root; System.DateTime started=System.DateTime.Now;
   try {
    if(root.Length!=3 || root[1]!=':' || root[2]!='\\') throw new System.ArgumentException("MFT mode requires a drive root, e.g. C:\\.");
    using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
     if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     byte[] volume=new byte[128];int returned;
     if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=104 && U32(volume,96)>=8 && U16(volume,100)==3 && U16(volume,102)<=1);
     int recordSize=checked((int)U32(volume,48)); long length=System.BitConverter.ToInt64(volume,56);
     Need(recordSize>=512 && recordSize<=65536 && length>=recordSize && length%recordSize==0);
     ulong next=(ulong)(length/recordSize-1);byte[] output=new byte[recordSize+16];
     var records=new System.Collections.Generic.List<MftRecord>();var errors=new System.Collections.Generic.List<string>();int errorCount=0;
     // Seed the root before descending so cancellation can still resolve top-level names.
     byte[] rootInput=System.BitConverter.GetBytes((ulong)5);
     if(!DeviceIoControl(handle,0x90068,rootInput,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12 && (U64(output,0)&IndexMask)==5);int rootSize=checked((int)U32(output,8));
     Need(rootSize>=48 && rootSize<=recordSize && rootSize<=returned-12);
     byte[] rootRecord=new byte[rootSize];System.Buffer.BlockCopy(output,12,rootRecord,0,rootSize);
     MftRecord rootEntry=Parse(rootRecord,5);Need(rootEntry!=null && rootEntry.Directory);records.Add(rootEntry);
     while(!CancelRequested) {
      byte[] input=System.BitConverter.GetBytes(next);
      if(!DeviceIoControl(handle,0x90068,input,input.Length,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
      Need(returned>=12);ulong actual=U64(output,0)&IndexMask;int size=checked((int)U32(output,8));
      Need(actual<=next && size>=48 && size<=recordSize && size<=returned-12);
      byte[] record=new byte[size];System.Buffer.BlockCopy(output,12,record,0,size);
      try {MftRecord r=Parse(record,actual);if(r!=null && actual!=5) {records.Add(r);if(r.BaseReference==0) {if(r.Directory) DirectoriesSeen++;else {System.Threading.Interlocked.Increment(ref FilesSeen);System.Threading.Interlocked.Add(ref BytesSeen,r.Bytes);}}}}
      catch(System.IO.InvalidDataException ex) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": "+ex.Message);}
      catch(System.OverflowException) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": oversized record field.");}
      System.Threading.Interlocked.Increment(ref RecordsSeen);
      if(actual==0) break;next=actual-1;
     }
     Result=Build(root,records.ToArray(),CancelRequested);Result.Started=started;
     try {var drive=new System.IO.DriveInfo(root);Result.VolumeUsed=drive.TotalSize-drive.TotalFreeSpace;} catch { }
     if(CancelRequested && !Result.Cancelled) {
      Result.Cancelled=true;Issue(Result,root,"Cancellation requested during tree reconstruction.");
      foreach(Node n in Result.Nodes.Values) n.Partial=true;
      foreach(var list in Result.CachedRows.Values) foreach(Row row in list) row.Partial=true;
     }
     if(errorCount>0) {
      foreach(string e in errors) Issue(Result,root,e,"RecordParseFailure");
      Result.IssueCount+=errorCount-errors.Count;Result.IssueCounts["RecordParseFailure"]=errorCount;
      foreach(Node n in Result.Nodes.Values) n.Partial=true;
      foreach(var list in Result.CachedRows.Values) foreach(Row row in list) row.Partial=true;
     }
     Result.MftRecordErrors=errorCount;Result.MftRecordsRead=RecordsSeen;
    }
   } catch(System.Exception ex) {Error=ex.Message;}
   finally {Done=true;}
  }
 }
}
// END EMBEDDED MFT SCANNER
'@
}

function Get-DiskMftUnavailableReason {
    param([string]$LiteralPath)
    $root=[IO.Path]::GetFullPath($LiteralPath)
    if ($root -notmatch '^[A-Za-z]:\\$') { return 'Select a local drive root (for example C:\), not a folder or network share.' }
    $drive=[IO.DriveInfo]::new($root)
    if (-not $drive.IsReady -or $drive.DriveType -notin @('Fixed','Removable') -or $drive.DriveFormat -ne 'NTFS') { return 'Requires a ready local NTFS volume.' }
    if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { return 'Requires an administrator PowerShell session.' }
}

function Measure-DiskTree {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath,
          [ValidateSet('Auto','Native','PowerShell','Mft')][string]$Engine='Auto')
    if ($Engine -eq 'Mft') {
        $reason=Get-DiskMftUnavailableReason $LiteralPath
        if ($reason) { Write-Warning ("MFT unavailable: $reason Using the standard scanner."); return Measure-DiskTree $LiteralPath -Engine Auto }
    }
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
    if ($Engine -eq 'Mft') {
        Write-Host 'EXPERIMENTAL: reading MFT records. Whole volume; metadata may include protected filenames. No filesystem snapshot.' -ForegroundColor Yellow
        $worker=[RandomToolkits.DiskV7.MftScanner]::Start($root.FullName)
    } else { $worker=[RandomToolkits.DiskV7.Scanner]::Start($root.FullName) }
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
        if ($worker.Error) {
            if ($Engine -eq 'Mft') { Write-Warning ('MFT scan failed; using the standard scanner: '+$worker.Error); return Measure-DiskTree $LiteralPath -Engine Auto }
            throw $worker.Error
        }
        return $worker.Result
    } finally {
        $worker.CancelRequested=$true
        Write-Progress -Activity 'Fast disk scan (read-only)' -Completed
        $timer.Stop()
    }
}

function Get-DiskChildren {
    param($Scan,[string]$LiteralPath)
    if ($Scan.PSObject.Properties['CachedRows'] -and $null -ne $Scan.CachedRows) { return $Scan.CachedRows[$LiteralPath].ToArray() }
    if ($Scan.GetType().FullName -eq 'RandomToolkits.DiskV7.Scan') {
        try { return [RandomToolkits.DiskV7.Scanner]::Children($Scan,$LiteralPath) }
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
        if ($Scan.PSObject.Properties['Engine']) { Write-Host ('Engine: '+$Scan.Engine) -ForegroundColor DarkGray }
        if ($Scan.PSObject.Properties['CachedRows'] -and $null -ne $Scan.CachedRows) {
            Write-Host 'MFT: sorted by known On disk allocation across data streams. Hard links charged once; LINK rows show zero charged bytes.' -ForegroundColor Yellow
            Write-Host 'Unknown / >= means incomplete allocation. Resident data slots count within MFT storage; other filesystem metadata and snapshots remain unassigned.' -ForegroundColor DarkGray
            Write-Host ("Reparse metadata only: {0:N0} files, {1:N0} directories; {2:N0} tags unavailable. No targets followed or content downloaded." -f $Scan.MftReparseFiles,$Scan.MftReparseDirectories,$Scan.MftUnknownTags) -ForegroundColor DarkGray
            if ($Scan.MftCloudFiles -gt 0) { Write-Host ("Volume-wide included cloud metadata: {0:N0} files, {1} logical. May be online-only; no content downloaded." -f $Scan.MftCloudFiles,(Format-DiskSize $Scan.MftCloudBytes)) -ForegroundColor Yellow }
            if ($Scan.MftContainerFiles -gt 0) { Write-Host ("Container records: {0:N0} files, {1} logical; {2} known local stream allocation. Backing layers are not charged again." -f $Scan.MftContainerFiles,(Format-DiskSize $Scan.MftContainerBytes),(Format-DiskSize $Scan.MftContainerAllocated)) -ForegroundColor Yellow }
            Write-Host ('Folder On disk: '+(Format-DiskAllocation $node.Allocated ($node.AllocationUnknown -or $node.Partial)))
            if ($Scan.VolumeUsed -ge 0) {
                $accounted=$Scan.Nodes[$Scan.Root].Allocated
                Write-Host ("Volume: Windows used {0} | Accounted data allocation {1} | Difference {2}" -f (Format-DiskSize $Scan.VolumeUsed),(Format-DiskSize $accounted),(Format-DiskSize ($Scan.VolumeUsed-$accounted)))
                if ($accounted -gt $Scan.VolumeUsed) { Write-Warning 'Accounted allocation exceeds the volume snapshot; totals need investigation (live changes or shared storage).' }
            }
        }
        Write-Host ("Included logical size: {0} | Files: {1:N0} | Scan diagnostics: {2:N0}" -f (Format-DiskSize $node.Bytes),$node.Files,$Scan.IssueCount)
        if ($Scan.PSObject.Properties['CachedRows'] -and $null -ne $Scan.CachedRows) {
            Write-Host ("Volume-wide omissions: {0:N0} files | {1:N0} directories | {2:N0} unparsed records. Press E for causes." -f $Scan.MftOmittedFiles,$Scan.MftOmittedDirectories,$Scan.MftRecordErrors) -ForegroundColor Yellow
            Write-Host ("Included records with incomplete allocation: {0:N0}. Columns: On disk | Logical size | Type | Name" -f $Scan.MftUnknownAllocations)
        }
        if ($node.Partial) { Write-Host 'PARTIAL TOTAL: inaccessible or excluded entries exist below this folder.' -ForegroundColor Yellow }
        Write-Host 'Folder totals and current listing are cached. Rescan after filesystem changes.' -ForegroundColor DarkGray
        for ($i=($page*20); $i -lt [math]::Min($rows.Count,($page+1)*20); $i++) {
            $row = $rows[$i]
            $flag = ''
            if ($row.Partial) { $flag = ' [partial]' }
            if ($row.PSObject.Properties['ReparseTag'] -and $row.ReparseTag) { $flag+=' [metadata: '+$row.ReparseTag+']' }
            if ($Scan.PSObject.Properties['CachedRows'] -and $null -ne $Scan.CachedRows) {
                Write-Host (' [{0}] {1,16}  {2,12}  {3,-4}  {4}{5}' -f ($i+1),(Format-DiskAllocation $row.Allocated ($row.AllocationUnknown -or $row.Partial)),(Format-DiskSize $row.Bytes),$row.Kind,$row.Name,$flag)
            } else { Write-Host (' [{0}] {1,12}  {2,-4}  {3}{4}' -f ($i+1),(Format-DiskSize $row.Bytes),$row.Kind,$row.Name,$flag) }
        }
        Write-Host ("Page {0}/{1} | Number: open folder | U: up | N/P: pages | R: rescan root | E: exclusions | 0: drives" -f ($page+1),$pages)
        $answer = Read-Host 'Select'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        switch ($answer.Trim().ToUpperInvariant()) {
            'U' { if ($node.Parent) { $current=$node.Parent; $page=0 }; continue browse }
            'N' { $page=[math]::Min($pages-1,$page+1); continue browse }
            'P' { $page=[math]::Max(0,$page-1); continue browse }
            'E' {
                if ($Scan.PSObject.Properties['IssueCounts'] -and $Scan.IssueCounts.Count -gt 0) {
                    $Scan.IssueCounts.GetEnumerator() | Sort-Object Value -Descending | Format-Table @{Label='Cause';Expression={$_.Key}},@{Label='Count';Expression={$_.Value}} -AutoSize | Out-Host
                    Write-Host 'Examples below are sampled by cause; an excluded ancestor can affect many descendants.'
                }
                $Scan.Issues | Format-List | Out-Host; Write-Host ("Showing {0} examples from {1:N0} diagnostics." -f $Scan.Issues.Count,$Scan.IssueCount); continue browse
            }
            'R' { $engine='Auto'; if ($Scan.PSObject.Properties['CachedRows'] -and $null -ne $Scan.CachedRows) { $engine='Mft' }; $Scan=Measure-DiskTree $Scan.Root -Engine $engine; $current=$Scan.Root; $page=0; $loadedPath=$null; continue browse }
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
        Write-Host "`n RANDOM TOOLKITS | DISK USAGE 0.4.0 | READ ONLY" -ForegroundColor Cyan
        for ($i=0; $i -lt $drives.Count; $i++) {
            $drive=$drives[$i]
            Write-Host (' [{0}] {1} {2} | Total {3} | Used {4} | Free {5} | {6}' -f ($i+1),$drive.Drive,$drive.Type,(Format-DiskSize $drive.Total),(Format-DiskSize $drive.Used),(Format-DiskSize $drive.Free),$drive.Detail)
        }
        Write-Host ' [F] Scan a folder path   [0] Exit'
        $mftLabel=' [M] Experimental MFT scan (local NTFS drive root)'
        if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { $mftLabel+=' [UNAVAILABLE: Requires administrator]' }
        Write-Host $mftLabel
        Write-Host ' [D] Diagnose an MFT record and its parents (local NTFS, admin; no full scan)'
        Write-Host 'Native metadata scan with live partial totals. Q: stop and browse partial results; Ctrl+C: exit. Links are skipped.' -ForegroundColor DarkGray
        $defaultDrive=$null
        if ($drives.Count -gt 0) { $defaultDrive=$drives[0].Drive }
        $answer=Read-Host 'Select drive or F/M/D'
        if ($null -eq $answer -or $answer.Trim() -eq '0') { return }
        try {
            if ($answer.Trim() -eq 'D') {
                $diagnosticRoot=Read-DiskDriveRoot $defaultDrive
                if ([string]::IsNullOrWhiteSpace($diagnosticRoot)) { continue }
                $reason=Get-DiskMftUnavailableReason $diagnosticRoot
                if ($reason) { Write-Warning $reason; continue }
                $recordText=Read-Host 'MFT record number from E (digits only)'
                $recordNumber=[uint64]0
                if (-not [uint64]::TryParse($recordText,[ref]$recordNumber) -or $recordNumber -gt 281474976710655) { throw 'Enter a valid MFT record number.' }
                Initialize-DiskScanner
                [RandomToolkits.DiskV7.MftScanner]::Inspect([IO.Path]::GetFullPath($diagnosticRoot),$recordNumber) | Out-Host
                continue
            }
            $scanPath=$null; $engine='Auto'
            if ($answer.Trim() -eq 'M') { $scanPath=Read-DiskDriveRoot $defaultDrive; $engine='Mft'; if ([string]::IsNullOrWhiteSpace($scanPath)) { continue } }
            elseif ($answer.Trim() -eq 'F') { $scanPath=Read-Host 'Folder path'; if ([string]::IsNullOrWhiteSpace($scanPath)) { continue } }
            else {
                $number=0
                if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $drives.Count) { throw 'Choose a listed drive.' }
                if (-not $drives[$number-1].Ready) { throw 'Drive is not ready.' }
                $scanPath=$drives[$number-1].Drive
            }
            Show-DiskScan (Measure-DiskTree $scanPath -Engine $engine)
        } catch { Write-Warning $_.Exception.Message }
    }
}

if ($PSVersionTable.PSVersion -lt [version]'5.0') { throw 'PowerShell 5.0+ is required.' }
if (-not $NoMenu) { Start-DiskUsage $Path }
