using System;
using System.Collections.Generic;
using System.Linq;
using RandomToolkits.DiskV10;
using RandomToolkits.HelperExperiment;

internal static class CompactIndexTest {
 static void Assert(bool value,string message){if(!value) throw new Exception(message);}
 static void Same(Row a,Row b) {
  Assert(a.Name==b.Name && a.Path==b.Path && a.Kind==b.Kind && a.ReparseTag==b.ReparseTag && a.Bytes==b.Bytes &&
   a.Allocated==b.Allocated && a.Partial==b.Partial && a.AllocationUnknown==b.AllocationUnknown,"Page row differs from source cache.");
 }
 static long Metric(Scan scan,string name){object snapshot=scan.Accounting.Snapshot(scan);return Convert.ToInt64(snapshot.GetType().GetProperty(name).GetValue(snapshot,null));}
 static MftRecord AccountingRecord(ulong reference,string name,ulong parent,bool directory,long bytes,long allocated,bool known){
  var record=new MftRecord {Reference=reference,Directory=directory,HasData=!directory,HasStandardInformation=true,Bytes=bytes,Allocated=allocated,AllocationKnown=known,AllocationIssue="fixture unknown"};
  record.Names.Add(new MftName {Name=name,Parent=parent});return record;
 }
 static Scan AccountingBuild(params MftRecord[] records){try {ScanProfile.Current=new ScanProfile {UseDirectRows=true,UseCompactFolders=true,UseLazyPaths=true};return MftScanner.Build(@"Z:\",records,false);}finally{ScanProfile.Current=null;}}
 static void Accounting(){
  var root=AccountingRecord(5,".",5,true,0,0,true);
  var file=AccountingRecord(100,"z.bin",5,false,100,4096,true);file.Names.Add(new MftName {Parent=5,Name="a.bin"});file.LinkCountMismatch=true;
  var info=AccountingBuild(root,file);
  Assert(!info.Nodes[info.Root].Partial && info.IssueCount==1 && Metric(info,"informationalDiagnostics")==1 && Metric(info,"problemDiagnostics")==0,"Included information incorrectly marks totals partial.");
  Assert(Metric(info,"uniqueFiles")==1 && Metric(info,"fileEntries")==2 && Metric(info,"additionalLinks")==1 && Metric(info,"uniqueLogical")==100 && Metric(info,"logicalAcrossLinks")==200,"Hard-link accounting totals are wrong.");
  var index=new CompactIndex(info,info.DirectRows);int rootId;index.Find(info.Root,out rootId);var order=index.Sort(rootId,"name");var rows=index.Page(rootId,order,0,order.Length);
  Assert(!index.GetFolder(rootId).Partial && rows[1].Kind=="LINK" && rows[1].Bytes==0 && rows[1].Allocated==0,"Information/expanded logical total changed charged browsing rows.");
  var duplicate=AccountingRecord(101,"a.bin",5,false,500,8192,true);var collision=AccountingBuild(root,file,duplicate);
  Assert(collision.Nodes[collision.Root].Partial && Metric(collision,"fileEntries")==2 && Metric(collision,"logicalAcrossLinks")==200,"Rejected duplicate entered accounting or lost partial flag.");
  var mft=AccountingRecord(0,"$MFT",5,false,8192,8192,true);var extend=AccountingRecord(11,"$Extend",5,true,0,128,false);
  var metadataDir=AccountingRecord(40,"$RmMetadata",11,true,0,64,true);var log=AccountingRecord(41,"log",40,false,100,1024,true);var unknown=AccountingRecord(42,"unknown",40,false,100,256,false);
  var badClusters=AccountingRecord(8,"$BadClus",5,false,999010856960L,999010856960L,true);
  var metadata=AccountingBuild(root,mft,mft,extend,badClusters,metadataDir,log,unknown,file);
  Assert(Metric(metadata,"coreMetadataRecords")==4 && Metric(metadata,"coreKnownDataAllocation")==8320 && Metric(metadata,"coreUnknownAllocations")==2,"Core metadata is duplicated, hides unknown allocation, or counts the bad-cluster span as used space.");
  Assert(Metric(metadata,"excludedMetadataFiles")==2 && Metric(metadata,"excludedMetadataDirectories")==1 && Metric(metadata,"excludedKnownDataAllocation")==1344 && Metric(metadata,"excludedUnknownAllocations")==1,"Excluded metadata tree accounting is wrong.");
  Assert(metadata.Nodes[metadata.Root].Bytes==100 && metadata.Nodes[metadata.Root].Allocated==4096 && metadata.Nodes[metadata.Root].Partial && Metric(metadata,"metadataExclusionDiagnostics")==3,"Metadata entered user totals or lost exclusion flags.");
  var uncertain=AccountingBuild(root,AccountingRecord(200,"uncertain",5,false,50,256,false));
  Assert(uncertain.Nodes[uncertain.Root].Partial && uncertain.Nodes[uncertain.Root].AllocationUnknown && Metric(uncertain,"problemDiagnostics")==1,"User allocation uncertainty was classified as information.");
  Console.WriteLine("PASS: unique/path logical totals, zero-charge links, duplicate rejection, informational-only completeness, metadata deduplication/lower bounds and real uncertainty flags.");
 }
 static void FolderBlocks(){
  const int count=4205;var records=new List<MftRecord>();
  records.Add(new MftRecord {Reference=5,Directory=true});
  for(int i=1;i<=count;i++){
   ulong parent=i/3==0?5UL:(ulong)(100+i/3);
   var directory=new MftRecord {Reference=(ulong)(100+i),Directory=true,Allocated=i%5*4096,AllocationKnown=i%101!=0,AllocationIssue="fixture unknown",Reparse=i%11==0,ReparseTag=0x80000018};
   directory.Names.Add(new MftName {Parent=parent,Name="folder-"+i});records.Add(directory);
   if(i%7==0)continue;
   var file=new MftRecord {Reference=(ulong)(10000+i),HasData=true,Bytes=i*7,Allocated=i*11,AllocationKnown=i%103!=0,AllocationIssue="fixture unknown"};
   file.Names.Add(new MftName {Parent=directory.Reference,Name="file-"+i});records.Add(file);
  }
  records.Reverse();var input=records.ToArray();ScanProfile.Current=null;
  Scan expected=MftScanner.Build(@"Z:\",input,false),actual;
  try{ScanProfile.Current=new ScanProfile {UseDirectRows=true,UseCompactFolders=true,UseLazyPaths=true};actual=MftScanner.Build(@"Z:\",input,false);}
  finally{ScanProfile.Current=null;}
  Assert(actual.Nodes.Count==1 && actual.CachedRows==null,"Compact build retained intermediate folder/row objects.");
  Assert(actual.DirectRows.Paths==null && actual.DirectRows.Ids==null,"Full directory path index retained.");
  Assert(actual.Files==expected.Files && actual.IssueCount==expected.IssueCount && actual.MftUnknownAllocations==expected.MftUnknownAllocations,"Compact diagnostics/counts changed.");
  var index=new CompactIndex(actual,actual.DirectRows);Assert(index.FolderCount==count+1,"Folder block boundary lost a folder.");
  foreach(var pair in expected.Nodes){int id;Assert(index.Find(pair.Key,out id),"Folder missing across block boundary.");var folder=index.GetFolder(id);var node=pair.Value;
   Assert(folder.Logical==node.Bytes && folder.Allocated==node.Allocated && folder.Files==node.Files && folder.Partial==node.Partial && folder.Unknown==node.AllocationUnknown,"Parent-ID aggregation differs from legacy tree.");
   Assert((folder.Parent<0?null:index.GetPath(folder.Parent))==node.Parent,"Parent ID changed.");
   foreach(string sort in new[]{"name","allocated","logical"}){
    var rows=expected.CachedRows[pair.Key];var ordered=sort=="name"?rows.OrderBy(r=>r.Name,StringComparer.Ordinal):sort=="allocated"?rows.OrderByDescending(r=>r.Allocated).ThenBy(r=>r.Name,StringComparer.Ordinal):rows.OrderByDescending(r=>r.Bytes).ThenBy(r=>r.Name,StringComparer.Ordinal);
    var wanted=ordered.ToArray();var order=index.Sort(id,sort);Assert(order.Length==wanted.Length,"Child row count changed.");var page=index.Page(id,order,0,order.Length);for(int n=0;n<page.Length;n++)Same(page[n],wanted[n]);
   }
  }
  actual.DirectRows.Folders.ForcePartial=true;actual.DirectRows.Rows.ForcePartial=true;
  for(int id=0;id<index.FolderCount;id++)Assert(index.GetFolder(id).Partial,"Late folder partial flag lost.");
  Console.WriteLine("PASS: 4,206 compact folders across block boundaries match legacy aggregation, navigation, tags, uncertainty and every row/sort.");
 }
 static void PathCache(){
  var paths=new DirectoryPaths(@"Z:\");paths.Add(0,-1,"",@"Z:\");string deep=@"Z:\";int id=0;
  for(int i=0;i<2200;i++){string name="Deep-"+i;string next=deep.TrimEnd('\\')+"\\"+name;paths.Add(++id,id-1,name,next);deep=next;}
  int deepest=id;
  for(int i=0;i<5000;i++){string name="Wide-"+i;paths.Add(++id,0,name,@"Z:\"+name);}
  Assert(paths.CacheCount<=DirectoryPaths.MaxCacheEntries && paths.CacheCharacters<=DirectoryPaths.MaxCacheCharacters,"Path cache exceeded entry/character bounds.");
  int found;Assert(paths.Find(deep.ToLowerInvariant(),out found) && found==deepest,"Deep case-insensitive lookup failed after eviction.");
  Assert(paths.Get(found)==deep,"Deep reconstruction changed canonical path spelling after eviction.");
  Assert(!paths.Find(deep+"\\",out found) && !paths.Find(@"Z:\\Wide-1",out found) && !paths.Find(@"Y:\Wide-1",out found) && !paths.Find(@"Z:\missing",out found),"Malformed/outside path accepted.");
  // Long valid components below a deep parent exercise the character cap independently of entry count.
  int first=id+1;string firstName=null;
  for(int i=0;i<300;i++){string name=new string('x',180)+i;if(i==0)firstName=name;paths.Add(++id,deepest,name,deep+"\\"+name);}
  Assert(paths.CacheCount<DirectoryPaths.MaxCacheEntries && paths.CacheCharacters<=DirectoryPaths.MaxCacheCharacters,"Character limit did not evict long paths.");
  Assert(paths.Get(first)==deep+"\\"+firstName && paths.Find(deep+"\\"+firstName,out found) && found==first,"Character-cap eviction lost a directory.");
  Console.WriteLine("PASS: path cache entry/character bounds, eviction, 2,200-level nonrecursive paths, case preservation and invalid-path rejection.");
 }
 static int Main() {
  var scan=new Scan {Root=@"Z:\"};scan.CachedRows=new Dictionary<string,List<Row>>(StringComparer.OrdinalIgnoreCase);
  // Deliberately insert the root last: cache IDs cannot assume dictionary order.
  for(int i=0;i<40;i++) {
   string path=scan.Root+"folder-"+i;scan.Nodes.Add(path,new Node {Path=path,Parent=scan.Root,Bytes=i*100,Allocated=i*200,Files=i,Partial=i%2==0,AllocationUnknown=i%3==0});
   scan.CachedRows.Add(path,new List<Row>());
  }
  scan.Nodes.Add(scan.Root,new Node {Path=scan.Root});scan.CachedRows.Add(scan.Root,new List<Row>());
  var random=new Random(127);int total=0;
  for(int i=0;i<40;i++) {
   string path=scan.Root+"folder-"+i;
   scan.CachedRows[scan.Root].Add(new Row {Name="folder-"+i,Path=path,Kind="DIR",Bytes=i*100,Allocated=i*200,Partial=i%2==0,AllocationUnknown=i%3==0});total++;
   for(int j=0;j<i*20;j++) {
    string name="caf\u00e9-\u6f22\u5b57-"+j;scan.CachedRows[path].Add(new Row {Name=name,Path=path+"\\"+name,Kind=j%4==0?"LINK":(j%4==1?"RP":(j%4==2?"WCI":"FILE")),
     Bytes=random.Next(100000),Allocated=random.Next(100000),Partial=j%3==0,AllocationUnknown=j%5==0,ReparseTag=j%4==0?null:"0x80000018"});total++;
   }
  }
  var direct=new DirectRows(scan.Root);
  foreach(var pair in scan.Nodes)if(pair.Value.Parent!=null)direct.AddFolder(pair.Key,pair.Value.Parent);
  // Interleave folders and cross several block boundaries; rows are not contiguous by folder.
  for(int j=0;j<800;j++)foreach(var pair in scan.CachedRows)if(j<pair.Value.Count){var row=pair.Value[j];
   if(row.Kind!="DIR")Assert(direct.Occupy(pair.Key,row.Name),"Unique folder/name incorrectly rejected.");
   direct.Add(pair.Key,row.Name,row.Kind,row.Bytes,row.Allocated,row.AllocationUnknown,row.Partial,row.ReparseTag);
  }
  Assert(!direct.Occupy(scan.Root,"FOLDER-0"),"Directory/file collision was not rejected.");
  Assert(!direct.Occupy(scan.Root+"folder-1","CAF\u00c9-\u6f22\u5b57-0"),"Case-insensitive duplicate was not rejected.");
  direct.EndFiles();
  foreach(var index in new[]{new CompactIndex(scan),new CompactIndex(scan,direct)}) {
  Assert(index.Root==scan.Root && index.RowCount==total && index.FolderCount==scan.Nodes.Count,"Index counts/root changed.");
  foreach(var pair in scan.Nodes) {
   int id;Assert(index.Find(pair.Key.ToLowerInvariant(),out id),"Case-insensitive lookup failed.");var folder=index.GetFolder(id);
   Assert(folder.Logical==pair.Value.Bytes && folder.Allocated==pair.Value.Allocated && folder.Files==pair.Value.Files && folder.Partial==pair.Value.Partial && folder.Unknown==pair.Value.AllocationUnknown,"Folder summary changed.");
   Assert((folder.Parent<0?null:index.GetPath(folder.Parent))==pair.Value.Parent,"Parent navigation changed.");
   foreach(string sort in new[]{"allocated","logical","name"}) {
    var original=scan.CachedRows[pair.Key];Row[] expected;
    if(sort=="name") expected=original.OrderBy(r=>r.Name,StringComparer.Ordinal).ToArray();
    else if(sort=="allocated") expected=original.OrderByDescending(r=>r.Allocated).ThenBy(r=>r.Name,StringComparer.Ordinal).ToArray();
    else expected=original.OrderByDescending(r=>r.Bytes).ThenBy(r=>r.Name,StringComparer.Ordinal).ToArray();
    int[] order=index.Sort(id,sort);
    for(int offset=0;offset<expected.Length;offset+=17) {
     int count=Math.Min(17,expected.Length-offset);Row[] rows=index.Page(id,order,offset,count);
     for(int n=0;n<count;n++) Same(rows[n],expected[offset+n]);
    }
    Assert(index.Page(id,order,0,0).Length==0,"Empty page failed.");
   }
  }
  int outside;Assert(!index.Find(@"Z:\outside",out outside),"Out-of-scan path accepted.");
  }
  direct.Rows.ForcePartial=true;var partial=new CompactIndex(scan,direct);int partialId;partial.Find(scan.Root+"folder-39",out partialId);
  int[] partialOrder=partial.Sort(partialId,"name");foreach(var row in partial.Page(partialId,partialOrder,0,partialOrder.Length))Assert(row.Partial,"Late partial flag lost.");
  Console.WriteLine("PASS: legacy and direct caches, "+total+" rows, 41 folders, three sort orders, block boundaries, duplicates, late partial flags and all pages/metadata/parents match.");FolderBlocks();PathCache();Accounting();return 0;
 }
}
