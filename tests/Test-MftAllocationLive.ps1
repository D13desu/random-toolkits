# Elevated, bounded validation: creates isolated TEMP fixtures and reads only
# their MFT records (plus referenced extensions). No production file changes.
[CmdletBinding()]
param([string]$ReportPath)
$ErrorActionPreference='Stop'
$report=[ordered]@{Status='FAIL';PowerShell=[string]$PSVersionTable.PSVersion;Rows=@();Error=$null;Fixture=$null}
try {
    if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator token required for bounded MFT validation.' }
    . (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
    Initialize-DiskScanner
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class AllocationOracle {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string p,uint a,uint s,IntPtr sec,uint c,uint f,IntPtr t);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,byte[] b);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandleEx(SafeFileHandle h,int c,byte[] b,int size);
 public ulong Reference; public long Allocated, Logical;
 public static AllocationOracle Query(string path) {
  using(var h=CreateFileW(path,0x80,7,IntPtr.Zero,3,0,IntPtr.Zero)) {
   if(h.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
   byte[] info=new byte[52], standard=new byte[24];
   if(!GetFileInformationByHandle(h,info) || !GetFileInformationByHandleEx(h,1,standard,24)) throw new Win32Exception(Marshal.GetLastWin32Error());
   var r=new AllocationOracle {Reference=((ulong)BitConverter.ToUInt32(info,44)<<32)|BitConverter.ToUInt32(info,48),Allocated=BitConverter.ToInt64(standard,0),Logical=BitConverter.ToInt64(standard,8)};
   if((BitConverter.ToUInt32(info,0)&0xa00)!=0) {
    byte[] compressed=new byte[16];
    if(!GetFileInformationByHandleEx(h,8,compressed,16)) throw new Win32Exception(Marshal.GetLastWin32Error());
    r.Allocated=BitConverter.ToInt64(compressed,0);
   }
   return r;
  }
 }
}
'@
    $fixture=Join-Path $env:TEMP ('toolkit-allocation-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory($fixture);$report.Fixture=$fixture
    $files=@()
    foreach ($entry in @(@('resident.bin',17),@('ordinary.bin',8193),@('compressed.bin',1048576),@('streams.bin',5000))) {
        $path=Join-Path $fixture $entry[0];$data=[byte[]]::new([int]$entry[1])
        if ($entry[0] -eq 'compressed.bin') { $pattern=[byte[]](0..255);for ($i=0;$i -lt $data.Length;$i+=256) {[Array]::Copy($pattern,0,$data,$i,256)} }
        [IO.File]::WriteAllBytes($path,$data);$files+=$path
    }
    $sparse=Join-Path $fixture 'sparse.bin';[IO.File]::WriteAllBytes($sparse,[byte[]]::new(0))
    $null=& fsutil sparse setflag $sparse;if ($LASTEXITCODE -ne 0) { throw 'Sparse fixture setup failed.' }
    $stream=[IO.File]::OpenWrite($sparse);try { $stream.SetLength(16777216);$stream.Position=0;$stream.Write([byte[]]::new(4096),0,4096) } finally {$stream.Dispose()}
    $files+=$sparse
    $null=& compact /C /I /Q (Join-Path $fixture 'compressed.bin');if ($LASTEXITCODE -ne 0) { throw 'Compression fixture setup failed.' }
    $streamBase=Join-Path $fixture 'streams.bin';$ads=$streamBase+':payload'
    if ($PSVersionTable.PSVersion.Major -ge 6) { Set-Content -LiteralPath $streamBase -Stream payload -Value ([byte[]]::new(12000)) -AsByteStream }
    else { Set-Content -LiteralPath $streamBase -Stream payload -Value ([byte[]]::new(12000)) -Encoding Byte }
    $alias=Join-Path $fixture 'ordinary-link.bin';$null=New-Item -ItemType HardLink -Path $alias -Target (Join-Path $fixture 'ordinary.bin')
    $files+=$alias
    $oracles=@{}; $ids=New-Object 'System.Collections.Generic.List[uint64]'
    foreach ($path in $files) { $oracle=[AllocationOracle]::Query($path);$oracles[$path]=$oracle;if (-not $ids.Contains($oracle.Reference)) {$ids.Add($oracle.Reference)} }
    $records=[RandomToolkits.DiskV9.MftScanner]::ReadRecordsForValidation([IO.Path]::GetPathRoot($fixture),$ids.ToArray())
    foreach ($path in $files) {
        $oracle=$oracles[$path];$record=@($records | Where-Object { $_.Reference -eq $oracle.Reference })
        if ($record.Count -ne 1) { throw "Missing fixture record: $path" }
        $allocated=$oracle.Allocated
        if ([IO.Path]::GetFileName($path) -eq 'streams.bin') { $allocated+=[AllocationOracle]::Query($ads).Allocated }
        $pass=$record[0].AllocationKnown -and $record[0].Allocated -eq $allocated -and $record[0].Bytes -eq $oracle.Logical
        $paths=[string[]]@($files | Where-Object {$oracles[$_].Reference -eq $oracle.Reference})
        $apiIssue=[RandomToolkits.DiskV9.MftApi]::Verify([IO.Path]::GetPathRoot($fixture),$record[0],$paths)
        $pass=$pass -and $null -eq $apiIssue
        $report.Rows+=@{File=[IO.Path]::GetFileName($path);Logical=$oracle.Logical;WindowsAllocated=$allocated;MftAllocated=$record[0].Allocated;Known=$record[0].AllocationKnown;Pass=$pass;Detail=$record[0].AllocationIssue;ApiIssue=$apiIssue}
    }
    if (@($report.Rows | Where-Object { -not $_.Pass }).Count) { throw 'Allocation differs from independent Windows API results.' }
    if ($oracles[$alias].Reference -ne $oracles[(Join-Path $fixture 'ordinary.bin')].Reference) { throw 'Hard-link identity mismatch.' }
    $report.Status='PASS'
} catch { $report.Error=$_.Exception.ToString()+"`n"+$_.ScriptStackTrace }
finally {
    $json=$report | ConvertTo-Json -Depth 6
    if ($ReportPath) { [IO.File]::WriteAllText($ReportPath,$json,[Text.UTF8Encoding]::new($false)) }
    $json | Write-Output
}
if ($report.Status -ne 'PASS') { exit 1 }
