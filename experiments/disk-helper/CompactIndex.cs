using System;
using System.Collections.Generic;
using RandomToolkits.DiskV10;

namespace RandomToolkits.HelperExperiment {
 // The MFT engine owns collection. This immutable cache owns completed browsing:
 // no per-file full path, Node object, child list or per-directory row list.
 internal sealed class CompactIndex {
  internal struct Folder {
   public int Parent,Start,Count;public long Logical,Allocated,Files;public bool Partial,Unknown;
  }
  struct Entry {
   public string Name,Tag;public long Logical,Allocated;public byte Kind,Flags;
  }
  readonly Dictionary<string,int> ids;
  readonly string[] paths;
  readonly Folder[] folders;
  readonly Entry[] entries;
  public string Root {get;private set;}
  static readonly string[] Kinds={"DIR","FILE","LINK","RP","WCI"};
  public int FolderCount {get{return folders.Length;}}
  public int RowCount {get{return entries.Length;}}
  public CompactIndex(Scan scan) {
   if(scan.CachedRows==null) throw new ArgumentException("Only completed MFT caches can be compacted.");
   Root=scan.Root;ids=new Dictionary<string,int>(scan.Nodes.Count,StringComparer.OrdinalIgnoreCase);
   paths=new string[scan.Nodes.Count];folders=new Folder[paths.Length];int id=0;long count=0;
   foreach(var pair in scan.Nodes){ids.Add(pair.Key,id);paths[id++]=pair.Key;count=checked(count+scan.CachedRows[pair.Key].Count);}
   if(count>Int32.MaxValue) throw new InvalidOperationException("Too many rows for the experimental compact cache.");
   entries=new Entry[(int)count];int offset=0;var tags=new Dictionary<string,string>(StringComparer.Ordinal);
   for(id=0;id<paths.Length;id++) {
    Node node=scan.Nodes[paths[id]];var rows=scan.CachedRows[paths[id]];
    folders[id]=new Folder {Parent=node.Parent==null?-1:ids[node.Parent],Start=offset,Count=rows.Count,
     Logical=node.Bytes,Allocated=node.Allocated,Files=node.Files,Partial=node.Partial,Unknown=node.AllocationUnknown};
    foreach(Row row in rows) {
     int kind=Array.IndexOf(Kinds,row.Kind);if(kind<0) throw new InvalidOperationException("Unknown cached row type.");
     string tag=row.ReparseTag;
     if(tag!=null){string shared;if(tags.TryGetValue(tag,out shared)) tag=shared;else tags.Add(tag,tag);}
     entries[offset++]=new Entry {Name=row.Name,Tag=tag,Logical=row.Bytes,Allocated=row.Allocated,Kind=(byte)kind,
      Flags=(byte)((row.Partial?1:0)|(row.AllocationUnknown?2:0))};
    }
   }
  }
  public bool Find(string path,out int id){return ids.TryGetValue(path,out id);}
  public Folder GetFolder(int id){return folders[id];}
  public string GetPath(int id){return paths[id];}
  public int[] Sort(int id,string sort) {
   Folder folder=folders[id];int[] order=new int[folder.Count];
   for(int i=0;i<order.Length;i++) order[i]=folder.Start+i;
   Array.Sort(order,delegate(int a,int b){
    Entry left=entries[a],right=entries[b];int size=sort=="name"?0:(sort=="allocated"?right.Allocated.CompareTo(left.Allocated):right.Logical.CompareTo(left.Logical));
    return size!=0?size:StringComparer.Ordinal.Compare(left.Name,right.Name);
   });return order;
  }
  public Row[] Page(int id,int[] order,int offset,int count) {
   Row[] rows=new Row[count];string parent=paths[id].TrimEnd('\\')+"\\";
   for(int i=0;i<count;i++){
    Entry e=entries[order[offset+i]];rows[i]=new Row {Name=e.Name,Path=parent+e.Name,Kind=Kinds[e.Kind],ReparseTag=e.Tag,
     Bytes=e.Logical,Allocated=e.Allocated,Partial=(e.Flags&1)!=0,AllocationUnknown=(e.Flags&2)!=0};
   }return rows;
  }
 }
}
