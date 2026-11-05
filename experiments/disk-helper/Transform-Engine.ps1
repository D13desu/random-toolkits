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
    return $prefix+$Source+$suffix
}
