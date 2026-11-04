// Embedded into Disk-Usage.ps1 by tests/Sync-DiskMft.ps1. No runtime download.
// Read-only Windows FSCTL_GET_NTFS_FILE_RECORD prototype; not a raw-sector reader.
namespace RandomToolkits.DiskV4 {
 public class MftName { public ulong Parent; public string Name; }
 public class MftRecord {
  public ulong Reference; public bool Directory, Reparse, Unsupported, HasData;
  public long Bytes; public System.Collections.Generic.List<MftName> Names = new System.Collections.Generic.List<MftName>();
 }
 public class MftScanner {
  [System.Runtime.InteropServices.DllImport("kernel32.dll",CharSet=System.Runtime.InteropServices.CharSet.Unicode,SetLastError=true)]
  static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(string path,uint access,uint share,System.IntPtr security,uint creation,uint flags,System.IntPtr template);
  [System.Runtime.InteropServices.DllImport("kernel32.dll",SetLastError=true)]
  [return:System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
  static extern bool DeviceIoControl(Microsoft.Win32.SafeHandles.SafeFileHandle handle,uint code,byte[] input,int inputSize,byte[] output,int outputSize,out int returned,System.IntPtr overlapped);
  const ulong IndexMask=0x0000ffffffffffffUL;
  public Scan Result=new Scan(); public volatile bool Done, CancelRequested;
  public string Error; public long FilesSeen, BytesSeen, RecordsSeen; public int DirectoriesSeen;
  public Row[] Snapshot() { return new Row[0]; }
  static ushort U16(byte[] b,int p) { return System.BitConverter.ToUInt16(b,p); }
  static uint U32(byte[] b,int p) { return System.BitConverter.ToUInt32(b,p); }
  static ulong U64(byte[] b,int p) { return System.BitConverter.ToUInt64(b,p); }
  static void Need(bool valid) { if(!valid) throw new System.IO.InvalidDataException("Invalid or unsupported NTFS record bounds."); }
  // The FSCTL returns a filesystem-managed record. It does not require raw-sector USA fixups.
  public static MftRecord Parse(byte[] b,ulong index) {
   Need(b!=null && b.Length>=48 && U32(b,0)==0x454c4946);
   if((U16(b,22)&1)==0 || U64(b,32)!=0) return null; // unused or extension: base record exclusions cover extensions
   int used=checked((int)U32(b,24)), p=U16(b,20);
   Need(used<=b.Length && used>=48 && p>=48 && p<=used-4);
   MftRecord r=new MftRecord {Reference=(index&IndexMask)|((ulong)U16(b,16)<<48),Directory=(U16(b,22)&2)!=0};
   bool end=false;
   while(p<=used-4) {
    uint type=U32(b,p); if(type==0xffffffff) {end=true;break;}
    Need(p<=used-16); int length=checked((int)U32(b,p+4));
    Need(length>=24 && length%8==0 && length<=used-p && b[p+8]<=1);
    bool nonresident=b[p+8]==1; int min=nonresident?64:24; Need(length>=min);
    if(b[p+9]!=0) {int no=U16(b,p+10);Need(no>=min && no+b[p+9]*2<=length);}
    int value=0, size=0;
    if(!nonresident) {size=checked((int)U32(b,p+16));value=U16(b,p+20);Need(value>=24 && value<=length && size<=length-value);}
    if(type==0x20) r.Unsupported=true; // Attribute lists may move names/data into extension records; omit whole file.
    if(type==0xc0) r.Reparse=true;
    if(type==0x30) {
     Need(!nonresident && size>=66); int v=p+value, chars=b[v+64];
     Need(chars>0 && 66+chars*2<=size && b[v+65]<=3);
     if(b[v+65]!=2) { // DOS-only short name is an alias, not another hard link
      string name=System.Text.Encoding.Unicode.GetString(b,v+66,chars*2);
      Need(name.IndexOfAny(new char[]{'\\','/',':','\0'})<0 && name!="..");
      r.Names.Add(new MftName {Parent=U64(b,v),Name=name});
     }
    }
    if(type==0x80 && b[p+9]==0) {
     if(!nonresident || U64(b,p+16)==0) {
      Need(!r.HasData); r.HasData=true;
      r.Bytes=nonresident?System.BitConverter.ToInt64(b,p+48):size; Need(r.Bytes>=0);
     }
    }
    p+=length;
   }
   Need(end); if(!r.Directory && !r.HasData) r.Unsupported=true;
   return r;
  }
  static void Issue(Scan scan,string path,string reason,string category="Other") {
   scan.IssueCount++; scan.Nodes[scan.Root].Partial=true;
   int count;scan.IssueCounts.TryGetValue(category,out count);scan.IssueCounts[category]=count+1;
   // Reserve examples for every cause instead of filling all slots with one repeated failure.
   if(count<4 && scan.Issues.Count<100) scan.Issues.Add(new Issue {Path=path,Reason=reason,Category=category});
  }
  static string Describe(MftRecord r) {
   return "MFT #"+(r.Reference&IndexMask)+" (sequence "+(r.Reference>>48)+", name: "+(r.Names.Count==0?"<none>":r.Names[0].Name)+")";
  }
  // Deterministic ownership: a hard-linked file is charged to its first ordinal path only.
  // Other links remain visible with zero charged bytes, labelled LINK.
  public static Scan Build(string root,MftRecord[] records,bool cancelled) {
   Scan s=new Scan {Root=root,Engine="Experimental NTFS MFT records",Cancelled=cancelled};
   s.CachedRows=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.List<Row>>(System.StringComparer.OrdinalIgnoreCase);
   s.Nodes.Add(root,new Node {Path=root}); s.CachedRows.Add(root,new System.Collections.Generic.List<Row>());
   var dirs=new System.Collections.Generic.Dictionary<ulong,MftRecord>();
   var paths=new System.Collections.Generic.Dictionary<ulong,string>();
   var pending=new System.Collections.Generic.List<MftRecord>();
   var blocked=new System.Collections.Generic.Dictionary<ulong,Issue>();
   foreach(MftRecord r in records) {
    if(r==null) continue;
    if((r.Reference&IndexMask)==5) {paths[r.Reference]=root;continue;}
    if((r.Reference&IndexMask)<16) continue; // NTFS system records are not user file totals
    if(r.Directory) {if(!dirs.ContainsKey(r.Reference)) {dirs.Add(r.Reference,r);pending.Add(r);}}
   }
   if(paths.Count==0) Issue(s,root,"Root record missing; paths cannot be reconstructed.");
   // Resolve paths without recursive stack growth. Reject missing/reused parents and cycles.
   foreach(MftRecord start in pending) {
    if(paths.ContainsKey(start.Reference)) continue;
    var chain=new System.Collections.Generic.List<MftRecord>(); var seen=new System.Collections.Generic.HashSet<ulong>();
    MftRecord cur=start; bool valid=true;Issue failure=null;
    while(!paths.ContainsKey(cur.Reference)) {
     if(blocked.TryGetValue(cur.Reference,out failure)) {valid=false;break;}
     if(!seen.Add(cur.Reference)) failure=new Issue {Category="DirectoryCycle",Reason="Parent cycle at "+Describe(cur)};
     else if(cur.Reparse) failure=new Issue {Category="DirectoryReparse",Reason="Reparse directory excluded: "+Describe(cur)};
     else if(cur.Unsupported) failure=new Issue {Category="DirectoryAttributeList",Reason="Directory requires extension records: "+Describe(cur)};
     else if(cur.Names.Count!=1) failure=new Issue {Category="DirectoryNames",Reason="Expected one directory name; found "+cur.Names.Count+" on "+Describe(cur)};
     if(failure!=null) {blocked[cur.Reference]=failure;valid=false;break;}
     chain.Add(cur); ulong parent=cur.Names[0].Parent;
     if(paths.ContainsKey(parent)) break;
     MftRecord parentRecord;
     if(!dirs.TryGetValue(parent,out parentRecord)) {
      failure=new Issue {Category="DirectoryParentMissing",Reason=Describe(cur)+" requires absent parent MFT #"+(parent&IndexMask)+" (sequence "+(parent>>48)+"). Parent may be excluded, changed or unparsed."};valid=false;break;
     }
     cur=parentRecord;
    }
    if(!valid) {
     foreach(MftRecord r in chain) blocked[r.Reference]=failure;
     blocked[start.Reference]=failure;s.MftOmittedDirectories++;
     Issue(s,Describe(start),failure.Reason,failure.Category);continue;
    }
    for(int i=chain.Count-1;i>=0;i--) {
     MftRecord r=chain[i]; string parent=paths[r.Names[0].Parent]; string path=parent.TrimEnd('\\')+"\\"+r.Names[0].Name;
     if(s.Nodes.ContainsKey(path)) {valid=false;break;}
     paths.Add(r.Reference,path); s.Nodes.Add(path,new Node {Path=path,Parent=parent});
     s.Nodes[parent].Children.Add(path); s.CachedRows.Add(path,new System.Collections.Generic.List<Row>());
    }
    if(!valid) {s.MftOmittedDirectories++;Issue(s,Describe(start),"Duplicate directory path; volume may have changed during scan.","DuplicateDirectory");}
   }
   var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);
   foreach(MftRecord r in records) {
    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;
    if(r.Reparse || r.Unsupported) {s.MftOmittedFiles++;Issue(s,Describe(r),r.Reparse?"Reparse file excluded.":"Attribute list or missing unnamed data; file excluded.",r.Reparse?"FileReparse":"FileUnsupported");continue;}
    var names=new System.Collections.Generic.SortedDictionary<string,string>(System.StringComparer.Ordinal);
    string linkFailure=null;
    foreach(MftName n in r.Names) {
     string parent; if(!paths.TryGetValue(n.Parent,out parent)) {
      Issue cause;
      if(linkFailure==null) linkFailure="Unresolved parent MFT #"+(n.Parent&IndexMask)+" (sequence "+(n.Parent>>48)+") for "+n.Name+(blocked.TryGetValue(n.Parent,out cause)?"; "+cause.Reason:"; parent absent or changed.");
      continue;
     }
     string path=parent.TrimEnd('\\')+"\\"+n.Name; names[path]=parent;
    }
    bool charged=false;
    foreach(var pair in names) {
     if(!occupied.Add(pair.Key)) {if(linkFailure==null) linkFailure="Duplicate path: "+pair.Key+"; file may have changed during scanning.";continue;}
     long bytes=charged?0:r.Bytes; var node=s.Nodes[pair.Value]; node.Bytes=checked(node.Bytes+bytes);
     if(!charged) {node.Files++;s.Files++;}
     s.CachedRows[pair.Value].Add(new Row {Name=System.IO.Path.GetFileName(pair.Key),Path=pair.Key,Kind=charged?"LINK":"FILE",Bytes=bytes}); charged=true;
    }
    if(!charged) s.MftOmittedFiles++;
    // At most one diagnostic per file: do not count each missing parent and then count the file again.
    if(linkFailure!=null || !charged) Issue(s,Describe(r),linkFailure??"No resolvable filename; file omitted.",charged?"PartialFileLinks":"FilePathUnresolved");
   }
   var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);
   order.Sort(delegate(Node a,Node b){return b.Path.Length.CompareTo(a.Path.Length);});
   foreach(Node n in order) if(n.Parent!=null) {Node parent=s.Nodes[n.Parent];parent.Bytes=checked(parent.Bytes+n.Bytes);parent.Files+=n.Files;}
   // Unresolved records cannot reliably be attributed to a folder: conservatively flag all totals.
   if(cancelled) Issue(s,root,"Cancelled: only records read so far are included; unresolved paths are omitted.");
   if(s.IssueCount>0) foreach(Node n in s.Nodes.Values) n.Partial=true;
   foreach(Node n in s.Nodes.Values) {
    foreach(string p in n.Children) {Node child=s.Nodes[p];s.CachedRows[n.Path].Add(new Row {Name=System.IO.Path.GetFileName(p),Path=p,Kind="DIR",Bytes=child.Bytes,Partial=child.Partial});}
    s.CachedRows[n.Path].Sort(delegate(Row a,Row b){int c=b.Bytes.CompareTo(a.Bytes);return c!=0?c:System.StringComparer.Ordinal.Compare(a.Name,b.Name);});
   }
   s.Finished=System.DateTime.Now; return s;
  }
  public static MftScanner Start(string root) {
   MftScanner w=new MftScanner();w.Result.Root=root;
   var t=new System.Threading.Thread(w.Run);t.IsBackground=true;t.Start();return w;
  }
  // Bounded read-only diagnostic: inspect one record and its parent chain, not a full scan.
  public static string[] Inspect(string root,ulong index) {
   if(root.Length!=3 || root[1]!=':' || root[2]!='\\') throw new System.ArgumentException("Select a local drive root.");
   var lines=new System.Collections.Generic.List<string>();var seen=new System.Collections.Generic.HashSet<ulong>();
   using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
    if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    byte[] volume=new byte[128];int returned;
    if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    Need(returned>=104 && U16(volume,100)==3 && U16(volume,102)<=1);
    int recordSize=checked((int)U32(volume,48));Need(recordSize>=512 && recordSize<=65536);
    byte[] output=new byte[recordSize+16];ulong expectedReference=0;
    for(int depth=0;depth<64;depth++) {
     if(!seen.Add(index)) {lines.Add("Parent cycle detected.");break;}
     byte[] input=System.BitConverter.GetBytes(index);
     if(!DeviceIoControl(handle,0x90068,input,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12);ulong actual=U64(output,0)&IndexMask;int size=checked((int)U32(output,8));Need(size>=48 && size<=recordSize && size<=returned-12);
     byte[] record=new byte[size];System.Buffer.BlockCopy(output,12,record,0,size);
     lines.Add("Requested #"+index+"; returned #"+actual+"; header record number="+U32(record,44)+"; flags="+U16(record,22)+"; base reference="+U64(record,32));
     if(actual!=index) {lines.Add("Requested record no longer in use; stopping at nearest record returned by Windows.");break;}
     MftRecord r;
     try {r=Parse(record,actual);} catch(System.Exception ex) {lines.Add("Parse failed: "+ex.Message);break;}
     if(r==null) {lines.Add("Extension or unused record; no standalone path.");break;}
     lines.Add(Describe(r)+"; directory="+r.Directory+"; reparse="+r.Reparse+"; unsupported="+r.Unsupported+"; data="+r.HasData+"; names="+r.Names.Count);
     foreach(MftName n in r.Names) lines.Add("  Name="+n.Name+"; parent #"+(n.Parent&IndexMask)+"; parent sequence="+(n.Parent>>48));
     if(expectedReference!=0 && r.Reference!=expectedReference) {lines.Add("Parent sequence mismatch: record was reused or changed.");break;}
     if(actual==5 || r.Names.Count!=1) break;
     expectedReference=r.Names[0].Parent;index=expectedReference&IndexMask;
     if(depth==63) lines.Add("Stopped at diagnostic depth limit (64).");
    }
   }
   return lines.ToArray();
  }
  void Run() {
   string root=Result.Root; System.DateTime started=System.DateTime.Now;
   try {
    if(root.Length!=3 || root[1]!=':' || root[2]!='\\') throw new System.ArgumentException("MFT mode requires a drive root, e.g. C:\\.");
    using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
     if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     byte[] volume=new byte[128];int returned;
     if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=104 && U32(volume,96)>=8 && U16(volume,100)==3 && U16(volume,102)<=1);
     int recordSize=checked((int)U32(volume,48)); long length=System.BitConverter.ToInt64(volume,56);
     Need(recordSize>=512 && recordSize<=65536 && length>=recordSize && length%recordSize==0);
     ulong next=(ulong)(length/recordSize-1);byte[] output=new byte[recordSize+16];
     var records=new System.Collections.Generic.List<MftRecord>();var errors=new System.Collections.Generic.List<string>();int errorCount=0;
     // Seed the root before descending so cancellation can still resolve top-level names.
     byte[] rootInput=System.BitConverter.GetBytes((ulong)5);
     if(!DeviceIoControl(handle,0x90068,rootInput,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12 && (U64(output,0)&IndexMask)==5);int rootSize=checked((int)U32(output,8));
     Need(rootSize>=48 && rootSize<=recordSize && rootSize<=returned-12);
     byte[] rootRecord=new byte[rootSize];System.Buffer.BlockCopy(output,12,rootRecord,0,rootSize);
     MftRecord rootEntry=Parse(rootRecord,5);Need(rootEntry!=null && rootEntry.Directory);records.Add(rootEntry);
     while(!CancelRequested) {
      byte[] input=System.BitConverter.GetBytes(next);
      if(!DeviceIoControl(handle,0x90068,input,input.Length,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
      Need(returned>=12);ulong actual=U64(output,0)&IndexMask;int size=checked((int)U32(output,8));
      Need(actual<=next && size>=48 && size<=recordSize && size<=returned-12);
      byte[] record=new byte[size];System.Buffer.BlockCopy(output,12,record,0,size);
      try {MftRecord r=Parse(record,actual);if(r!=null && actual!=5) {records.Add(r);if(r.Directory) DirectoriesSeen++;else {System.Threading.Interlocked.Increment(ref FilesSeen);System.Threading.Interlocked.Add(ref BytesSeen,r.Bytes);}}}
      catch(System.IO.InvalidDataException ex) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": "+ex.Message);}
      catch(System.OverflowException) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": oversized record field.");}
      System.Threading.Interlocked.Increment(ref RecordsSeen);
      if(actual==0) break;next=actual-1;
     }
     Result=Build(root,records.ToArray(),CancelRequested);Result.Started=started;
     if(CancelRequested && !Result.Cancelled) {
      Result.Cancelled=true;Issue(Result,root,"Cancellation requested during tree reconstruction.");
      foreach(Node n in Result.Nodes.Values) n.Partial=true;
      foreach(var list in Result.CachedRows.Values) foreach(Row row in list) row.Partial=true;
     }
     if(errorCount>0) {
      foreach(string e in errors) Issue(Result,root,e,"RecordParseFailure");
      Result.IssueCount+=errorCount-errors.Count;Result.IssueCounts["RecordParseFailure"]=errorCount;
      foreach(Node n in Result.Nodes.Values) n.Partial=true;
      foreach(var list in Result.CachedRows.Values) foreach(Row row in list) row.Partial=true;
     }
     Result.MftRecordErrors=errorCount;Result.MftRecordsRead=RecordsSeen;
    }
   } catch(System.Exception ex) {Error=ex.Message;}
   finally {Done=true;}
  }
 }
}
