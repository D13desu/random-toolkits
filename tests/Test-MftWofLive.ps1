# Creates one isolated TEMP WOF fixture. Reads metadata; never edits existing files.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
$report=[ordered]@{Status='FAIL';PowerShell=[string]$PSVersionTable.PSVersion}
try {
    . (Join-Path $PSScriptRoot '../win/disk/Disk-Usage.ps1') -NoMenu
    Initialize-DiskScanner
    $fixture=Join-Path $env:TEMP ('toolkit-wof-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory($fixture)
    $path=Join-Path $fixture 'wof.bin';$data=[byte[]]::new(1048576)
    for($i=0;$i -lt $data.Length;$i++){$data[$i]=[byte]($i%251)}
    [IO.File]::WriteAllBytes($path,$data)
    $compression=& compact /C /I /Q /EXE:LZX $path
    if($LASTEXITCODE -ne 0){throw 'WOF fixture compression failed.'}
    # Independent native query obtains the reference without reading file contents.
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;
public class WofFixtureId {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string p,uint a,uint s,IntPtr sec,uint c,uint f,IntPtr t);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,byte[] info);
 public static ulong Get(string path) {using(var h=CreateFileW(path,0x80,7,IntPtr.Zero,3,0x00300000,IntPtr.Zero)) {
  if(h.IsInvalid) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());byte[] b=new byte[52];
  if(!GetFileInformationByHandle(h,b)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  return ((ulong)BitConverter.ToUInt32(b,44)<<32)|BitConverter.ToUInt32(b,48);
 }}
}
'@
    $id=[WofFixtureId]::Get($path);$drive=[IO.Path]::GetPathRoot($path)
    $record=[RandomToolkits.DiskV10.MftScanner]::ReadRecordsForValidation($drive,[uint64[]]@($id))[0]
    $api=[RandomToolkits.DiskV10.MftApi]::Query($drive,$id)
    $issue=[RandomToolkits.DiskV10.MftApi]::Verify($drive,$record,[string[]]@($path))
    $report.Fixture=$path;$report.Compression=@($compression)
    $report.Record=$record | Select-Object Reference,Reparse,ReparseTag,Bytes,Allocated,NamedStreams
    $report.Api=$api;$report.VerificationIssue=$issue
    if(-not $record.Reparse -or $record.ReparseTag -ne [Convert]::ToUInt32('80000017',16)){throw 'Fixture did not expose the WOF tag; cannot validate the WOF path.'}
    if($null -ne $issue) {
        # A real no-follow handle can retain the reparse flag. That must stay blocked.
        if(($api.Attributes -band 0x400) -ne 0){$report.Outcome='Rejected: opened handle still reports a reparse point'}
        else {throw ('Unexpected WOF rejection: '+$issue)}
    } else {$report.Outcome='Verified: WOF metadata agrees'}
    $report.Status='PASS'
} catch {$report.Error=$_.Exception.ToString()}
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReportPath
if($report.Status -ne 'PASS'){exit 1}
