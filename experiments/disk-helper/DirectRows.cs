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
 internal sealed class DirectRows {
  internal struct Chain {internal int Head,Tail,Count;}
  struct Key : IEquatable<Key> {
   internal int Parent; internal string Name;
   public bool Equals(Key other){return Parent==other.Parent && StringComparer.OrdinalIgnoreCase.Equals(Name,other.Name);}
   public override bool Equals(object other){return other is Key && Equals((Key)other);}
   public override int GetHashCode(){return unchecked(Parent*397)^StringComparer.OrdinalIgnoreCase.GetHashCode(Name);}
  }
  internal readonly Dictionary<string,int> Ids=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
  internal readonly List<string> Paths=new List<string>();
  internal readonly List<Chain> Chains=new List<Chain>();
  internal readonly PackedRows Rows=new PackedRows();
  HashSet<Key> occupied=new HashSet<Key>();
  readonly Dictionary<string,string> tags=new Dictionary<string,string>(StringComparer.Ordinal);
  internal DirectRows(string root){AddFolder(root,null);}
  internal void AddFolder(string path,string parent){
   int id=Paths.Count;Ids.Add(path,id);Paths.Add(path);Chains.Add(new Chain {Head=-1,Tail=-1});
   if(parent!=null) occupied.Add(new Key {Parent=Ids[parent],Name=Path.GetFileName(path)});
  }
  internal bool Occupy(string parent,string name){return occupied.Add(new Key {Parent=Ids[parent],Name=name});}
  internal void Add(string parent,string name,string kind,long logical,long allocated,bool unknown,bool partial,string tag){
   int id=Ids[parent],code=Array.IndexOf(CompactIndex.Kinds,kind);
   if(code<0) throw new InvalidOperationException("Unknown compact row kind.");
   if(tag!=null){string shared;if(tags.TryGetValue(tag,out shared)) tag=shared;else tags.Add(tag,tag);}
   int index=Rows.Add(new CompactIndex.Entry {Name=name,Tag=tag,Kind=(byte)code,Logical=logical,Allocated=allocated,Flags=(byte)((partial?1:0)|(unknown?2:0))});
   var chain=Chains[id];if(chain.Tail>=0) Rows.Link(chain.Tail,index);else chain.Head=index;
   chain.Tail=index;chain.Count++;Chains[id]=chain;
  }
  internal void EndFiles(){occupied=null;}
 }
}
