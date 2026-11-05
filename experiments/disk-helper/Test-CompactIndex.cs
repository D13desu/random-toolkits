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
  Console.WriteLine("PASS: legacy and direct caches, "+total+" rows, 41 folders, three sort orders, block boundaries, duplicates, late partial flags and all pages/metadata/parents match.");return 0;
 }
}
