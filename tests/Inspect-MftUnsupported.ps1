# Read-only investigation. Captures unsupported records from one volume scan,
# then queries a bounded sample through independent Windows metadata APIs.
[CmdletBinding()]
param([string]$Drive='C:\',[Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
try {
    $source=Get-Content (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -Raw
    $source=$source.Replace('RandomToolkits.DiskV9','RandomToolkits.DiskInvestigation1')
    $marker='if(r.Unsupported) {s.MftOmittedFiles++;'
    if (-not $source.Contains($marker)) {throw 'Scanner instrumentation marker changed; review this diagnostic.'}
    $source=$source.Replace('public class MftScanner {','public class MftScanner { public static System.Collections.Generic.List<MftRecord> UnsupportedSample = new System.Collections.Generic.List<MftRecord>();')
    $source=$source.Replace($marker,'if(r.Unsupported) {UnsupportedSample.Add(r);s.MftOmittedFiles++;')
    . ([scriptblock]::Create($source)) -NoMenu
    $reason=Get-DiskMftUnavailableReason $Drive;if($reason){throw $reason}
    Initialize-DiskScanner
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class MftMetadataProbe {
 public class StreamRow {public string Name;public long Logical,Allocated;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string p,uint a,uint s,IntPtr sec,uint c,uint f,IntPtr t);
 [DllImport("kernel32.dll",SetLastError=true)] static extern SafeFileHandle OpenFileById(SafeFileHandle h,byte[] id,uint a,uint s,IntPtr sec,uint flags);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,byte[] info);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(SafeFileHandle h,int c,byte[] info,int size);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandleW(SafeFileHandle h,StringBuilder b,uint n,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr FindFirstFileNameW(string p,uint flags,ref uint length,StringBuilder b);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool FindNextFileNameW(IntPtr h,ref uint length,StringBuilder b);
 [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr h);
 public ulong RequestedReference,ReturnedReference; public uint Attributes,Links;
 public long Allocation,Logical; public string Path,Error,LinkError; public List<string> Names=new List<string>();
 public string StreamError;public List<StreamRow> Streams=new List<StreamRow>();
 public static MftMetadataProbe Query(string root,ulong reference) {
  var r=new MftMetadataProbe {RequestedReference=reference};
  using(var volume=CreateFileW(@"\\.\"+root.Substring(0,2),0,7,IntPtr.Zero,3,0,IntPtr.Zero)) {
   if(volume.IsInvalid) {r.Error="Volume open: "+Marshal.GetLastWin32Error();return r;}
   byte[] id=new byte[24];Buffer.BlockCopy(BitConverter.GetBytes(24),0,id,0,4);Buffer.BlockCopy(BitConverter.GetBytes(reference),0,id,8,8);
   // FILE_READ_ATTRIBUTES only; OPEN_REPARSE_POINT and OPEN_NO_RECALL.
   using(var file=OpenFileById(volume,id,0x80,7,IntPtr.Zero,0x02200000|0x00100000)) {
    if(file.IsInvalid) {r.Error="OpenFileById: "+Marshal.GetLastWin32Error();return r;}
    byte[] info=new byte[52];
    if(!GetFileInformationByHandle(file,info)) {r.Error="File information: "+Marshal.GetLastWin32Error();return r;}
    r.ReturnedReference=((ulong)BitConverter.ToUInt32(info,44)<<32)|BitConverter.ToUInt32(info,48);
    if(r.ReturnedReference!=reference) {r.Error="File reference changed";return r;}
    r.Attributes=BitConverter.ToUInt32(info,0);r.Links=BitConverter.ToUInt32(info,40);
    byte[] standard=new byte[24];if(GetFileInformationByHandleEx(file,1,standard,24)) {r.Allocation=BitConverter.ToInt64(standard,0);r.Logical=BitConverter.ToInt64(standard,8);}
    else r.Error="Standard information: "+Marshal.GetLastWin32Error();
    byte[] streams=null;
    for(int capacity=4096;capacity<=1048576;capacity*=2) {
     byte[] candidate=new byte[capacity];
     if(GetFileInformationByHandleEx(file,7,candidate,capacity)) {streams=candidate;break;}
     int error=Marshal.GetLastWin32Error();if(error!=122 && error!=234) {r.StreamError="Stream query: "+error;break;}
    }
    if(streams!=null) {
     int p=0;
     while(true) {
      if(p>streams.Length-24) {r.StreamError="Stream bounds";break;}
      uint next=BitConverter.ToUInt32(streams,p),length=BitConverter.ToUInt32(streams,p+4);
      if(length%2!=0 || length>streams.Length-p-24) {r.StreamError="Stream name bounds";break;}
      r.Streams.Add(new StreamRow {Name=Encoding.Unicode.GetString(streams,p+24,(int)length),Logical=BitConverter.ToInt64(streams,p+8),Allocated=BitConverter.ToInt64(streams,p+16)});
      if(next==0) break;
      if(next%8!=0 || next<24+length || next>streams.Length-p-24) {r.StreamError="Stream offset bounds";break;}p+=(int)next;
     }
    } else if(r.StreamError==null) r.StreamError="Stream buffer limit";
    var path=new StringBuilder(32768);uint count=GetFinalPathNameByHandleW(file,path,32768,8);
    if(count==0 || count>=32768) {r.Error="Path query: "+Marshal.GetLastWin32Error();return r;} r.Path=path.ToString();
    // Query names only: no file data read or target traversal.
    uint nameCapacity=32768;var name=new StringBuilder(32768);IntPtr find=FindFirstFileNameW(r.Path,0,ref nameCapacity,name);
    if(find==new IntPtr(-1)) {r.LinkError="FindFirstFileName: "+Marshal.GetLastWin32Error();return r;}
    try {
     do {r.Names.Add(name.ToString());if(r.Names.Count>=4096){r.LinkError="Sample link limit";break;}nameCapacity=32768;name.Clear();}
     while(FindNextFileNameW(find,ref nameCapacity,name));
     if(r.LinkError==null && Marshal.GetLastWin32Error()!=38) r.LinkError="FindNextFileName: "+Marshal.GetLastWin32Error();
    } finally {FindClose(find);}
   }
  }
  return r;
 }
}
'@
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $worker=[RandomToolkits.DiskInvestigation1.MftScanner]::Start($Drive)
    $last=0
    while(-not $worker.Done) {
        if($timer.Elapsed.TotalSeconds -gt 600){$worker.CancelRequested=$true}
        if($timer.Elapsed.TotalSeconds-$last -ge 10) {
            @{Status='Running';Seconds=[int]$timer.Elapsed.TotalSeconds;Records=$worker.RecordsSeen} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath
            $last=$timer.Elapsed.TotalSeconds
        }
        Start-Sleep -Milliseconds 200
    }
    if($worker.Error){throw $worker.Error}
    $records=[RandomToolkits.DiskInvestigation1.MftScanner]::UnsupportedSample
    $groups=@($records | Group-Object { 'List='+$_.HasAttributeList+'; Known='+$_.AllocationListKnown+'; Data='+$_.HasData+'; Standard='+$_.HasStandardInformation+'; ListIssue='+$_.AttributeListIssue+'; ExtensionIssue='+$_.ExtensionIssue })
    $selected=@($records | Where-Object {($_.Reference -band 281474976710655) -in @(5030641,4373548,4330640,4319349)})
    foreach($group in $groups){$selected+=@($group.Group | Select-Object -First 3)}
    $ordinary=@($records | Where-Object HasData | Sort-Object Reference)
    for($i=0;$i -lt 48 -and $ordinary.Count;$i++) {$selected+=$ordinary[[int][math]::Floor($i*($ordinary.Count-1)/47)]}
    $samples=foreach($record in @($selected | Sort-Object Reference -Unique | Select-Object -First 64)) {
        [ordered]@{
            Index=($record.Reference -band 281474976710655);Reference=$record.Reference
            Mft=($record | Select-Object Names,HasAttributeList,AllocationListKnown,HasData,HasStandardInformation,NameAttributeCount,ExpectedNameCount,LinkCount,Reparse,ReparseTag,Bytes,Allocated,AllocationKnown,AttributeListIssue,ExtensionIssue,AllocationIssue,ExtensionReferences)
            Windows=[MftMetadataProbe]::Query($Drive,$record.Reference)
        }
    }
    $report=[ordered]@{Status='Complete';Seconds=[math]::Round($timer.Elapsed.TotalSeconds,1);Cancelled=$worker.Result.Cancelled;Unsupported=$records.Count;Causes=$worker.Result.IssueCounts;Groups=@($groups | Select-Object Name,Count);Samples=@($samples)}
    $report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $ReportPath
} catch {
    @{Status='FAIL';Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $ReportPath
    exit 1
}
