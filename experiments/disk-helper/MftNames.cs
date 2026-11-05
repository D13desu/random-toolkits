using System;
using System.Collections;
using System.Collections.Generic;
namespace RandomToolkits.DiskV10 {
 // The common zero/one-name cases allocate no separate list or backing array.
 // Multi-name records retain ordered overflow values; no string interning.
 public sealed class MftNames : IEnumerable<MftName> {
  MftName first; List<MftName> overflow; int count;
  public int Count {get{return count;}}
  public MftName this[int index] {get {
   if(index<0 || index>=count) throw new ArgumentOutOfRangeException("index");
   return index==0?first:overflow[index-1];
  }}
  public void Add(MftName name){
   if(count==0) first=name;
   else {if(overflow==null) overflow=new List<MftName>(2);overflow.Add(name);}
   count++;
  }
  public void AddRange(IEnumerable<MftName> names){foreach(var name in names) Add(name);}
  public Enumerator GetEnumerator(){return new Enumerator(this);}
  IEnumerator<MftName> IEnumerable<MftName>.GetEnumerator(){return GetEnumerator();}
  IEnumerator IEnumerable.GetEnumerator(){return GetEnumerator();}
  public struct Enumerator : IEnumerator<MftName> {
   readonly MftNames names;int index;
   internal Enumerator(MftNames value){names=value;index=-1;}
   public bool MoveNext(){return ++index<names.Count;}
   public MftName Current {get{return names[index];}}
   object IEnumerator.Current {get{return Current;}}
   public void Reset(){index=-1;}
   public void Dispose(){}
  }
 }
}
