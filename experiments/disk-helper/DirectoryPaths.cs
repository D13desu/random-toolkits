using System;
using System.Collections.Generic;
using System.Text;
namespace RandomToolkits.HelperExperiment {
 // Directory identity is (parent ID, name), never a retained full path.
 internal sealed class DirectoryPaths {
  struct Key : IEquatable<Key> {
   internal int Parent;internal string Name;
   public bool Equals(Key other){return Parent==other.Parent && StringComparer.OrdinalIgnoreCase.Equals(Name,other.Name);}
   public override bool Equals(object other){return other is Key && Equals((Key)other);}
   public override int GetHashCode(){return unchecked(Parent*397)^StringComparer.OrdinalIgnoreCase.GetHashCode(Name);}
  }
  struct Part {internal int Parent;internal string Name;}
  sealed class Cached {internal int Id;internal string Path;}
  const int Shift=12,Size=1<<Shift,Mask=Size-1;
  internal const int MaxCacheEntries=4096,MaxCacheCharacters=2097152;
  readonly List<Part[]> parts=new List<Part[]>();
  readonly Dictionary<Key,int> children=new Dictionary<Key,int>();
  readonly Dictionary<int,LinkedListNode<Cached>> cache=new Dictionary<int,LinkedListNode<Cached>>();
  readonly Dictionary<string,int> reverse=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
  readonly LinkedList<Cached> recent=new LinkedList<Cached>();
  readonly string root;int count,characters;
  internal DirectoryPaths(string root){this.root=root;}
  internal int CacheCount {get{return cache.Count;}}
  internal int CacheCharacters {get{return characters;}}
  Part PartAt(int id){if(id<0 || id>=count)throw new ArgumentOutOfRangeException("id");return parts[id>>Shift][id&Mask];}
  internal string Name(int id){return PartAt(id).Name;}
  internal void Add(int id,int parent,string name,string canonicalPath){
   if(id!=count || (id==0?parent!=-1:parent<0 || parent>=id))throw new InvalidOperationException("Invalid directory path order.");
   if(id!=0)children.Add(new Key {Parent=parent,Name=name},id);
   if((id&Mask)==0)parts.Add(new Part[Size]);parts[id>>Shift][id&Mask]=new Part {Parent=parent,Name=name};count++;
   if(id!=0) Remember(id,canonicalPath);
  }
  void Remember(int id,string path){
   if(path.Length>MaxCacheCharacters)return;
   LinkedListNode<Cached> found;if(cache.TryGetValue(id,out found)){recent.Remove(found);recent.AddFirst(found);return;}
   var node=recent.AddFirst(new Cached {Id=id,Path=path});cache.Add(id,node);reverse.Add(path,id);characters+=path.Length;
   while(cache.Count>MaxCacheEntries || characters>MaxCacheCharacters){var last=recent.Last;recent.RemoveLast();cache.Remove(last.Value.Id);reverse.Remove(last.Value.Path);characters-=last.Value.Path.Length;}
  }
  internal string Get(int id){
   if(id==0)return root;LinkedListNode<Cached> hit;
   if(cache.TryGetValue(id,out hit)){recent.Remove(hit);recent.AddFirst(hit);return hit.Value.Path;}
   var suffix=new List<int>();int current=id;string prefix=root;
   while(current!=0){if(cache.TryGetValue(current,out hit)){prefix=hit.Value.Path;break;}suffix.Add(current);current=PartAt(current).Parent;}
   var builder=new StringBuilder(prefix.TrimEnd('\\'));
   for(int i=suffix.Count-1;i>=0;i--)builder.Append('\\').Append(PartAt(suffix[i]).Name);
   string result=builder.ToString();Remember(id,result);return result;
  }
  internal bool Find(string path,out int id){
   id=-1;if(path==null)return false;
   if(StringComparer.OrdinalIgnoreCase.Equals(path,root)){id=0;return true;}
   if(reverse.TryGetValue(path,out id))return true;
   if(!path.StartsWith(root,StringComparison.OrdinalIgnoreCase) || path.Length<=root.Length || path[path.Length-1]=='\\' || path.IndexOf("\\\\",StringComparison.Ordinal)>=0){id=-1;return false;}
   int last=path.LastIndexOf('\\'),parent;
   string parentPath=last==root.Length-1?root:path.Substring(0,last);
   if(StringComparer.OrdinalIgnoreCase.Equals(parentPath,root))parent=0;
   else if(!reverse.TryGetValue(parentPath,out parent))parent=-1;
   if(parent>=0)return children.TryGetValue(new Key {Parent=parent,Name=path.Substring(last+1)},out id);
   parent=0;int start=root.Length;
   while(start<path.Length){int end=path.IndexOf('\\',start);if(end<0)end=path.Length;if(end==start){id=-1;return false;}
    if(!children.TryGetValue(new Key {Parent=parent,Name=path.Substring(start,end-start)},out id))return false;
    parent=id;start=end+1;
   }
   id=parent;return true;
  }
 }
 // Full sequence-bearing MFT references remain authoritative; only the mapped
 // value changes from a full path to a compact folder ID.
 internal sealed class ResolvedPaths {
  readonly DirectRows direct;readonly Dictionary<ulong,int> ids;readonly Dictionary<ulong,string> paths;
  internal ResolvedPaths(DirectRows direct){this.direct=direct;if(direct!=null && direct.Lazy!=null)ids=new Dictionary<ulong,int>();else paths=new Dictionary<ulong,string>();}
  internal int Count {get{return ids!=null?ids.Count:paths.Count;}}
  internal bool ContainsKey(ulong reference){return ids!=null?ids.ContainsKey(reference):paths.ContainsKey(reference);}
  internal string this[ulong reference] {get{return ids!=null?direct.PathForId(ids[reference]):paths[reference];}set{if(ids!=null)ids[reference]=direct.IdForPath(value);else paths[reference]=value;}}
  internal void Add(ulong reference,string path){if(ids!=null)ids.Add(reference,direct.IdForPath(path));else paths.Add(reference,path);}
  internal bool TryGetValue(ulong reference,out string path){if(ids==null)return paths.TryGetValue(reference,out path);int id;if(!ids.TryGetValue(reference,out id)){path=null;return false;}path=direct.PathForId(id);return true;}
 }
}
