using System;
using System.Collections.Generic;
using System.Diagnostics;
namespace RandomToolkits.DiskV10 {
 public sealed class ScanProfile {
  [ThreadStatic] public static ScanProfile Current;
  readonly object gate=new object(); readonly Stopwatch timer=Stopwatch.StartNew();
  readonly List<object> samples=new List<object>();
  public volatile string Phase="starting";
  long total,single,multiple,empty,names,attributeLists,extensions;
  public static void MarkCurrent(string phase){if(Current!=null) Current.Mark(phase);}
  public static MftRecord[] TakeRecords(List<MftRecord> records){var result=records.ToArray();records.Clear();return result;}
  public void Mark(string phase){
   using(var process=Process.GetCurrentProcess()){
    var sample=new {phase=phase,seconds=timer.Elapsed.TotalSeconds,managedBytes=GC.GetTotalMemory(false),
     workingSet=process.WorkingSet64,privateBytes=process.PrivateMemorySize64,peakWorkingSet=process.PeakWorkingSet64,
     gen0=GC.CollectionCount(0),gen1=GC.CollectionCount(1),gen2=GC.CollectionCount(2)};
    lock(gate){samples.Add(sample);Phase=phase;}
   }
  }
  public void CountRecords(IEnumerable<MftRecord> records){
   long t=0,s=0,m=0,e=0,n=0,a=0,x=0;
   foreach(var r in records){t++;n+=r.Names.Count;if(r.Names.Count==1)s++;else if(r.Names.Count==0)e++;else m++;if(r.HasAttributeList)a++;if(r.BaseReference!=0)x++;}
   lock(gate){total=t;single=s;multiple=m;empty=e;names=n;attributeLists=a;extensions=x;}
  }
  public object Snapshot(){lock(gate){return new {phase=Phase,samples=samples.ToArray(),records=new {total=total,singleName=single,multipleNames=multiple,noNames=empty,names=names,attributeLists=attributeLists,extensions=extensions}};}}
 }
}
