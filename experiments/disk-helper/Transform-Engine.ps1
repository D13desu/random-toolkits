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
        $new="for(int recordIndex=0;recordIndex<records.Length;recordIndex++) {`n    MftRecord r=records[recordIndex];records[recordIndex]=null;`n    if(r==null || r.Directory || (r.Reference&IndexMask)<16) continue;"
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
    return $prefix+$Source+$suffix
}
