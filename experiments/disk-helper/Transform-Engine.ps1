# Experiment-only, checked source adaptations. Production scanner files stay untouched.
function ConvertTo-HelperEngine([string]$Source,[switch]$CompactNames,[switch]$ReleaseRecords) {
    $start=$Source.IndexOf('// BEGIN EMBEDDED MFT SCANNER')
    $end=$Source.IndexOf('// END EMBEDDED MFT SCANNER')
    if($start -lt 0 -or $end -le $start){throw 'MFT source markers missing.'}
    $prefix=$Source.Substring(0,$start);$suffix=$Source.Substring($end)
    $Source=$Source.Substring($start,$end-$start)
    function Replace-One([string]$Text,[string]$Old,[string]$New) {
        if(([regex]::Matches($Text,[regex]::Escape($Old))).Count -ne 1){throw "Engine adaptation anchor changed: $Old"}
        return $Text.Replace($Old,$New)
    }
    $Source=Replace-One $Source 'public Scan Result=new Scan(); public volatile bool Done, CancelRequested;' 'public ScanProfile Profile=new ScanProfile(); public Scan Result=new Scan(); public volatile bool Done, CancelRequested;'
    $Source=Replace-One $Source 'string root=Result.Root; System.DateTime started=System.DateTime.Now;' 'ScanProfile.Current=Profile; Profile.Mark("record collection"); string root=Result.Root; System.DateTime started=System.DateTime.Now;'
    $Source=Replace-One $Source 'if(!CancelRequested) CompleteExtensions(handle,records,volume,recordSize);' 'Profile.Mark("extension completion"); Profile.CountRecords(records); if(!CancelRequested) CompleteExtensions(handle,records,volume,recordSize);'
    $Source=Replace-One $Source 'records=Assemble(records);' 'ScanProfile.MarkCurrent("extension assembly"); records=Assemble(records); ScanProfile.MarkCurrent("directory paths");'
    $Source=Replace-One $Source 'var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);' 'ScanProfile.MarkCurrent("file paths and API verification"); var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);'
    $Source=Replace-One $Source 'var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);' 'ScanProfile.MarkCurrent("aggregation and row sorting"); var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);'
    $Source=Replace-One $Source 'finally {Done=true;}' 'finally {Profile.Mark("scan complete"); ScanProfile.Current=null; Done=true;}'
    if($CompactNames){
        $Source=Replace-One $Source 'public long Bytes; public System.Collections.Generic.List<MftName> Names = new System.Collections.Generic.List<MftName>();' 'public long Bytes; public MftNames Names=new MftNames();'
        $Source=Replace-One $Source 'var names=new System.Collections.Generic.List<MftName>();' 'var names=new MftNames();'
    }
    if($ReleaseRecords){
        # Only the worker owns and consumes this list. Public Build callers retain their inputs.
        $Source=Replace-One $Source 'Result=Build(root,records.ToArray(),CancelRequested,' 'Result=Build(root,ScanProfile.TakeRecords(records),CancelRequested,'
        $Source=Replace-One $Source 'ScanProfile.MarkCurrent("file paths and API verification");' 'dirs.Clear(); pending.Clear(); ScanProfile.MarkCurrent("file paths and API verification");'
        $old="foreach(MftRecord r in records) {`n    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;"
        $new=@'
for(int recordIndex=0;recordIndex<records.Length;recordIndex++) {
    MftRecord r=records[recordIndex];records[recordIndex]=null;
    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;
    if(direct!=null && direct.Lazy!=null && r.Names.Count==1 && !r.Unsupported && r.AllocationKnown) {
     MftName single=r.Names[0];int parentId;
     if(paths.TryGetId(single.Parent,out parentId) && direct.Occupy(parentId,single.Name)) {
      direct.Charge(parentId,r.Bytes,r.Allocated,true,false);s.Files++;
      if(r.Reparse && (r.ReparseTag&0xffff0fffU)==0x9000001aU) {s.MftCloudFiles++;s.MftCloudBytes=checked(s.MftCloudBytes+r.Bytes);}
      if(IsContainer(r)) {s.MftContainerFiles++;s.MftContainerBytes=checked(s.MftContainerBytes+r.Bytes);s.MftContainerAllocated=checked(s.MftContainerAllocated+r.Allocated);}
      if(r.Reparse) {s.MftReparseFiles++;if(r.ReparseTag==0) s.MftUnknownTags++;}
      if(r.LinkCountMismatch) Issue(s,Describe(r),"Included using verified attribute-list filenames; header link count differs (names="+r.NameAttributeCount+", header="+r.LinkCount+").","IncludedLinkCountMismatch");
      direct.Add(parentId,single.Name,IsContainer(r)?"WCI":(r.Reparse?"RP":"FILE"),r.Bytes,r.Allocated,false,false,r.Reparse?Tag(r):null);
      s.Accounting.IncludePath(r.Bytes,false);continue;
     }
    }
'@
        $Source=Replace-One $Source $old $new
    }
    $prefix=Replace-One $prefix 'public Dictionary<string,List<Row>> CachedRows;' 'internal RandomToolkits.HelperExperiment.DirectRows DirectRows; public Dictionary<string,List<Row>> CachedRows;'
    $Source=Replace-One $Source 's.CachedRows=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.List<Row>>(System.StringComparer.OrdinalIgnoreCase);' 'var direct=ScanProfile.Current!=null && ScanProfile.Current.UseDirectRows ? new RandomToolkits.HelperExperiment.DirectRows(root):null; s.DirectRows=direct; if(direct==null) s.CachedRows=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.List<Row>>(System.StringComparer.OrdinalIgnoreCase);'
    $Source=Replace-One $Source 's.CachedRows.Add(root,new System.Collections.Generic.List<Row>());' 'if(direct==null) s.CachedRows.Add(root,new System.Collections.Generic.List<Row>());'
    $Source=Replace-One $Source 's.CachedRows.Add(path,new System.Collections.Generic.List<Row>());' 'if(direct==null) s.CachedRows.Add(path,new System.Collections.Generic.List<Row>());else direct.AddFolder(path,parent);'
    $Source=Replace-One $Source 'var occupied=new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase);' 'var occupied=direct==null?new System.Collections.Generic.HashSet<string>(s.Nodes.Keys,System.StringComparer.OrdinalIgnoreCase):null;'
    $Source=Replace-One $Source 'if(!occupied.Add(pair.Key))' 'string fileName=System.IO.Path.GetFileName(pair.Key); if(!(direct==null?occupied.Add(pair.Key):direct.Occupy(pair.Value,fileName)))'
    $old='s.CachedRows[pair.Value].Add(new Row {Name=System.IO.Path.GetFileName(pair.Key),Path=pair.Key,Kind=charged?"LINK":(IsContainer(r)?"WCI":(r.Reparse?"RP":"FILE")),Bytes=bytes,Allocated=allocated,AllocationUnknown=!charged && !r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null}); charged=true;'
    $new='if(direct!=null) direct.Add(pair.Value,fileName,charged?"LINK":(IsContainer(r)?"WCI":(r.Reparse?"RP":"FILE")),bytes,allocated,!charged && !r.AllocationKnown,false,r.Reparse?Tag(r):null);else '+$old
    # The charged state must advance in both paths.
    $new=$new.Replace('}); charged=true;','});')+' charged=true;'
    $Source=Replace-One $Source $old $new
    $Source=Replace-One $Source 'ScanProfile.MarkCurrent("aggregation and row sorting");' 'if(direct!=null) direct.EndFiles(); ScanProfile.MarkCurrent("aggregation and row sorting");'
    $old='s.CachedRows[n.Path].Add(new Row {Name=System.IO.Path.GetFileName(p),Path=p,Kind="DIR",Bytes=child.Bytes,Allocated=child.Allocated,AllocationUnknown=child.AllocationUnknown,Partial=child.Partial,ReparseTag=child.ReparseTag});'
    $Source=Replace-One $Source $old ('if(direct!=null) direct.Add(n.Path,System.IO.Path.GetFileName(p),"DIR",child.Bytes,child.Allocated,child.AllocationUnknown,child.Partial,child.ReparseTag);else '+$old)
    $Source=Replace-One $Source 's.CachedRows[n.Path].Sort(' 'if(direct==null) s.CachedRows[n.Path].Sort('
    $old='foreach(var list in Result.CachedRows.Values) foreach(Row row in list) row.Partial=true;'
    if(([regex]::Matches($Source,[regex]::Escape($old))).Count -ne 2){throw 'Late partial-result adaptation anchors changed.'}
    $Source=$Source.Replace($old,'if(Result.DirectRows!=null) Result.DirectRows.Rows.ForcePartial=true;else '+$old)
    $Source=Replace-One $Source 'new RandomToolkits.HelperExperiment.DirectRows(root):null' 'new RandomToolkits.HelperExperiment.DirectRows(root,ScanProfile.Current.UseCompactFolders):null'
    $Source=Replace-One $Source 'if(s.Nodes.ContainsKey(path))' 'if(direct!=null && direct.CompactFolders?direct.Ids.ContainsKey(path):s.Nodes.ContainsKey(path))'
    $Source=Replace-One $Source 'paths.Add(r.Reference,path); s.Nodes.Add(path,new Node {Path=path,Parent=parent,Allocated=r.Allocated,AllocationUnknown=!r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null});' 'paths.Add(r.Reference,path); if(direct==null || !direct.CompactFolders) s.Nodes.Add(path,new Node {Path=path,Parent=parent,Allocated=r.Allocated,AllocationUnknown=!r.AllocationKnown,ReparseTag=r.Reparse?Tag(r):null});'
    $Source=Replace-One $Source 's.Nodes[parent].Children.Add(path);' 'if(direct==null || !direct.CompactFolders) s.Nodes[parent].Children.Add(path);'
    $Source=Replace-One $Source 'else direct.AddFolder(path,parent);' 'else {direct.AddFolder(path,parent);if(direct.CompactFolders) direct.SetMetadata(path,r.Allocated,!r.AllocationKnown,r.Reparse?Tag(r):null);}'
    if($ReleaseRecords){$Source=Replace-One $Source 'dirs.Clear(); pending.Clear(); ScanProfile.MarkCurrent("file paths and API verification");' 'dirs.Clear(); pending.Clear(); if(direct!=null && direct.CompactFolders) {ScanProfile.MarkCurrent("retiring directory records");for(int retire=0;retire<records.Length;retire++)if(records[retire]!=null && records[retire].Directory)records[retire]=null;System.GC.Collect(2,System.GCCollectionMode.Forced,true,true);} ScanProfile.MarkCurrent("file paths and API verification");'}
    $old="long bytes=charged?0:r.Bytes; var node=s.Nodes[pair.Value]; node.Bytes=checked(node.Bytes+bytes);`n     long allocated=charged?0:r.Allocated;node.Allocated=checked(node.Allocated+allocated);"
    $new='long bytes=charged?0:r.Bytes,allocated=charged?0:r.Allocated; Node node=null; if(direct!=null && direct.CompactFolders) direct.Charge(pair.Value,bytes,allocated,!charged,!charged && !r.AllocationKnown);else {node=s.Nodes[pair.Value];node.Bytes=checked(node.Bytes+bytes);node.Allocated=checked(node.Allocated+allocated);}'
    $Source=Replace-One $Source $old $new
    $Source=Replace-One $Source 'node.Files++;s.Files++;' 'if(node!=null) node.Files++;s.Files++;'
    $Source=Replace-One $Source 'node.AllocationUnknown=true;s.MftUnknownAllocations++;' 'if(node!=null) node.AllocationUnknown=true;s.MftUnknownAllocations++;'
    $Source=Replace-One $Source 'var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);' 'if(direct!=null && direct.CompactFolders) {if(cancelled) Issue(s,root,"Cancelled: only records read so far are included; unresolved paths are omitted.");direct.Aggregate(s);}else {var order=new System.Collections.Generic.List<Node>(s.Nodes.Values);'
    $Source=Replace-One $Source 's.Finished=System.DateTime.Now; return s;' '} s.Finished=System.DateTime.Now; return s;'
    $old='if(Result.DirectRows!=null) Result.DirectRows.Rows.ForcePartial=true;'
    if(([regex]::Matches($Source,[regex]::Escape($old))).Count -ne 2){throw 'Compact folder partial anchors changed.'}
    $Source=$Source.Replace($old,'if(Result.DirectRows!=null) {Result.DirectRows.Rows.ForcePartial=true;Result.DirectRows.Folders.ForcePartial=true;}')
    $Source=Replace-One $Source 'new RandomToolkits.HelperExperiment.DirectRows(root,ScanProfile.Current.UseCompactFolders)' 'new RandomToolkits.HelperExperiment.DirectRows(root,ScanProfile.Current.UseCompactFolders,ScanProfile.Current.UseLazyPaths)'
    $Source=Replace-One $Source 'var paths=new System.Collections.Generic.Dictionary<ulong,string>();' 'var paths=new RandomToolkits.HelperExperiment.ResolvedPaths(direct);'
    $Source=Replace-One $Source 'direct.Ids.ContainsKey(path)' 'direct.ContainsPath(path)'
    $Source=Replace-One $Source 'paths.Add(r.Reference,path); if(direct==null || !direct.CompactFolders)' 'if(direct==null || !direct.CompactFolders)'
    $Source=Replace-One $Source 'direct.SetMetadata(path,r.Allocated,!r.AllocationKnown,r.Reparse?Tag(r):null);}' 'direct.SetMetadata(path,r.Allocated,!r.AllocationKnown,r.Reparse?Tag(r):null);} paths.Add(r.Reference,path);'
    $prefix=Replace-One $prefix 'internal RandomToolkits.HelperExperiment.DirectRows DirectRows;' 'internal RandomToolkits.HelperExperiment.ScanAccounting Accounting; internal RandomToolkits.HelperExperiment.DirectRows DirectRows;'
    $Source=Replace-One $Source 'Scan s=new Scan {Root=root,Engine="Experimental NTFS MFT records",Cancelled=cancelled};' 'Scan s=new Scan {Root=root,Engine="Experimental NTFS MFT records",Cancelled=cancelled}; s.Accounting=new RandomToolkits.HelperExperiment.ScanAccounting(); foreach(MftRecord core in records)if(core!=null && (core.Reference&IndexMask)<16)s.Accounting.Metadata(core,true);'
    $Source=Replace-One $Source 'scan.IssueCount++; scan.Nodes[scan.Root].Partial=true;' 'scan.IssueCount++; if(category!="IncludedLinkCountMismatch")scan.Nodes[scan.Root].Partial=true;'
    $Source=Replace-One $Source 'if(s.IssueCount>0) foreach(Node n in s.Nodes.Values) n.Partial=true;' 'if(RandomToolkits.HelperExperiment.ScanAccounting.HasIncompleteTotals(s)) foreach(Node n in s.Nodes.Values) n.Partial=true;'
    $Source=Replace-One $Source 'blocked[start.Reference]=failure;s.MftOmittedDirectories++;' 'blocked[start.Reference]=failure;s.MftOmittedDirectories++;if(failure.Category=="DirectorySystemMetadata")s.Accounting.Metadata(start,false);'
    $Source=Replace-One $Source 'if(names.Count==0 && linkFailure!=null && metadataOnly) {s.MftOmittedFiles++;' 'if(names.Count==0 && linkFailure!=null && metadataOnly) {s.Accounting.Metadata(r,false);s.MftOmittedFiles++;'
    $Source=Replace-One $Source 'charged=true;' 's.Accounting.IncludePath(r.Bytes,charged);charged=true;'
    return $prefix+$Source+$suffix
}
