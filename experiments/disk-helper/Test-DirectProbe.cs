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
   try {ScanProfile.Current=new ScanProfile {UseDirectRows=true};scan=MftScanner.Build(root,records,cancelled,verify);}
   finally {ScanProfile.Current=previous;}
   if(scan.CachedRows!=null || scan.DirectRows==null) throw new Exception("Direct build retained the legacy row cache.");
   var index=new CompactIndex(scan,scan.DirectRows);
   scan.CachedRows=new Dictionary<string,List<Row>>(StringComparer.OrdinalIgnoreCase);
   foreach(string path in scan.Nodes.Keys){int id;if(!index.Find(path,out id))throw new Exception("Direct folder missing.");
    int[] order=index.Sort(id,"allocated");scan.CachedRows.Add(path,new List<Row>(index.Page(id,order,0,order.Length)));
   }
   return scan;
  }
 }
}
