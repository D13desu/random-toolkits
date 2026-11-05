# Disk Usage 0.4.2

Read-only drive and folder explorer for PowerShell 5.0+; tested on Windows PowerShell 5.1 and PowerShell 7. Open it from the unified Windows launcher: **Storage > Open disk usage explorer**.

```powershell
irm https://tools.d0xd.com/win | iex
```

The standalone endpoint is `/win/disk/`. Local execution: `./win/disk/Disk-Usage.ps1`, or add `-Path 'C:\Users'`. Dot-source with `-NoMenu` for the scanner functions.

## Navigation

Select a numbered drive for the standard scanner, **F** for a folder, or **M** for an experimental MFT scan. The M and D drive prompts default to the first listed drive when you press Enter. MFT mode requires an administrator session and a local NTFS drive root. Unsupported paths, missing elevation or API failures fall back with a warning to the standard scanner. **D** inspects a selected MFT record and its parent chain without a full scan.

In results: select a directory number to drill down, **U** to go up, **N/P** for pages, **E** for diagnostic causes/examples, **R** to rescan using the same engine, and **0** to return. **Q** during collection requests partial results in consoles supporting key polling. Ctrl+C signals cancellation. Reconstruction or an outstanding OS request can take time to finish. Scans/listings are cached; rescan after changes. There are no delete, cleanup, file-open or repair actions.

## MFT: On disk and logical size

The existing **M** mode now shows **On disk** beside **Logical size**, sorted by known allocation. It accounts for unnamed and named DATA streams, including compressed stream storage. Nonresident streams use their allocation metadata; sparse/compressed streams use TotalAllocated. Resident data contributes its padded payload slot inside the MFT record, matching Windows stream-allocation reporting. Other filesystem metadata is not assigned to files.

Hard-linked files are charged once, to the first ordinal full path. Other links remain visible as LINK with zero charged bytes. DOS short-name attributes participate in the NTFS completeness check but are neither displayed nor charged as extra files.

**Unknown** means allocation could not be established. **>=** is a known subtotal with missing information; neither is a complete total. Resident and readable nonresident attribute lists are checked against assembled stream names. Nonresident lists use bounded, aligned metadata reads (maximum 1 MiB per list), with validated run lengths and volume bounds. Unsupported, fragmented-across-records, uninitialized or unreadable lists remain unknown; raw metadata reads may be rejected by Windows or a volume provider. Missing/conflicting stream headers also leave allocation incomplete. The viewer reports Windows-used space, accounted DATA allocation and their difference. The difference can include metadata, snapshots, excluded records and live filesystem changes; it is not automatically reclaimable space. A negative difference is flagged for investigation.

MFT mode constructs a graph from local record IDs and parent references. It never walks a reparse target or opens file contents. A junction, symlink, cloud placeholder, container record or unknown tag can therefore contribute its **own local DATA allocation** without following the target or downloading data. RP/WCI rows and directory annotations identify reparse metadata. Cloud/container logical size is reported separately and is not substituted for local allocation. Shared backing layers are counted only where their own file records are accounted for. A missing reparse tag does not imply missing stream allocation.

Extension records are joined only to an exact base reference including its sequence number. Referenced extensions missing from enumeration are queried individually and checked for sequence and ownership. Filename counts are checked per referenced record against the attribute list; a verified list can supersede a differing header link count, reported as IncludedLinkCountMismatch rather than an omission. Without a verified list the conservative header check remains. Children of intentionally excluded NTFS metadata are labelled FileSystemMetadata. Cycles, reused/missing parents, malformed records and incomplete names remain explicit diagnostics. Exclusions conservatively mark totals partial. This is a live metadata scan, not an atomic filesystem snapshot, forensic NTFS implementation or complete allocated-cluster ownership map. Memory scales with all retained file names/folders; very large volumes can need substantial RAM.

Implementation: embedded C# uses read-only volume access, FSCTL_GET_NTFS_VOLUME_DATA and FSCTL_GET_NTFS_FILE_RECORD for NTFS 3.0/3.1. It makes a request per in-use record and reads raw volume ranges only for nonresident ATTRIBUTE_LIST metadata; it is not a bulk raw MFT reader. No disk writes, volume locks, journal creation or automatic elevation. Elevated metadata may reveal protected filenames. Sources: [attribute headers](https://learn.microsoft.com/en-us/windows/win32/devnotes/attribute-record-header), [MFT record retrieval](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_get_ntfs_file_record), [Windows stream allocation](https://learn.microsoft.com/en-us/windows/win32/fileio/file-streams).

## Standard scanner

The default engine remains compiled FindFirstFileEx/FindNextFile directory enumeration. It does not require administrator access, includes hidden files, supports long paths and shows logical sizes only. Junctions, symlinks and cloud reparse entries are skipped. Errors/exclusions produce partial totals. Cached directory totals and per-directory file listings avoid repeated work during paging. If Add-Type is restricted, Auto warns and falls back to the original PowerShell scanner.

For comparison: `Measure-DiskTree -LiteralPath PATH -Engine Native` or `-Engine PowerShell`. The default engine previously measured 108.6 ms versus 1,595.3 ms for the old PowerShell scanner on a warm-cache 20,000-file fixture (three alternating samples). Compilation was measured separately at 4,830.3 ms. This is a synthetic result, not a full-drive promise. Reproduce with `tests/Measure-DiskScannerPerformance.ps1`.

## Validation and maintenance

- `tests/Test-DiskUsage.ps1`: native/fallback totals, long paths, hidden files, junction loops, navigation and IEX startup.
- `tests/Test-MftScanner.ps1`: parser bounds, hard links/DOS aliases, extensions, reparse metadata, resident/named/sparse/compressed allocation, unknown/lower-bound presentation and allocation sorting.
- `tests/Test-MftAllocationLive.ps1`: elevated, bounded comparison of real fixture MFT records against independent Windows file-information APIs. Creates isolated TEMP files (resident, ordinary, compressed, sparse, named stream and hard link); changes no existing files and retains the fixture.
- `tests/Measure-MftVolumeAllocation.ps1`: optional elevated read-only volume scan with a compact report, cancellation-file support and a default 10-minute collection timeout.
- `tests/Test-MftLive.ps1`: older optional whole-volume logical-size fixture check.

Edit the C# in `MftScanner.cs`, then run `tests/Sync-DiskMft.ps1` to embed it in `Disk-Usage.ps1` and refresh its raw Pages `index.html`. Other script edits need the same endpoint copy. The unified launcher pins the disk script's Git commit and SHA-256; update both together. Changing the embedded type namespace prevents an earlier loaded scanner version being reused in the same PowerShell process.

Validation on 2026-11-04: all six live allocation fixtures matched Windows APIs on PowerShell 5.1 and 7.6.5. A read-only C: scan completed in 38.6 seconds: 2,910,817 files, 1,719,663 directories, 756.7 GiB accounted allocation versus 774.8 GiB Windows used, zero parse errors. The remaining 18.1 GiB is not attributed: 40,536 files and 4 metadata directories were omitted, and 1,016 allocations remained unknown. These are machine-specific results, not a completeness or performance guarantee.

Validation for 0.4.2 on 2026-11-05: parser and reconstruction tests passed on PowerShell 5.1 and 7.6.5; live allocation fixtures passed on 5.1. Targeted reads of the reported DLL/catalog records confirmed that their filename lists were complete despite differing header link counts. The full C: scan took 91.8 seconds (5,097,336 records), with zero parse errors, 4,966 FileUnsupported exclusions, 12 intentional FileSystemMetadata exclusions, and 35,541 IncludedLinkCountMismatch diagnostics for files now counted. Accounted allocation was 759.1 GiB against 774.5 GiB used (15.5 GiB difference). The 1,016 uncertain allocations remained: raw metadata access returned 'The request is not supported' on this volume. Successful raw list reading still needs validation on a volume that permits it; failures stay explicit and do not invent totals. Timing is machine/workload-dependent and this run was slower than the previous 38.6-second scan.
