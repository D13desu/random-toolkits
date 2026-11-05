using System;
using System.Collections.Generic;
using RandomToolkits.HelperExperiment;
namespace RandomToolkits.DiskV10 {
 // Test-only adapter: run the actual direct writer, then materialize its paged
 // output so the unchanged shared regression assertions can inspect every row.
 public static class DirectProbe {
  public static Scan Build(string root,MftRecord[] records,bool cancelled){return Build(root,records,cancelled,null);}
  public static Scan Build(string root,MftRecord[] records,bool cancelled,Func<MftRecord,string[],string> verify){
   var previous=ScanProfile.Current;Scan scan;
   try {ScanProfile.Current=new ScanProfile {UseDirectRows=true,UseCompactFolders=true,UseLazyPaths=true};scan=MftScanner.Build(root,records,cancelled,verify);}
   finally {ScanProfile.Current=previous;}
   if(scan.CachedRows!=null || scan.DirectRows==null) throw new Exception("Direct build retained the legacy row cache.");
   if(scan.Nodes.Count!=1 || !scan.DirectRows.CompactFolders)throw new Exception("Compact folder build retained intermediate nodes.");
   if(scan.DirectRows.Lazy==null || scan.DirectRows.Paths!=null || scan.DirectRows.Ids!=null)throw new Exception("On-demand path build retained the full path index.");
   var index=new CompactIndex(scan,scan.DirectRows);
   scan.CachedRows=new Dictionary<string,List<Row>>(StringComparer.OrdinalIgnoreCase);
   for(int id=0;id<index.FolderCount;id++){string path=index.GetPath(id);var folder=index.GetFolder(id);
    scan.Nodes[path]=new Node {Path=path,Parent=folder.Parent<0?null:index.GetPath(folder.Parent),Bytes=folder.Logical,Allocated=folder.Allocated,Files=folder.Files,Partial=folder.Partial,AllocationUnknown=folder.Unknown};
    int[] order=index.Sort(id,"allocated");scan.CachedRows.Add(path,new List<Row>(index.Page(id,order,0,order.Length)));
   }
   foreach(var node in scan.Nodes.Values)if(node.Parent!=null)scan.Nodes[node.Parent].Children.Add(node.Path);
   foreach(var rows in scan.CachedRows.Values)foreach(var row in rows)if(row.Kind=="DIR")scan.Nodes[row.Path].ReparseTag=row.ReparseTag;
   return scan;
  }
 }
}
