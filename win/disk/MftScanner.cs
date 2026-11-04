// Embedded into Disk-Usage.ps1 by tests/Sync-DiskMft.ps1. No runtime download.
// Read-only Windows FSCTL_GET_NTFS_FILE_RECORD prototype; not a raw-sector reader.
namespace RandomToolkits.DiskV7 {
 public class MftStream { public string Name; public long Allocated; public bool Known; }
 public class MftName { public ulong Parent; public string Name; }
 public class MftRecord {
  public ulong Reference; public bool Directory, Reparse, Unsupported, HasData;
  public bool HasAttributeList, HasStandardInformation;
  public ulong BaseReference; public ushort LinkCount; public uint ReparseTag;
  public int NameAttributeCount;
  public string ExtensionIssue;
  public long UnnamedAllocated, Allocated;
  public bool UnnamedAllocationKnown=true, AllocationKnown, AllocationListKnown;
  public string AllocationIssue;
  public System.Collections.Generic.List<MftStream> NamedStreams;
  public System.Collections.Generic.List<string> ExpectedStreams;
  public System.Collections.Generic.List<ulong> ExtensionReferences;
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
   if((U16(b,22)&1)==0) return null;
   int used=checked((int)U32(b,24)), p=U16(b,20);
   Need(used<=b.Length && used>=48 && p>=48 && p<=used-4);
   MftRecord r=new MftRecord {Reference=(index&IndexMask)|((ulong)U16(b,16)<<48),Directory=(U16(b,22)&2)!=0,BaseReference=U64(b,32),LinkCount=U16(b,18)};
   bool end=false;
   while(p<=used-4) {
    uint type=U32(b,p); if(type==0xffffffff) {end=true;break;}
    Need(p<=used-16); int length=checked((int)U32(b,p+4));
    Need(length>=24 && length%8==0 && length<=used-p && b[p+8]<=1);
    bool nonresident=b[p+8]==1; int min=nonresident?64:24; Need(length>=min);
    if(b[p+9]!=0) {int no=U16(b,p+10);Need(no>=min && no+b[p+9]*2<=length);}
    int value=0, size=0;
    if(!nonresident) {size=checked((int)U32(b,p+16));value=U16(b,p+20);Need(value>=24 && value<=length && size<=length-value);}
    if(type==0x10) {
     // Standard information is resident in the base record. Its file attributes
     // identify reparses even when the reparse payload is in an extension record.
     Need(!nonresident && b[p+9]==0 && size>=36 && !r.HasStandardInformation);
     r.HasStandardInformation=true;
     if((U32(b,p+value+32)&0x400)!=0) r.Reparse=true;
    }
    if(type==0x20) {
     r.HasAttributeList=true;
     if(!nonresident && size>0) {
      r.ExpectedStreams=new System.Collections.Generic.List<string>();int q=p+value, limit=q+size;
      r.ExtensionReferences=new System.Collections.Generic.List<ulong>();
      while(q<limit) {
       Need(limit-q>=26);int entryLength=U16(b,q+4), chars=b[q+6], nameOffset=b[q+7];
       Need(entryLength>=26 && entryLength%8==0 && entryLength<=limit-q);
       Need(chars==0 || (nameOffset>=26 && nameOffset+chars*2<=entryLength));
       if(U32(b,q)==0x80 && U64(b,q+8)==0) r.ExpectedStreams.Add(chars==0?"":System.Text.Encoding.Unicode.GetString(b,q+nameOffset,chars*2));
       ulong reference=U64(b,q+16);if(reference!=r.Reference && !r.ExtensionReferences.Contains(reference)) r.ExtensionReferences.Add(reference);
       q+=entryLength;
      }
      r.AllocationListKnown=true;
     }
    }
    if(type==0xc0) {
     r.Reparse=true;
     if(!nonresident) {Need(size>=8 && U16(b,p+value+4)<=size-8);r.ReparseTag=U32(b,p+value);}
    }
    if(type==0x30) {
     Need(!nonresident && size>=66); int v=p+value, chars=b[v+64];
     Need(chars>0 && 66+chars*2<=size && b[v+65]<=3);
     r.NameAttributeCount++;
     if(b[v+65]!=2) { // DOS-only short name is an alias, not another hard link
      string name=System.Text.Encoding.Unicode.GetString(b,v+66,chars*2);
      Need(name.IndexOfAny(new char[]{'\\','/',':','\0'})<0 && name!="..");
      r.Names.Add(new MftName {Parent=U64(b,v),Name=name});
     }
    }
    if(type==0x80) {
     if(!nonresident || U64(b,p+16)==0) {
      string streamName=b[p+9]==0?"":System.Text.Encoding.Unicode.GetString(b,p+U16(b,p+10),b[p+9]*2);
      // Resident DATA consumes its padded payload slot inside the MFT record.
      // Windows reports that slot as stream allocation even without separate clusters.
      long allocation=nonresident?0:length-value;bool known=true;
      if(nonresident) {
       ushort flags=U16(b,p+12);bool packed=(flags&0x8001)!=0;
       if((flags&0xff)!=0 && (flags&0xff)!=1) known=false;
       else if(packed && (length<72 || U16(b,p+32)<72)) known=false;
       else {allocation=System.BitConverter.ToInt64(b,p+(packed?64:40));if(allocation<0) {known=false;allocation=0;}}
      }
      if(streamName.Length==0) {
       Need(!r.HasData); r.HasData=true;
       r.Bytes=nonresident?System.BitConverter.ToInt64(b,p+48):size; Need(r.Bytes>=0);
       r.UnnamedAllocated=allocation;r.UnnamedAllocationKnown=known;
      } else {
       if(r.NamedStreams==null) r.NamedStreams=new System.Collections.Generic.List<MftStream>();
       r.NamedStreams.Add(new MftStream {Name=streamName,Allocated=allocation,Known=known});
      }
     }
    }
    p+=length;
   }
   Need(end);
   // Directory sizes come from child records, not the directory's index extents.
   // A usable base filename plus authoritative reparse flags is sufficient to
   // connect this directory to the tree, even when its index spans extensions.
   // This is the base-only view; Assemble validates and joins extension metadata.
   r.Unsupported=r.HasAttributeList && (!r.Directory || !r.HasStandardInformation || r.Names.Count!=1);
   if(!r.Directory && !r.HasData) r.Unsupported=true;
   CalculateAllocation(r);
   return r;
  }
  public static void CalculateAllocation(MftRecord r) {
   r.Allocated=0;r.AllocationKnown=true;r.AllocationIssue=null;
   if(!r.HasAttributeList && r.NamedStreams==null) {
    r.AllocationKnown=r.UnnamedAllocationKnown && (r.Directory || r.HasData);
    if(r.HasData && r.UnnamedAllocationKnown) r.Allocated=r.UnnamedAllocated;
    if(!r.AllocationKnown) r.AllocationIssue="Unnamed stream allocation unavailable.";
    return;
   }
   var streams=new System.Collections.Generic.Dictionary<string,MftStream>(System.StringComparer.Ordinal);
   if(r.HasData) streams.Add("",new MftStream {Name="",Allocated=r.UnnamedAllocated,Known=r.UnnamedAllocationKnown});
   if(r.NamedStreams!=null) foreach(MftStream stream in r.NamedStreams) {
    if(streams.ContainsKey(stream.Name)) {streams[stream.Name]=new MftStream {Name=stream.Name,Known=false};}
    else streams.Add(stream.Name,stream);
   }
   foreach(MftStream stream in streams.Values) {
    if(stream.Known) r.Allocated=checked(r.Allocated+stream.Allocated);
    else {r.AllocationKnown=false;r.AllocationIssue="Missing, conflicting or unsupported stream allocation header.";}
   }
   if(r.HasAttributeList) {
    if(!r.AllocationListKnown || r.ExpectedStreams==null) {r.AllocationKnown=false;r.AllocationIssue="Attribute list is nonresident or unavailable; stream completeness is unknown.";}
    else {
     var expected=new System.Collections.Generic.HashSet<string>(r.ExpectedStreams,System.StringComparer.Ordinal);
     if(expected.Count!=r.ExpectedStreams.Count || !expected.SetEquals(streams.Keys)) {r.AllocationKnown=false;r.AllocationIssue="Data stream list does not match the assembled initial extents.";}
    }
   }
   if(!r.Directory && !r.HasData) {r.AllocationKnown=false;r.AllocationIssue="Unnamed data metadata unavailable.";}
  }
  public static bool IsContainer(MftRecord r) {return r.Reparse && (r.ReparseTag==0x80000018U || r.ReparseTag==0x90001018U);}
  static string Tag(MftRecord r) {return r.ReparseTag==0?"UnknownTag":"0x"+r.ReparseTag.ToString("X8");}
  public static MftRecord[] Assemble(MftRecord[] records) {
   var result=new System.Collections.Generic.List<MftRecord>();
   var bases=new System.Collections.Generic.Dictionary<ulong,MftRecord>();
   foreach(MftRecord r in records) {
    if(r==null || r.BaseReference!=0 || bases.ContainsKey(r.Reference)) continue;
    if(!r.HasAttributeList) {result.Add(r);continue;}
    // Clone only records being assembled; repeated builds must not append names twice.
    var copy=new MftRecord {Reference=r.Reference,Directory=r.Directory,Reparse=r.Reparse,Unsupported=r.Unsupported,HasData=r.HasData,HasAttributeList=true,HasStandardInformation=r.HasStandardInformation,LinkCount=r.LinkCount,NameAttributeCount=r.NameAttributeCount,ReparseTag=r.ReparseTag,Bytes=r.Bytes,UnnamedAllocated=r.UnnamedAllocated,UnnamedAllocationKnown=r.UnnamedAllocationKnown,AllocationListKnown=r.AllocationListKnown,ExpectedStreams=r.ExpectedStreams};
    if(r.NamedStreams!=null) copy.NamedStreams=new System.Collections.Generic.List<MftStream>(r.NamedStreams);
    copy.Names.AddRange(r.Names);bases.Add(copy.Reference,copy);result.Add(copy);
   }
   foreach(MftRecord extra in records) {
    if(extra==null || extra.BaseReference==0) continue;
    MftRecord owner;
    // Match the entire reference including sequence; never attach a stale extent
    // to a reused record slot. Missing data/names are detected below.
    if(!bases.TryGetValue(extra.BaseReference,out owner) || !owner.HasAttributeList) continue;
    owner.Names.AddRange(extra.Names);owner.NameAttributeCount+=extra.NameAttributeCount;owner.Reparse|=extra.Reparse;
    if(extra.ReparseTag!=0) {
     if(owner.ReparseTag!=0 && owner.ReparseTag!=extra.ReparseTag) owner.ExtensionIssue="Conflicting reparse tags in extension records.";
     owner.ReparseTag=extra.ReparseTag;
    }
    if(extra.HasStandardInformation) owner.ExtensionIssue="Unexpected standard information in an extension record.";
    if(extra.HasData) {
     if(owner.HasData) owner.ExtensionIssue="Multiple initial unnamed data attributes.";
     else {owner.HasData=true;owner.Bytes=extra.Bytes;owner.UnnamedAllocated=extra.UnnamedAllocated;owner.UnnamedAllocationKnown=extra.UnnamedAllocationKnown;}
    }
    if(extra.NamedStreams!=null) {if(owner.NamedStreams==null) owner.NamedStreams=new System.Collections.Generic.List<MftStream>();owner.NamedStreams.AddRange(extra.NamedStreams);}
   }
   foreach(MftRecord r in bases.Values) {
    if(!r.HasAttributeList) continue;
    var unique=new System.Collections.Generic.HashSet<string>(System.StringComparer.Ordinal);
    var names=new System.Collections.Generic.List<MftName>();
    foreach(MftName n in r.Names) if(unique.Add(n.Parent.ToString()+":"+n.Name)) names.Add(n);
    r.Names=names;
    // NTFS's header count includes separate DOS FILE_NAME attributes. Retain
    // those in the completeness check but never display/count them as extra files.
    r.Unsupported=r.ExtensionIssue!=null || !r.HasStandardInformation || r.Names.Count==0 ||
      (r.Directory ? r.Names.Count!=1 : (!r.HasData || r.LinkCount==0 || r.NameAttributeCount!=r.LinkCount));
    CalculateAllocation(r);
    if(r.ExtensionIssue!=null) {r.AllocationKnown=false;r.AllocationIssue=r.ExtensionIssue;}
   }
   return result.ToArray();
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
   // This is a graph of local MFT parent IDs. Reparse payloads and target paths
   // are never followed. Their own local DATA allocation can therefore be counted
   // even when the tag is unknown, without traversing a junction or hydrating data.
   records=Assemble(records);
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
     else if(cur.Unsupported) failure=new Issue {Category="DirectoryAttributeList",Reason="Incomplete/conflicting extension metadata: "+Describe(cur)+"; "+(cur.ExtensionIssue??"missing name or base standard flags")};
     else if(cur.Names.Count!=1) failure=new Issue {Category="DirectoryNames",Reason="Expected one directory name; found "+cur.Names.Count+" on "+Describe(cur)};
     if(failure!=null) {blocked[cur.Reference]=failure;valid=false;break;}
     chain.Add(cur); ulong parent=cur.Names[0].Parent;
     if(paths.ContainsKey(parent)) break;
     MftRecord parentRecord;
     if(!dirs.TryGetValue(parent,out parentRecord)) {
      bool metadata=(parent&IndexMask)<16;
      failure=new Issue {Category=metadata?"DirectorySystemMetadata":"DirectoryParentMissing",Reason=Describe(cur)+" requires parent MFT #"+(parent&IndexMask)+" (sequence "+(parent>>48)+"). "+(metadata?"NTFS system metadata tree intentionally excluded.":"Parent absent, changed or unparsed.")};valid=false;break;
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
     paths.Add(r.Reference,path); s.Nodes.Add(path,new Node {Path=path,Parent=parent,Allocated=r.Allocated,AllocationUnknown=!r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null});
     s.Nodes[parent].Children.Add(path); s.CachedRows.Add(path,new System.Collections.Generic.List<Row>());
     if(r.Reparse) {s.MftReparseDirectories++;if(r.ReparseTag==0) s.MftUnknownTags++;}
     if(!r.AllocationKnown) {s.MftUnknownAllocations++;Issue(s,Describe(r),r.AllocationIssue,"AllocationUnknown");}
    }
    if(!valid) {s.MftOmittedDirectories++;Issue(s,Describe(start),"Duplicate directory path; volume may have changed during scan.","DuplicateDirectory");}
   }
   var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);
   foreach(MftRecord r in records) {
    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;
    if(r.Unsupported) {s.MftOmittedFiles++;Issue(s,Describe(r),"Incomplete/conflicting metadata: data="+r.HasData+", standardInfo="+r.HasStandardInformation+", name attributes="+r.NameAttributeCount+", header count="+r.LinkCount+"; "+r.ExtensionIssue,"FileUnsupported");continue;}
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
     long allocated=charged?0:r.Allocated;node.Allocated=checked(node.Allocated+allocated);
     if(!charged) {
      node.Files++;s.Files++;
      if(r.Reparse && (r.ReparseTag&0xffff0fffU)==0x9000001aU) {s.MftCloudFiles++;s.MftCloudBytes=checked(s.MftCloudBytes+r.Bytes);}
      if(IsContainer(r)) {s.MftContainerFiles++;s.MftContainerBytes=checked(s.MftContainerBytes+r.Bytes);s.MftContainerAllocated=checked(s.MftContainerAllocated+r.Allocated);}
      if(r.Reparse) {s.MftReparseFiles++;if(r.ReparseTag==0) s.MftUnknownTags++;}
      if(!r.AllocationKnown) {node.AllocationUnknown=true;s.MftUnknownAllocations++;Issue(s,Describe(r),r.AllocationIssue,"AllocationUnknown");}
     }
     s.CachedRows[pair.Value].Add(new Row {Name=System.IO.Path.GetFileName(pair.Key),Path=pair.Key,Kind=charged?"LINK":(IsContainer(r)?"WCI":(r.Reparse?"RP":"FILE")),Bytes=bytes,Allocated=allocated,AllocationUnknown=!charged && !r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null}); charged=true;
    }
    if(!charged) s.MftOmittedFiles++;
    // At most one diagnostic per file: do not count each missing parent and then count the file again.
    if(linkFailure!=null || !charged) Issue(s,Describe(r),linkFailure??"No resolvable filename; file omitted.",charged?"PartialFileLinks":"FilePathUnresolved");
   }
   var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);
   order.Sort(delegate(Node a,Node b){return b.Path.Length.CompareTo(a.Path.Length);});
   foreach(Node n in order) if(n.Parent!=null) {Node parent=s.Nodes[n.Parent];parent.Bytes=checked(parent.Bytes+n.Bytes);parent.Allocated=checked(parent.Allocated+n.Allocated);parent.AllocationUnknown|=n.AllocationUnknown;parent.Files+=n.Files;}
   // Unresolved records cannot reliably be attributed to a folder: conservatively flag all totals.
   if(cancelled) Issue(s,root,"Cancelled: only records read so far are included; unresolved paths are omitted.");
   if(s.IssueCount>0) foreach(Node n in s.Nodes.Values) n.Partial=true;
   foreach(Node n in s.Nodes.Values) {
    foreach(string p in n.Children) {Node child=s.Nodes[p];s.CachedRows[n.Path].Add(new Row {Name=System.IO.Path.GetFileName(p),Path=p,Kind="DIR",Bytes=child.Bytes,Allocated=child.Allocated,AllocationUnknown=child.AllocationUnknown,Partial=child.Partial,ReparseTag=child.ReparseTag});}
    s.CachedRows[n.Path].Sort(delegate(Row a,Row b){int c=b.Allocated.CompareTo(a.Allocated);return c!=0?c:System.StringComparer.Ordinal.Compare(a.Name,b.Name);});
   }
   s.Finished=System.DateTime.Now; return s;
  }
  public static MftScanner Start(string root) {
   MftScanner w=new MftScanner();w.Result.Root=root;
   var t=new System.Threading.Thread(w.Run);t.IsBackground=true;t.Start();return w;
  }
  // Targeted validation of newly created fixture files, not a whole-volume scan.
  public static MftRecord[] ReadRecordsForValidation(string root,ulong[] references) {
   if(root.Length!=3 || root[1]!=':' || root[2]!='\\' || references.Length>128) throw new System.ArgumentException("Invalid bounded record request.");
   var records=new System.Collections.Generic.List<MftRecord>();var seen=new System.Collections.Generic.HashSet<ulong>();
   var queue=new System.Collections.Generic.Queue<ulong>(references);
   using(var handle=CreateFileW(@"\\.\"+root.Substring(0,2),0x80000000,7,System.IntPtr.Zero,3,0,System.IntPtr.Zero)) {
    if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    byte[] volume=new byte[128];int returned;
    if(!DeviceIoControl(handle,0x90064,null,0,volume,volume.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
    Need(returned>=104 && U16(volume,100)==3 && U16(volume,102)<=1);
    int recordSize=checked((int)U32(volume,48));Need(recordSize>=512 && recordSize<=65536);byte[] output=new byte[recordSize+16];
    while(queue.Count>0) {
     ulong reference=queue.Dequeue();if(!seen.Add(reference)) continue;Need(seen.Count<=128);
     byte[] input=System.BitConverter.GetBytes(reference&IndexMask);
     if(!DeviceIoControl(handle,0x90068,input,8,output,output.Length,out returned,System.IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
     Need(returned>=12 && (U64(output,0)&IndexMask)==(reference&IndexMask));int size=checked((int)U32(output,8));Need(size>=48 && size<=recordSize && size<=returned-12);
     byte[] bytes=new byte[size];System.Buffer.BlockCopy(output,12,bytes,0,size);MftRecord r=Parse(bytes,reference&IndexMask);
     Need(r!=null && ((reference>>48)==0 || r.Reference==reference));records.Add(r);
     if(r.ExtensionReferences!=null) foreach(ulong extra in r.ExtensionReferences) queue.Enqueue(extra);
    }
   }
   return Assemble(records.ToArray());
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
     lines.Add(Describe(r)+"; directory="+r.Directory+"; reparse="+r.Reparse+"; tag="+Tag(r)+"; baseOnlyUnsupported="+r.Unsupported+"; attributeList="+r.HasAttributeList+"; standardInfo="+r.HasStandardInformation+"; data="+r.HasData+"; names="+r.Names.Count+"; links="+r.LinkCount);
     if(r.HasAttributeList) lines.Add("Base-record view only: a full scan assembles names/data from matching extension records.");
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
      try {MftRecord r=Parse(record,actual);if(r!=null && actual!=5) {records.Add(r);if(r.BaseReference==0) {if(r.Directory) DirectoriesSeen++;else {System.Threading.Interlocked.Increment(ref FilesSeen);System.Threading.Interlocked.Add(ref BytesSeen,r.Bytes);}}}}
      catch(System.IO.InvalidDataException ex) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": "+ex.Message);}
      catch(System.OverflowException) {errorCount++;if(errors.Count<100) errors.Add("MFT #"+actual+": oversized record field.");}
      System.Threading.Interlocked.Increment(ref RecordsSeen);
      if(actual==0) break;next=actual-1;
     }
     Result=Build(root,records.ToArray(),CancelRequested);Result.Started=started;
     try {var drive=new System.IO.DriveInfo(root);Result.VolumeUsed=drive.TotalSize-drive.TotalFreeSpace;} catch { }
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
