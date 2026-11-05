using System;
using System.Collections.Generic;
using System.IO;
using RandomToolkits.DiskV10;
namespace RandomToolkits.HelperExperiment {
 // Fixed-size blocks avoid copying a growing multi-million-entry array.
 internal sealed class PackedRows {
  const int Shift=12, Size=1<<Shift, Mask=Size-1;
  readonly List<CompactIndex.Entry[]> blocks=new List<CompactIndex.Entry[]>();
  readonly List<int[]> links=new List<int[]>();
  internal int Count; internal bool ForcePartial;
  internal int Add(CompactIndex.Entry entry){
   if(Count==Int32.MaxValue) throw new InvalidOperationException("Too many compact rows.");
   int index=Count;if((index&Mask)==0){blocks.Add(new CompactIndex.Entry[Size]);links.Add(new int[Size]);}
   blocks[index>>Shift][index&Mask]=entry;links[index>>Shift][index&Mask]=-1;Count++;return index;
  }
  internal CompactIndex.Entry Get(int index){var entry=blocks[index>>Shift][index&Mask];if(ForcePartial) entry.Flags|=1;return entry;}
  internal int Next(int index){return links[index>>Shift][index&Mask];}
  internal void Link(int index,int next){links[index>>Shift][index&Mask]=next;}
 }
 internal sealed class PackedFolders {
  internal struct Item {internal int Parent,Head,Tail,Count;internal long Logical,Allocated,Files;internal bool Unknown,Partial;}
  const int Shift=12,Size=1<<Shift,Mask=Size-1;
  readonly List<Item[]> blocks=new List<Item[]>();
  internal int Count;internal bool ForcePartial;
  internal void Add(Item item){if(Count==Int32.MaxValue)throw new InvalidOperationException("Too many folders.");if((Count&Mask)==0)blocks.Add(new Item[Size]);blocks[Count>>Shift][Count&Mask]=item;Count++;}
  internal Item Get(int id){var item=blocks[id>>Shift][id&Mask];if(ForcePartial)item.Partial=true;return item;}
  internal void Set(int id,Item item){blocks[id>>Shift][id&Mask]=item;}
 }
 internal sealed class DirectRows {
  struct Key : IEquatable<Key> {
   internal int Parent; internal string Name;
   public bool Equals(Key other){return Parent==other.Parent && StringComparer.OrdinalIgnoreCase.Equals(Name,other.Name);}
   public override bool Equals(object other){return other is Key && Equals((Key)other);}
   public override int GetHashCode(){return unchecked(Parent*397)^StringComparer.OrdinalIgnoreCase.GetHashCode(Name);}
  }
  internal readonly Dictionary<string,int> Ids=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
  internal readonly List<string> Paths=new List<string>();
  internal readonly PackedFolders Folders=new PackedFolders();
  internal readonly bool CompactFolders;
  List<string> folderTags=new List<string>();
  internal readonly PackedRows Rows=new PackedRows();
  HashSet<Key> occupied=new HashSet<Key>();
  readonly Dictionary<string,string> tags=new Dictionary<string,string>(StringComparer.Ordinal);
  internal DirectRows(string root):this(root,false){}
  internal DirectRows(string root,bool compactFolders){CompactFolders=compactFolders;AddFolder(root,null);}
  internal void AddFolder(string path,string parent){
   int id=Paths.Count,parentId=parent==null?-1:Ids[parent];Ids.Add(path,id);Paths.Add(path);Folders.Add(new PackedFolders.Item {Parent=parentId,Head=-1,Tail=-1});folderTags.Add(null);
   if(parent!=null) occupied.Add(new Key {Parent=Ids[parent],Name=Path.GetFileName(path)});
  }
  internal bool Occupy(string parent,string name){return occupied.Add(new Key {Parent=Ids[parent],Name=name});}
  internal void Add(string parent,string name,string kind,long logical,long allocated,bool unknown,bool partial,string tag){
   int id=Ids[parent],code=Array.IndexOf(CompactIndex.Kinds,kind);
   if(code<0) throw new InvalidOperationException("Unknown compact row kind.");
   if(tag!=null){string shared;if(tags.TryGetValue(tag,out shared)) tag=shared;else tags.Add(tag,tag);}
   int index=Rows.Add(new CompactIndex.Entry {Name=name,Tag=tag,Kind=(byte)code,Logical=logical,Allocated=allocated,Flags=(byte)((partial?1:0)|(unknown?2:0))});
   var chain=Folders.Get(id);if(chain.Tail>=0) Rows.Link(chain.Tail,index);else chain.Head=index;
   chain.Tail=index;chain.Count++;Folders.Set(id,chain);
  }
  internal void SetMetadata(string path,long allocated,bool unknown,string tag){int id=Ids[path];var folder=Folders.Get(id);folder.Allocated=allocated;folder.Unknown=unknown;Folders.Set(id,folder);folderTags[id]=tag;}
  internal void Charge(string path,long logical,long allocated,bool file,bool unknown){int id=Ids[path];var folder=Folders.Get(id);folder.Logical=checked(folder.Logical+logical);folder.Allocated=checked(folder.Allocated+allocated);if(file)folder.Files++;folder.Unknown|=unknown;Folders.Set(id,folder);}
  internal void Aggregate(Scan scan){
   // Resolution creates parents before children. Reverse IDs are a topological order.
   for(int id=Folders.Count-1;id>0;id--){var child=Folders.Get(id);if(child.Parent<0 || child.Parent>=id)throw new InvalidOperationException("Invalid compact parent order.");var parent=Folders.Get(child.Parent);
    parent.Logical=checked(parent.Logical+child.Logical);parent.Allocated=checked(parent.Allocated+child.Allocated);parent.Files=checked(parent.Files+child.Files);parent.Unknown|=child.Unknown;Folders.Set(child.Parent,parent);
   }
   Folders.ForcePartial=scan.IssueCount>0;
   for(int id=1;id<Folders.Count;id++){var folder=Folders.Get(id);Add(Paths[folder.Parent],Path.GetFileName(Paths[id]),"DIR",folder.Logical,folder.Allocated,folder.Unknown,folder.Partial,folderTags[id]);}
   folderTags=null;
   var totals=Folders.Get(0);var root=scan.Nodes[scan.Root];root.Bytes=totals.Logical;root.Allocated=totals.Allocated;root.Files=totals.Files;root.AllocationUnknown=totals.Unknown;root.Partial=totals.Partial;
  }
  internal void EndFiles(){occupied=null;}
 }
}
