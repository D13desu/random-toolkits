using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Web.Script.Serialization;
using System.Runtime.InteropServices;
using System.Threading;
using RandomToolkits.DiskV10;

namespace RandomToolkits.HelperExperiment {
 internal sealed class VolumeSpaceSnapshot {internal long Used,Reserved,VolumeStorageReserve,Total,Available;}
 internal sealed class LiveFileSample {internal long Allocation;internal string Identity;}
 internal sealed class LiveDirectorySample {internal long Initial,Last;internal bool HasInitial,HasLast,Unavailable;internal DateTime Next;}
 internal sealed class BrowseRow {
  public string Name,Path,Kind,ReparseTag,Modified,LiveState;
  public long Bytes,Allocated,LogicalDelta,AllocatedDelta;
  public bool Partial,AllocationUnknown;
 }
 internal static class LiveFileInfo {
  const uint FileReadAttributes=0x80,ShareRead=1,ShareWrite=2,ShareDelete=4,OpenExisting=3;
  const uint OpenReparsePoint=0x00200000,OpenNoRecall=0x00100000;
  static readonly IntPtr InvalidHandle=new IntPtr(-1);
  [StructLayout(LayoutKind.Sequential)] struct FileStandardInfo {internal long AllocationSize,EndOfFile;internal uint NumberOfLinks;[MarshalAs(UnmanagedType.Bool)]internal bool DeletePending;[MarshalAs(UnmanagedType.Bool)]internal bool Directory;}
  [StructLayout(LayoutKind.Sequential)] struct ByHandleInfo {
   internal uint Attributes,CreationLow,CreationHigh,AccessLow,AccessHigh,WriteLow,WriteHigh,VolumeSerial,SizeHigh,SizeLow,Links,FileIndexHigh,FileIndexLow;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFileW(string path,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(IntPtr handle,int informationClass,out FileStandardInfo information,uint size);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(IntPtr handle,out ByHandleInfo information);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  static string DevicePath(string path){if(path.StartsWith(@"\\?\",StringComparison.Ordinal))return path;if(path.StartsWith(@"\\",StringComparison.Ordinal))return @"\\?\UNC\"+path.Substring(2);return @"\\?\"+path;}
  internal static bool Query(string path,out long logical,out long allocated,out string identity,out bool deleted){
   logical=allocated=0;identity=null;deleted=false;IntPtr handle=CreateFileW(DevicePath(path),FileReadAttributes,ShareRead|ShareWrite|ShareDelete,IntPtr.Zero,OpenExisting,OpenReparsePoint|OpenNoRecall,IntPtr.Zero);
   if(handle==InvalidHandle){int error=Marshal.GetLastWin32Error();deleted=error==2 || error==3 || error==303;return false;}
   try {
    FileStandardInfo standard;ByHandleInfo byHandle;
    if(!GetFileInformationByHandleEx(handle,1,out standard,(uint)Marshal.SizeOf(typeof(FileStandardInfo))) || standard.Directory)return false;
    logical=standard.EndOfFile;allocated=standard.AllocationSize;
    if(GetFileInformationByHandle(handle,out byHandle))identity=String.Format("{0:X8}:{1:X8}{2:X8}",byHandle.VolumeSerial,byHandle.FileIndexHigh,byHandle.FileIndexLow);
    return true;
   } finally {CloseHandle(handle);}
  }
 }
 internal sealed class LiveDirectoryProbe {
  const uint Reparse=0x400,DirectoryFlag=0x10;static readonly IntPtr Invalid=new IntPtr(-1);
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct FindData {
   internal uint Attributes,CreationLow,CreationHigh,AccessLow,AccessHigh,WriteLow,WriteHigh,SizeHigh,SizeLow,Reserved0,Reserved1;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)]internal string Name;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=14)]internal string Alternate;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr FindFirstFileExW(string path,int level,out FindData data,int search,IntPtr filter,int flags);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)][return:MarshalAs(UnmanagedType.Bool)]static extern bool FindNextFileW(IntPtr handle,out FindData data);
  [DllImport("kernel32.dll",SetLastError=true)][return:MarshalAs(UnmanagedType.Bool)]static extern bool FindClose(IntPtr handle);
  internal volatile bool Done,CancelRequested;internal bool Partial;internal long Logical;internal string Error;readonly string root;
  LiveDirectoryProbe(string path){root=path;}
  static string DevicePath(string path){if(path.StartsWith(@"\\?\",StringComparison.Ordinal))return path;if(path.StartsWith(@"\\",StringComparison.Ordinal))return @"\\?\UNC\"+path.Substring(2);return @"\\?\"+path;}
  static string Child(string parent,string name){return parent.TrimEnd('\\')+"\\"+name;}
  static IntPtr Open(string path,out FindData data){IntPtr handle=FindFirstFileExW(Child(DevicePath(path),"*"),1,out data,0,IntPtr.Zero,2);if(handle==Invalid && Marshal.GetLastWin32Error()==87)handle=FindFirstFileExW(Child(DevicePath(path),"*"),1,out data,0,IntPtr.Zero,0);return handle;}
  internal static LiveDirectoryProbe Start(string path){var probe=new LiveDirectoryProbe(path);var thread=new Thread(probe.Run);thread.IsBackground=true;thread.Start();return probe;}
  void Run(){
   try {
    var pending=new Stack<string>();pending.Push(root);long total=0;
    while(pending.Count>0 && !CancelRequested) {
     string directory=pending.Pop();FindData data;IntPtr handle=Open(directory,out data);
     if(handle==Invalid){int openError=Marshal.GetLastWin32Error();if(openError!=2 && openError!=3 && openError!=18)Partial=true;continue;}
     try {
      do {
       if(CancelRequested)break;if(data.Name=="." || data.Name=="..")continue;if((data.Attributes&Reparse)!=0)continue;
       string path=Child(directory,data.Name);if((data.Attributes&DirectoryFlag)!=0)pending.Push(path);else total=checked(total+(((long)data.SizeHigh<<32)|data.SizeLow));
      } while(FindNextFileW(handle,out data));
      int error=Marshal.GetLastWin32Error();if(!CancelRequested && error!=18)Partial=true;
     } finally {FindClose(handle);}
    }
    if(!CancelRequested)Logical=total;
   } catch(Exception ex){Error=ex.Message;} finally {Done=true;}
  }
 }
 internal static class VolumeSpace {
  [StructLayout(LayoutKind.Sequential)] struct DiskSpaceInformation {
   internal ulong ActualTotal,ActualAvailable,ActualPoolUnavailable,CallerTotal,CallerAvailable,CallerPoolUnavailable;
   internal ulong Used,TotalReserved,VolumeStorageReserve,AvailableCommitted,PoolAvailable;
   internal uint SectorsPerAllocationUnit,BytesPerSector;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern int GetDiskSpaceInformationW(string rootPath,out DiskSpaceInformation information);
  static long Bytes(ulong units,ulong unitBytes){ulong value=checked(units*unitBytes);if(value>Int64.MaxValue)throw new OverflowException();return (long)value;}
  internal static VolumeSpaceSnapshot Query(string root){
   try {DiskSpaceInformation value;int result=GetDiskSpaceInformationW(root,out value);if(result!=0)return null;ulong unit=checked((ulong)value.SectorsPerAllocationUnit*value.BytesPerSector);if(unit==0)return null;
    return new VolumeSpaceSnapshot {Used=Bytes(value.Used,unit),Reserved=Bytes(value.TotalReserved,unit),VolumeStorageReserve=Bytes(value.VolumeStorageReserve,unit),Total=Bytes(value.ActualTotal,unit),Available=Bytes(value.ActualAvailable,unit)};
   } catch(EntryPointNotFoundException){return null;} catch(OverflowException){return null;}
  }
 }
 internal static class Program {
  const string Version="1.2.0";
  static readonly JavaScriptSerializer Json=new JavaScriptSerializer {MaxJsonLength=16777216,RecursionLimit=32};
  static Scanner native; static MftScanner mft; static Scan scan;
  static CompactIndex compact;static object completedSummary;static int[] cachedOrder;
  static List<Issue> issues;static Dictionary<string,int> causes;static int issueCount;
  static double cleanupMilliseconds,preCompactCleanupMilliseconds,finalCleanupMilliseconds,compactMilliseconds;
  static ScanProfile profile;
  static Stopwatch elapsed; static string mode, cachedPath, cachedSort; static Row[] cachedRows;
  static readonly Dictionary<string,LiveFileSample> liveFiles=new Dictionary<string,LiveFileSample>(StringComparer.OrdinalIgnoreCase);
  static readonly Dictionary<string,LiveDirectorySample> liveDirectories=new Dictionary<string,LiveDirectorySample>(StringComparer.OrdinalIgnoreCase);
  static LiveDirectoryProbe liveDirectoryScanner;static string liveDirectoryPath;
  static bool Running {get {return (native!=null && !native.Done) || (mft!=null && !mft.Done);}}
  static string Text(Dictionary<string,object> request,string key,string fallback) {
   object value;return request.TryGetValue(key,out value) && value!=null ? Convert.ToString(value):fallback;
  }
  static int Number(Dictionary<string,object> request,string key,int fallback,int min,int max) {
   object value;int result=request.TryGetValue(key,out value)?Convert.ToInt32(value):fallback;
   if(result<min || result>max) throw new ArgumentException(key+" is outside its allowed range.");return result;
  }
  static bool Boolean(Dictionary<string,object> request,string key,bool fallback) {object value;return request.TryGetValue(key,out value) && value!=null?Convert.ToBoolean(value):fallback;}
  static void ResetLiveDirectory(){if(liveDirectoryScanner!=null && !liveDirectoryScanner.Done)liveDirectoryScanner.CancelRequested=true;liveDirectoryScanner=null;liveDirectoryPath=null;liveDirectories.Clear();}
  static void ResetLive(){liveFiles.Clear();ResetLiveDirectory();}
  static void Cancel() {if(native!=null) native.CancelRequested=true;if(mft!=null) mft.CancelRequested=true;}
  static void Finish() {
   if(completedSummary!=null || Running || (native==null && mft==null)) return;
   string error=mft!=null?mft.Error:native.Error;
   if(elapsed!=null) elapsed.Stop();
   if(error!=null) throw new IOException(error);
   scan=mft!=null?mft.Result:native.Result;
   object summary=Summary();issues=scan.Issues;causes=scan.IssueCounts;issueCount=scan.IssueCount;
   if(mode=="mft") {
    var timer=Stopwatch.StartNew();
    // Legacy rows build a replacement cache and benefit from reclaiming the
    // reconstruction graph first. The default direct cache is handed off
    // without copying, so collecting here only repeats the final collection.
    if(scan.DirectRows==null) {
     profile.Mark("pre-compaction cleanup");
     GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();preCompactCleanupMilliseconds=timer.Elapsed.TotalMilliseconds;
    }
    profile.Mark("cache handoff");timer.Restart();compact=scan.DirectRows==null?new CompactIndex(scan):new CompactIndex(scan,scan.DirectRows);compactMilliseconds=timer.Elapsed.TotalMilliseconds;
    scan=null;mft=null;
    timer.Restart();
    // Reclaim gaps left by the discarded reconstruction tree and large indexes.
    System.Runtime.GCSettings.LargeObjectHeapCompactionMode=System.Runtime.GCLargeObjectHeapCompactionMode.CompactOnce;
    GC.Collect(2,GCCollectionMode.Forced,true,true);GC.WaitForPendingFinalizers();GC.Collect();finalCleanupMilliseconds=timer.Elapsed.TotalMilliseconds;
    cleanupMilliseconds=preCompactCleanupMilliseconds+finalCleanupMilliseconds;
    profile.Mark("ready");
   }
   completedSummary=summary;
  }
  static object Summary() {
   Node root=scan.Nodes[scan.Root];bool allocated=mode=="mft";
   object accounting=allocated && scan.Accounting!=null?scan.Accounting.Snapshot(scan):null;
   object nonData=allocated && mft!=null?mft.AttributeAllocation.Snapshot():null;
   object reconciliation=null;
   if(allocated && scan.Accounting!=null && mft!=null) {
    VolumeSpaceSnapshot volume=VolumeSpace.Query(scan.Root);
    long includedPhysical=checked(root.Allocated-scan.Accounting.IncludedResidentAllocation);
    long metadataDataPhysical=checked(scan.Accounting.KnownMetadataDataAllocation-scan.Accounting.MetadataResidentAllocation);
    long knownPhysical=checked(includedPhysical+metadataDataPhysical+mft.AttributeAllocation.AttributeList+mft.AttributeAllocation.IndexAllocation+mft.AttributeAllocation.Bitmap+mft.AttributeAllocation.Other);
    if(volume!=null) reconciliation=new {includedAllocation=root.Allocated,includedResidentOverlap=scan.Accounting.IncludedResidentAllocation,
     includedPhysical= includedPhysical,metadataDataPhysical=metadataDataPhysical,nonDataPhysical=checked(mft.AttributeAllocation.AttributeList+mft.AttributeAllocation.IndexAllocation+mft.AttributeAllocation.Bitmap+mft.AttributeAllocation.Other),
     knownPhysical=knownPhysical,windowsUsed=volume.Used,reserved=volume.Reserved,volumeStorageReserve=volume.VolumeStorageReserve,
     windowsUnavailable=checked(volume.Used+volume.Reserved),reconciled=checked(knownPhysical+volume.Reserved),residual=checked(volume.Used-knownPhysical)};
   }
   return new {root=scan.Root,engine=scan.Engine,files=scan.Files,folders=scan.DirectRows!=null?scan.DirectRows.FolderCount:scan.Nodes.Count,
    logical=root.Bytes,allocated=allocated?(long?)root.Allocated:null,allocationUnknown=allocated && root.AllocationUnknown,
    partial=root.Partial,cancelled=scan.Cancelled,diagnostics=scan.IssueCount,causes=scan.IssueCounts,
    omittedFiles=scan.MftOmittedFiles,omittedDirectories=scan.MftOmittedDirectories,parseErrors=scan.MftRecordErrors,
    unknownAllocations=scan.MftUnknownAllocations,apiVerified=scan.MftApiVerified,records=scan.MftRecordsRead,
    volumeUsed=scan.VolumeUsed,seconds=elapsed.Elapsed.TotalSeconds,accounting=accounting,
    nonDataAllocation=nonData,reconciliation=reconciliation};
  }
  static object Status() {
   Finish();
   if(completedSummary!=null) return new {type="status",state="ready",summary=completedSummary,workingSet=Process.GetCurrentProcess().WorkingSet64,
    managedBytes=GC.GetTotalMemory(false),cleanupMilliseconds=cleanupMilliseconds,compactMilliseconds=compactMilliseconds,
    preCompactCleanupMilliseconds=preCompactCleanupMilliseconds,finalCleanupMilliseconds=finalCleanupMilliseconds,
    readySeconds=elapsed.Elapsed.TotalSeconds+(cleanupMilliseconds+compactMilliseconds)/1000};
   if(native==null && mft==null) return new {type="status",state="idle"};
   return new {type="status",state="scanning",phase=profile!=null?profile.Phase:"native scan",files=mft!=null?mft.FilesSeen:native.FilesSeen,
    folders=mft!=null?mft.DirectoriesSeen:native.DirectoriesSeen,records=mft!=null?mft.RecordsSeen:0,
    seconds=elapsed.Elapsed.TotalSeconds,cancelling=mft!=null?mft.CancelRequested:native.CancelRequested,
    workingSet=Process.GetCurrentProcess().WorkingSet64};
  }
  static object Start(Dictionary<string,object> request) {
   if(Running) throw new InvalidOperationException("A scan is already running. Cancel it and wait for completion first.");
   string engine=Text(request,"engine","mft");if(engine!="mft" && engine!="native") throw new ArgumentException("Engine must be mft or native.");
   string path=Text(request,"path",null);if(String.IsNullOrWhiteSpace(path)) throw new ArgumentException("A scan path is required.");
   path=Path.GetFullPath(path);var directory=new DirectoryInfo(path);
   if(!directory.Exists) throw new DirectoryNotFoundException(path);
   if((directory.Attributes&FileAttributes.ReparsePoint)!=0) throw new IOException("Choose a real directory, not a reparse point.");
   if(engine=="mft") {
    if(path.Length!=3 || path[1]!=':' || path[2]!='\\') throw new ArgumentException("MFT requires a local NTFS drive root.");
    if(!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) throw new UnauthorizedAccessException("MFT scanning requires an administrator PowerShell. No automatic elevation.");
    var drive=new DriveInfo(path);if(drive.DriveType==DriveType.Network || drive.DriveFormat!="NTFS") throw new ArgumentException("MFT requires a local NTFS volume.");
   }
   mode=engine;scan=null;native=null;mft=null;compact=null;completedSummary=null;issues=null;causes=null;issueCount=0;cachedOrder=null;ResetLive();
   cleanupMilliseconds=0;preCompactCleanupMilliseconds=0;finalCleanupMilliseconds=0;compactMilliseconds=0;cachedRows=null;cachedPath=null;cachedSort=null;elapsed=Stopwatch.StartNew();
   profile=null;if(engine=="mft") {mft=MftScanner.Start(path);profile=mft.Profile;}else native=Scanner.Start(path);
   return new {type="accepted",engine=engine,path=path};
  }
  static void RequireReady() {Finish();if(completedSummary==null) throw new InvalidOperationException("Wait for scan completion before browsing.");}
  static void PresentDirectories(BrowseRow[] rows,string priorityPath) {
   var visible=new HashSet<string>(StringComparer.OrdinalIgnoreCase);foreach(BrowseRow row in rows)if(row.Kind=="DIR")visible.Add(row.Path);
   if(visible.Count==0){ResetLiveDirectory();return;}
   if(liveDirectoryPath!=null && !visible.Contains(liveDirectoryPath)){if(liveDirectoryScanner!=null && !liveDirectoryScanner.Done)liveDirectoryScanner.CancelRequested=true;liveDirectoryScanner=null;liveDirectoryPath=null;}
   var remove=new List<string>();foreach(string path in liveDirectories.Keys)if(!visible.Contains(path))remove.Add(path);foreach(string path in remove)liveDirectories.Remove(path);
   foreach(string path in visible)if(!liveDirectories.ContainsKey(path))liveDirectories.Add(path,new LiveDirectorySample {Next=DateTime.MinValue});
   DateTime now=DateTime.UtcNow;
   if(liveDirectoryScanner!=null && liveDirectoryScanner.Done) {
    LiveDirectorySample completed;
    if(liveDirectories.TryGetValue(liveDirectoryPath,out completed)) {
     if(liveDirectoryScanner.Error==null && !liveDirectoryScanner.CancelRequested) {
      long current=liveDirectoryScanner.Logical;if(!completed.HasInitial){completed.Initial=current;completed.HasInitial=true;}completed.Last=current;completed.HasLast=true;completed.Unavailable=false;
     } else completed.Unavailable=true;
     completed.Next=now.AddSeconds(2);
    }
    liveDirectoryScanner=null;liveDirectoryPath=null;
   }
   foreach(BrowseRow row in rows)if(row.Kind=="DIR") {
    LiveDirectorySample sample=liveDirectories[row.Path];
    if(sample.HasLast){long delta=checked(sample.Last-sample.Initial);row.Bytes=checked(row.Bytes+delta);row.LogicalDelta=delta;row.LiveState=delta>0?"grown":delta<0?"shrunk":"same";}
    else row.LiveState=sample.Unavailable?"unavailable":"checking";
   }
   if(liveDirectoryScanner==null) {
    string candidate=null;LiveDirectorySample choice=null;
    foreach(string path in visible) {
     LiveDirectorySample sample=liveDirectories[path];if(sample.Next>now)continue;
     bool better=choice==null || (!sample.HasInitial && choice.HasInitial) || (sample.HasInitial==choice.HasInitial && sample.Next<choice.Next) ||
      (sample.HasInitial==choice.HasInitial && sample.Next==choice.Next && String.Equals(path,priorityPath,StringComparison.OrdinalIgnoreCase));
     if(better){candidate=path;choice=sample;}
    }
    if(candidate!=null){liveDirectoryPath=candidate;liveDirectoryScanner=LiveDirectoryProbe.Start(candidate);}
   }
  }
  static BrowseRow[] PresentRows(Row[] rows,bool live,string watchPath) {
   var presented=new BrowseRow[rows.Length];
   for(int index=0;index<rows.Length;index++) {
    Row row=rows[index];var output=new BrowseRow {Name=row.Name,Path=row.Path,Kind=row.Kind,ReparseTag=row.ReparseTag,Bytes=row.Bytes,Allocated=row.Allocated,Partial=row.Partial,AllocationUnknown=row.AllocationUnknown};
    try {DateTime modified=File.GetLastWriteTime(row.Path);output.Modified=modified.Year>1601?modified.ToString("yyyy-MM-dd"):null;}catch {output.Modified=null;}
    if(live && row.Kind!="DIR" && row.Kind!="LINK") {
     long logical,allocation;string identity;bool deleted;
     if(LiveFileInfo.Query(row.Path,out logical,out allocation,out identity,out deleted)) {
      LiveFileSample sample;
      if(!liveFiles.TryGetValue(row.Path,out sample)){sample=new LiveFileSample {Allocation=allocation,Identity=identity};liveFiles.Add(row.Path,sample);}
      if(sample.Identity!=null && identity!=null && !String.Equals(sample.Identity,identity,StringComparison.Ordinal)){output.LiveState="replaced";output.Bytes=logical;output.Allocated=allocation;output.LogicalDelta=checked(logical-row.Bytes);output.AllocatedDelta=checked(allocation-row.Allocated);}
      else {
       output.Bytes=logical;output.LogicalDelta=checked(logical-row.Bytes);output.AllocatedDelta=checked(allocation-sample.Allocation);output.Allocated=Math.Max(0,checked(row.Allocated+output.AllocatedDelta));
       if(output.LogicalDelta==0 && output.AllocatedDelta==0)output.LiveState="same";
       else if(output.LogicalDelta>=0 && output.AllocatedDelta>=0)output.LiveState="grown";
       else if(output.LogicalDelta<=0 && output.AllocatedDelta<=0)output.LiveState="shrunk";
       else output.LiveState="changed";
      }
     } else output.LiveState=deleted?"deleted":"unavailable";
    }
    presented[index]=output;
   }
   if(live)PresentDirectories(presented,watchPath);
   else if(liveDirectoryPath!=null || liveDirectories.Count>0)ResetLiveDirectory();
   return presented;
  }
  static object Memory(Dictionary<string,object> request) {
   RequireReady();long managedBefore=GC.GetTotalMemory(false),workingBefore=Process.GetCurrentProcess().WorkingSet64;
   bool collect=Text(request,"collect","false").Equals("true",StringComparison.OrdinalIgnoreCase);
   var timer=Stopwatch.StartNew();
   if(collect) {GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();}
   timer.Stop();long rows=compact==null?0:compact.RowCount;
   return new {type="memory",collected=collect,collectionMilliseconds=timer.Elapsed.TotalMilliseconds,
    managedBefore=managedBefore,managedAfter=GC.GetTotalMemory(false),workingSetBefore=workingBefore,
    workingSetAfter=Process.GetCurrentProcess().WorkingSet64,privateBytes=Process.GetCurrentProcess().PrivateMemorySize64,
    peakWorkingSet=Process.GetCurrentProcess().PeakWorkingSet64,folders=compact!=null?compact.FolderCount:scan.Nodes.Count,cachedRows=rows,
    pathCacheEntries=compact==null?0:compact.PathCacheCount,pathCacheCharacters=compact==null?0:compact.PathCacheCharacters};
  }
  static object List(Dictionary<string,object> request) {
   RequireReady();string path=Text(request,"path",compact!=null?compact.Root:scan.Root);
   string sort=Text(request,"sort",mode=="mft"?"allocated":"logical");
   if(sort!="allocated" && sort!="logical" && sort!="name") throw new ArgumentException("Unknown sort order.");
   int offset=Number(request,"offset",0,0,Int32.MaxValue),limit=Number(request,"limit",20,1,100);bool live=Boolean(request,"live",false);string watchPath=Text(request,"watchPath",null);
   if(compact!=null) {
    int id;if(!compact.Find(path,out id)) throw new ArgumentException("Path is outside the cached scan.");
    CompactIndex.Folder folder=compact.GetFolder(id);
    if(cachedOrder==null || cachedPath!=path || cachedSort!=sort){cachedOrder=compact.Sort(id,sort);cachedPath=path;cachedSort=sort;}
    offset=Math.Min(offset,folder.Count);int compactCount=Math.Min(limit,folder.Count-offset);
    return new {type="listing",path=compact.GetPath(id),parent=folder.Parent<0?null:compact.GetPath(folder.Parent),sort=sort,offset=offset,total=folder.Count,
     logical=folder.Logical,allocated=(long?)folder.Allocated,partial=folder.Partial,allocationUnknown=folder.Unknown,files=folder.Files,
     rows=PresentRows(compact.Page(id,cachedOrder,offset,compactCount),live,watchPath)};
   }
   Node node;if(!scan.Nodes.TryGetValue(path,out node)) throw new ArgumentException("Path is outside the cached scan.");
   if(cachedRows==null || cachedPath!=path || cachedSort!=sort) {
    cachedRows=scan.CachedRows!=null?scan.CachedRows[path].ToArray():Scanner.Children(scan,path);
    Array.Sort(cachedRows,delegate(Row a,Row b) {
     int size=sort=="name"?0:((sort=="allocated" && mode=="mft")?b.Allocated.CompareTo(a.Allocated):b.Bytes.CompareTo(a.Bytes));
     return size!=0?size:StringComparer.Ordinal.Compare(a.Name,b.Name);
    });cachedPath=path;cachedSort=sort;
   }
   if(offset>cachedRows.Length) offset=cachedRows.Length;int count=Math.Min(limit,cachedRows.Length-offset);
   Row[] rows=new Row[count];Array.Copy(cachedRows,offset,rows,0,count);
   return new {type="listing",path=path,parent=node.Parent,sort=sort,offset=offset,total=cachedRows.Length,
    logical=node.Bytes,allocated=mode=="mft"?(long?)node.Allocated:null,partial=node.Partial,
    allocationUnknown=node.AllocationUnknown,files=node.Files,rows=PresentRows(rows,live,watchPath)};
  }
  static object Dispatch(Dictionary<string,object> request) {
   switch(Text(request,"command","")) {
    case "scan":return Start(request);
    case "status":return Status();
    case "cancel":Cancel();return new {type="cancelled",message="Cancellation requested; poll status for partial results."};
    case "live":ResetLive();return new {type="live",enabled=Boolean(request,"enabled",false)};
    case "list":return List(request);
    case "memory":return Memory(request);
    case "profile":return new {type="profile",scan=profile==null?null:profile.Snapshot()};
    case "issues":
     RequireReady();int offset=Number(request,"offset",0,0,Int32.MaxValue),limit=Number(request,"limit",20,1,100);
     offset=Math.Min(offset,issues.Count);return new {type="issues",total=issueCount,sampled=issues.Count,
      causes=causes,offset=offset,rows=issues.GetRange(offset,Math.Min(limit,issues.Count-offset))};
    default:throw new ArgumentException("Unknown command.");
   }
  }
  static void Send(object value) {Console.WriteLine(Json.Serialize(value));Console.Out.Flush();}
  public static int Main() {
   Console.InputEncoding=new UTF8Encoding(false);Console.OutputEncoding=new UTF8Encoding(false);
   Send(new {type="hello",protocol=1,version=Version,engineVersion="0.4.6",processId=Process.GetCurrentProcess().Id,
    architecture=Environment.Is64BitProcess?"x64":"x86"});
   try {
    string line;while((line=Console.ReadLine())!=null) {
     try {
      if(line.Length>65536) throw new ArgumentException("Request too large.");
      var request=Json.Deserialize<Dictionary<string,object>>(line);if(request==null) throw new ArgumentException("Request must be an object.");
      if(Text(request,"command","")=="quit") {Cancel();Send(new {type="bye"});break;}
      Send(Dispatch(request));
     } catch(Exception ex) {Send(new {type="error",message=ex.Message});}
    }
   } finally {Cancel();}
   return 0;
  }
 }
}
