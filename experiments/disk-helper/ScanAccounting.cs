using System;
using System.Collections.Generic;
using RandomToolkits.DiskV10;
namespace RandomToolkits.HelperExperiment {
 internal sealed class ScanAccounting {
  long uniqueFiles,entries,links,uniqueLogical,linkLogical;
  long coreRecords,coreAllocated,coreUnknown,excludedFiles,excludedDirectories,excludedAllocated,excludedUnknown;
  int coreSamples,fileSamples,directorySamples;
  readonly HashSet<ulong> metadata=new HashSet<ulong>();
  readonly List<object> samples=new List<object>();
  internal void IncludePath(long bytes,bool additionalLink){
   entries=checked(entries+1);linkLogical=checked(linkLogical+bytes);
   if(additionalLink)links=checked(links+1);else{uniqueFiles=checked(uniqueFiles+1);uniqueLogical=checked(uniqueLogical+bytes);}
  }
  internal void Metadata(MftRecord record,bool core){
   if(!metadata.Add(record.Reference))return;
   bool badClusterMap=core && (record.Reference&0x0000ffffffffffffUL)==8;
   // $BadClus:$Bad requires validation of mapped non-sparse runs. Its header
   // value can describe the volume span; do not present that as used space.
   long allocated=badClusterMap?0:Math.Max(0,record.Allocated);bool unknown=badClusterMap || !record.AllocationKnown || record.Allocated<0;
   bool sample;
   if(core){coreRecords++;coreAllocated=checked(coreAllocated+allocated);if(unknown)coreUnknown++;sample=coreSamples++<16;}
   else{if(record.Directory)excludedDirectories++;else excludedFiles++;excludedAllocated=checked(excludedAllocated+allocated);if(unknown)excludedUnknown++;sample=record.Directory?directorySamples++<4:fileSamples++<8;}
   if(sample)samples.Add(new {record=record.Reference&0x0000ffffffffffffUL,sequence=record.Reference>>48,
    name=record.Names.Count==0?"<unnamed>":record.Names[0].Name,directory=record.Directory,
    group=core?"Core NTFS record":"Excluded metadata tree",knownDataAllocation=allocated,allocationUnknown=unknown,
    note=badClusterMap?"Unmeasured bad-cluster map; header allocation not counted.":null});
  }
  internal static string Kind(string cause){
   if(cause=="IncludedLinkCountMismatch")return "Information (included)";
   if(cause=="DirectorySystemMetadata" || cause=="FileSystemMetadata")return "Metadata exclusion";
   if(cause=="AllocationUnknown")return "Allocation uncertainty";
   return "Problem / incomplete";
  }
  internal static bool HasIncompleteTotals(Scan scan){foreach(var cause in scan.IssueCounts)if(cause.Key!="IncludedLinkCountMismatch" && cause.Value>0)return true;return false;}
  internal static object[] Categories(Scan scan){var rows=new List<object>();foreach(var cause in scan.IssueCounts)rows.Add(new {cause=cause.Key,count=cause.Value,kind=Kind(cause.Key)});return rows.ToArray();}
  internal object Snapshot(Scan scan){
   long informational=0,exclusions=0,problems=0;
   foreach(var cause in scan.IssueCounts){if(cause.Key=="IncludedLinkCountMismatch")informational+=cause.Value;else if(cause.Key=="DirectorySystemMetadata" || cause.Key=="FileSystemMetadata")exclusions+=cause.Value;else problems+=cause.Value;}
   return new {uniqueFiles=uniqueFiles,fileEntries=entries,additionalLinks=links,uniqueLogical=uniqueLogical,
    logicalAcrossLinks=linkLogical,informationalDiagnostics=informational,metadataExclusionDiagnostics=exclusions,problemDiagnostics=problems,
    coreMetadataRecords=coreRecords,coreKnownDataAllocation=coreAllocated,coreUnknownAllocations=coreUnknown,
    excludedMetadataFiles=excludedFiles,excludedMetadataDirectories=excludedDirectories,excludedKnownDataAllocation=excludedAllocated,excludedUnknownAllocations=excludedUnknown,
    metadataSamples=samples.ToArray(),categories=Categories(scan)};
  }
 }
}
