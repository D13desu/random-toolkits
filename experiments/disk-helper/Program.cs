using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Web.Script.Serialization;
using RandomToolkits.DiskV10;

namespace RandomToolkits.HelperExperiment {
 internal static class Program {
  const string Version="1.1.0";
  static readonly JavaScriptSerializer Json=new JavaScriptSerializer {MaxJsonLength=16777216,RecursionLimit=32};
  static Scanner native; static MftScanner mft; static Scan scan;
  static CompactIndex compact;static object completedSummary;static int[] cachedOrder;
  static List<Issue> issues;static Dictionary<string,int> causes;static int issueCount;
  static double cleanupMilliseconds,preCompactCleanupMilliseconds,finalCleanupMilliseconds,compactMilliseconds;
  static ScanProfile profile;
  static Stopwatch elapsed; static string mode, cachedPath, cachedSort; static Row[] cachedRows;
  static bool Running {get {return (native!=null && !native.Done) || (mft!=null && !mft.Done);}}
  static string Text(Dictionary<string,object> request,string key,string fallback) {
   object value;return request.TryGetValue(key,out value) && value!=null ? Convert.ToString(value):fallback;
  }
  static int Number(Dictionary<string,object> request,string key,int fallback,int min,int max) {
   object value;int result=request.TryGetValue(key,out value)?Convert.ToInt32(value):fallback;
   if(result<min || result>max) throw new ArgumentException(key+" is outside its allowed range.");return result;
  }
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
   return new {root=scan.Root,engine=scan.Engine,files=scan.Files,folders=scan.DirectRows!=null?scan.DirectRows.FolderCount:scan.Nodes.Count,
    logical=root.Bytes,allocated=allocated?(long?)root.Allocated:null,allocationUnknown=allocated && root.AllocationUnknown,
    partial=root.Partial,cancelled=scan.Cancelled,diagnostics=scan.IssueCount,causes=scan.IssueCounts,
    omittedFiles=scan.MftOmittedFiles,omittedDirectories=scan.MftOmittedDirectories,parseErrors=scan.MftRecordErrors,
    unknownAllocations=scan.MftUnknownAllocations,apiVerified=scan.MftApiVerified,records=scan.MftRecordsRead,
    volumeUsed=scan.VolumeUsed,seconds=elapsed.Elapsed.TotalSeconds,accounting=allocated && scan.Accounting!=null?scan.Accounting.Snapshot(scan):null};
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
   mode=engine;scan=null;native=null;mft=null;compact=null;completedSummary=null;issues=null;causes=null;issueCount=0;cachedOrder=null;
   cleanupMilliseconds=0;preCompactCleanupMilliseconds=0;finalCleanupMilliseconds=0;compactMilliseconds=0;cachedRows=null;cachedPath=null;cachedSort=null;elapsed=Stopwatch.StartNew();
   profile=null;if(engine=="mft") {mft=MftScanner.Start(path);profile=mft.Profile;}else native=Scanner.Start(path);
   return new {type="accepted",engine=engine,path=path};
  }
  static void RequireReady() {Finish();if(completedSummary==null) throw new InvalidOperationException("Wait for scan completion before browsing.");}
  static Row[] AddModifiedDates(Row[] rows) {
   foreach(Row row in rows) {
    try {DateTime modified=File.GetLastWriteTime(row.Path);row.Modified=modified.Year>1601?modified.ToString("yyyy-MM-dd"):null;}
    catch {row.Modified=null;}
   }
   return rows;
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
   int offset=Number(request,"offset",0,0,Int32.MaxValue),limit=Number(request,"limit",20,1,100);
   if(compact!=null) {
    int id;if(!compact.Find(path,out id)) throw new ArgumentException("Path is outside the cached scan.");
    CompactIndex.Folder folder=compact.GetFolder(id);
    if(cachedOrder==null || cachedPath!=path || cachedSort!=sort){cachedOrder=compact.Sort(id,sort);cachedPath=path;cachedSort=sort;}
    offset=Math.Min(offset,folder.Count);int compactCount=Math.Min(limit,folder.Count-offset);
    return new {type="listing",path=compact.GetPath(id),parent=folder.Parent<0?null:compact.GetPath(folder.Parent),sort=sort,offset=offset,total=folder.Count,
     logical=folder.Logical,allocated=(long?)folder.Allocated,partial=folder.Partial,allocationUnknown=folder.Unknown,files=folder.Files,
     rows=AddModifiedDates(compact.Page(id,cachedOrder,offset,compactCount))};
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
   Row[] rows=new Row[count];Array.Copy(cachedRows,offset,rows,0,count);AddModifiedDates(rows);
   return new {type="listing",path=path,parent=node.Parent,sort=sort,offset=offset,total=cachedRows.Length,
    logical=node.Bytes,allocated=mode=="mft"?(long?)node.Allocated:null,partial=node.Partial,
    allocationUnknown=node.AllocationUnknown,files=node.Files,rows=rows};
  }
  static object Dispatch(Dictionary<string,object> request) {
   switch(Text(request,"command","")) {
    case "scan":return Start(request);
    case "status":return Status();
    case "cancel":Cancel();return new {type="cancelled",message="Cancellation requested; poll status for partial results."};
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
   Send(new {type="hello",protocol=1,version=Version,engineVersion="0.4.5",processId=Process.GetCurrentProcess().Id,
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
