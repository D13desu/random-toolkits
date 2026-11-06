# Disk Usage 1.1.0

The preferred C# disk explorer with a PowerShell interface. The executable owns scanning, aggregation, the MFT tree, sorting, diagnostics and cached navigation. PowerShell receives progress and at most one page of rows per request. Engine semantics are the same as Disk Usage 0.4.4, including WOF verification and explicit unknown allocations.

Version 1.1.0 adds a live `MODIFIED` date for each visible file and directory and the containing volume's space available to the current user. Timestamps are queried only for the current page rather than stored for every scan record, preserving the compact cache and its large-volume memory profile. Because dates and available space are live while sizes are cached, they can reflect filesystem activity after the scan.

## Run the packaged disk explorer

Extract the package, open PowerShell in its directory, and run:

```powershell
.\Start-DiskHelper.ps1
```

Auto mode selects MFT only for an elevated, fixed local NTFS drive root. Other paths and unelevated sessions use native directory enumeration (logical sizes, with inaccessible/reparse entries reported as exclusions). Explicit -Engine mft/native remains available. MFT mode requires administrator rights. Enter selects the first fixed drive. To choose a drive directly:

```powershell
.\Start-DiskHelper.ps1 -Path C:\ -Engine mft
```

For an unelevated folder test:

```powershell
.\Start-DiskHelper.ps1 -Path "$env:USERPROFILE\Documents" -Engine native
```

B returns to the parent folder, then drive selection, then the calling launcher (or exits when run standalone). During a scan, B cancels and returns to drive selection; Q cancels scanning and opens partial results. Folder numbers, U, N/P, S and E provide navigation, paging, sorting and diagnostics. T shows MFT phase timings and memory samples; progress names the current phase. Exit disposes the helper process and releases its scan tree. Ctrl+C runs client cleanup. The client checks the executable against the package manifest before launch. This is an unsigned binary; it performs no automatic installation, elevation or update.

The packaged runner needs Windows, the full .NET Framework 4.5.1 or later runtime and PowerShell 5.1 or 7. Tests used .NET Framework 4.8.10008; older Windows/.NET installations and 32-bit hosts have not been validated. It does not require a modern dotnet SDK, NuGet, runtime Add-Type, or a network connection.

## Build from this repository

```powershell
.\experiments\disk-helper\Build-Helper.ps1
.\experiments\disk-helper\Start-DiskHelper.ps1 -Path C:\
```

The build invokes the installed .NET Framework csc.exe, producing an AnyCPU executable (x64 on the tested machine). Build output and local reports are ignored by Git. It extracts the shared C# engine from Disk-Usage.ps1 and checks that its MFT block matches MftScanner.cs before compiling. This avoids maintaining a divergent experimental copy of the scanner. Runtime execution does not parse the PowerShell scanner or compile C#.

Transform-Engine.ps1 applies experiment-only profiling hooks and storage adaptations to the extracted MFT block. Every replacement checks its expected occurrence count and fails the build if the maintained source changes unexpectedly. The maintained source still lives under experiments/disk-helper for build/history compatibility; the published package and launcher are production releases. Build with `-BaselineStorage -OutputDirectory out/baseline` to retain original filename storage, record lifetimes and row caching while keeping profiling hooks. `-LegacyRows -OutputDirectory out/legacy` keeps the 0.3.0 record-storage improvements but restores the intermediate row cache. Both comparison modes use the current final heap cleanup. The manifest records the storage mode and generated engine hash.

`-LegacyFolders -OutputDirectory out/legacy-folders` retains direct rows but uses intermediate folder objects and child lists for comparison. The default build uses compact folder records.

`-LegacyPaths -OutputDirectory out/legacy-paths` retains full directory paths for comparison. The default builds paths on demand.

## Protocol

UTF-8 JSON lines over redirected stdin/stdout, no network listener. The helper emits a versioned hello, then exactly one response per request. Progress is polled, so unsolicited output cannot interleave with replies.

| Command | Purpose |
| --- | --- |
| scan | Start local MFT or native scan; reject a second active scan |
| status | Progress, or a compact completed summary |
| cancel | Request cooperative cancellation and partial results |
| list | Cached folder page; allocated/logical/name sorting; maximum 100 rows |
| issues | Cause counts and a page of sampled diagnostics |
| memory | Completed-cache memory measurements; optional explicit garbage collection |
| profile | Phase-boundary timing/memory samples and record/name counts; native scans return null |
| quit / stdin EOF | Cancel and exit; no retained scan process |

Requests are limited to 64 KiB. Only paths in the cached scan can be browsed. All MFT file rows stay in C# memory; native mode caches the current directory listing. No write/delete/repair command exists.

## Validation and measured limits

### Unreleased: volume-space reconciliation

The root accounting report now separates attributable file/folder allocation from volume-wide NTFS structures and Windows reservations. It measures nonresident non-`$DATA` attributes from the MFT, subtracts resident `$DATA` slots already contained inside `$MFT`, adds known core/excluded metadata DATA, and queries `GetDiskSpaceInformationW` for Windows used and reserved allocation units. These categories are reported separately; reservations and filesystem-wide metadata are never assigned to folders.

On the local C: validation volume, the former 15.311 GiB difference comprised 5.454 GiB of core/excluded metadata DATA, 4.864 GiB of non-DATA attributes, 0.063 GiB of resident overlap, and 5.056 GiB reserved by Windows. The reconciled result differed from Windows' unavailable-space total by 1.79 MiB during a live scan. An earlier sample taken closer to the volume query differed by one 4 KiB cluster. The remaining residual is retained rather than forced to zero because both the MFT and Windows space counters can change while the scan runs.

The non-DATA sample included 2.803 GiB of `$INDEX_ALLOCATION` directory streams and 2.037 GiB of nonresident `$REPARSE_POINT` streams. `GetDiskSpaceInformationW` is available beginning with Windows 10 version 1809; older systems retain the existing included-allocation display without extended reconciliation. Microsoft documents the [NTFS attribute types](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/a82e9105-2405-4e37-b2c3-28c773902d85), [attribute record allocation fields](https://learn.microsoft.com/en-us/windows/win32/devnotes/attribute-record-header), and [disk-space information fields](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-disk_space_information).

### 0.7.0: explicit accounting and diagnostic categories

Press **A** for volume-wide accounting: unique included files, additional hard-link paths, total included file entries, unique logical bytes and logical bytes summed across included paths. Duplicate/rejected paths and excluded files do not enter these counters. LINK rows still have zero charged bytes/allocation; the expanded logical figure is a comparison metric, not physical disk usage.

The report separately measures known DATA allocation in observed core NTFS records (record indexes below 16) and in the excluded metadata tree. Records are deduplicated by their full sequence-bearing reference. Unknown/incomplete allocation counts and sampled records accompany both groups. Known portions are lower bounds when streams are incomplete. Historical 0.7.0 reports did not measure non-DATA structures and could not safely add metadata to user allocation because resident-file slots overlap `$MFT`; the unreleased reconciliation described above now handles that overlap explicitly.

$BadClus is explicitly unmeasured and its header allocation is excluded from the known sum. The live test exposed a header value spanning nearly the entire volume; the bad-cluster map needs separate mapping validation before physical allocation can be reported. See Microsoft's [MFT developer notes](https://learn.microsoft.com/en-us/windows/win32/devnotes/master-file-table) and the [Linux NTFS3 implementation](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux/+/69050f8d6d075dc01af7a5f2f550a8067510366f/fs/ntfs3/super.c) for the special stream and mapped-run accounting.

**E** labels included-file information, metadata exclusions, allocation uncertainty and other problems separately. IncludedLinkCountMismatch remains visible and counted but does not set PARTIAL by itself. Exclusions, unknown allocations, cancellation and parse failures retain partial flags. Tests cover information-only completeness, immutable zero-charge LINK rows, duplicate rejection, expanded logical totals, metadata deduplication, lower bounds and genuine uncertainty.

The final elevated C: comparison passed the immutable hard-link fixture against the production engine. It reported 2,949,999 unique files, 440,665 additional paths and 3,390,664 total file entries, with zero parse errors. Unique logical bytes were 988,496,494,254 versus 1,082,989,301,103 across included paths. Early and reconstruction-stage cancellation both passed. These live results validate the report on this PC; they do not establish equality with another tool or explain every allocation difference.

### 0.6.0: directory paths on demand

Directory identity now consists of a parent ID and the original name, indexed case-insensitively. Resolved MFT references map to folder IDs, retaining their complete sequence-bearing references. The full-path list and full-path-keyed directory dictionary are absent in this mode. Full paths are reconstructed iteratively for browsing, hard-link ordering, diagnostics and API verification; no filesystem traversal is used.

An LRU cache retains at most 4,096 full paths and 2,097,152 UTF-16 characters (about 4 MiB of character data, plus object/index overhead). Directory names and parent IDs remain the authoritative data, so eviction never loses a folder. Cache misses preserve original spelling; arbitrary case-insensitive lookups resolve through parent/name keys. Directory browsing rows share those original name strings. The memory protocol exposes path-cache entry and character counts.

The elevated C: memory run measured 3.88 GiB peak working set, 1.09 GiB while browsing and 39.14 seconds to results, versus the prior 0.5.0 samples of 4.59 GiB, 1.71 GiB and about 37 seconds. Reconstruction trades about two seconds for lower memory in these sequential live-volume samples; this is not a controlled benchmark. The cache held 4,096 entries and 387,652 characters at the measurement point.

Tests cover eviction by both cache limits, 2,200-level iterative paths, case-insensitive lookup after eviction, canonical spelling, malformed/outside paths, 4,206-folder legacy equivalence and 15,640-row paging/sorting equivalence. The shared MFT suite and protocol tests pass on PowerShell 5.1 and 7. The test adapter rejects accidental retention of the full path index.

The final live comparison measured 3.85 GiB peak, 1.04 GiB browsing working set and 39.79 seconds to results. The hard-link fixture matched exactly; both engines reported 2,949,753 files, 366 unknown allocations, 5,612 API-verified records, identical diagnostic counts and zero parse errors. Whole-volume byte totals changed slightly during the sequential scans. Cancellation passed during collection (136 ms) and reconstruction (7.67 seconds), with partial flags preserved on directory and file rows.

### 0.5.0: compact folder records

Folders now use fixed-size blocks containing parent IDs, child-row links, totals and flags. The worker retains only the root compatibility Node, avoiding a Node, child list and duplicate path-index entry for every other folder. Parents are created before children during path resolution; reverse folder IDs provide a validated aggregation order without sorting folder objects. Browsing reuses these records directly, removing folder-summary conversion. Parsed directory records are released after path resolution, followed by a measured blocking collection before file processing. Full directory paths remain retained for now.

The shared MFT regression suite passes against the compact folder path on PowerShell 5.1 and 7. Its test adapter verifies that reconstruction retained only the root Node before materializing results for the assertions. An additional 4,206-folder fixture crosses block boundaries and compares every folder total, parent, row, sort order, reparse tag and uncertainty flag against legacy tree reconstruction; input records are reversed to exercise parent resolution. Existing 15,640-row cache tests and protocol suites also pass.

An elevated C: memory run on the user's PC measured 4.59 GiB peak working set and 36.99 seconds to browsing, compared with the previous 0.4.0 samples of 5.47 GiB and 40.69 seconds. Completed browsing memory remained about 1.71 GiB; this step mostly removes temporary objects and aggregation/conversion work. Folder-index transfer takes about 2 milliseconds. An earlier compact-folder build without early directory retirement peaked at 5.28 GiB and finished in 34.85 seconds: the added collection trades about two seconds for lower peak memory. These are live-volume samples, not a controlled benchmark. Removing retained full directory paths is the next memory target.

The final live comparison matched the hard-link fixture exactly and reported the same 2,949,730 files and diagnostic counts as the embedded engine: 366 unknown allocations, 5,612 API-verified records and zero parse errors. Whole-volume byte totals differed slightly with live filesystem activity. The helper was ready in 37.08 seconds. Final cancellation checks passed during collection (167 ms) and reconstruction (7.46 seconds), including partial flags on packed folder and file rows.

### 0.4.0: direct compact rows

The MFT worker writes file and directory browsing rows directly into packed blocks of 4,096 entries. Entries store filenames, sizes, kinds, tags and uncertainty flags; folder chains use integer row IDs. Completed browsing reuses those blocks instead of copying millions of Row objects. Directory nodes and full directory paths still exist during reconstruction and are the next memory target.

Duplicate detection uses a case-insensitive folder-ID/filename key, avoiding retained full file paths. Full file paths still exist transiently for ordinal hard-link ownership, diagnostics and API verification. The original accounting/verification rules remain unchanged. Folder summaries are transferred after aggregation, and the current folder is sorted on demand. Late cancellation or record errors force row partial flags without rewriting every block.

Final cleanup compacts the managed heaps after releasing reconstruction data to reduce retained heap gaps. It remains synchronous; preparation time is included in the displayed ready time.

The shared MFT suite passes against the direct writer on PowerShell 5.1 and 7. `Test-Engine.ps1 -DirectRows` uses a test-only adapter to materialize the direct cache for the unchanged suite's assertions and rejects any build that silently used the legacy cache. The cache-equivalence test checks 15,640 rows across 41 folders, all three sort orders/pages, several block boundaries, case-insensitive collisions, parent navigation and late partial flags. Protocol/client tests also pass on both shells.

Elevated C: validation on the user's PC (2026-11-05), about 5.10 million records and 5.11 million browsing rows:

| Measurement | Previous 0.3.0 sample | 0.4.0 final-build sample |
| --- | --- | --- |
| Peak process working set | 6.85 GiB | 5.47 GiB |
| Scan plus cache preparation | 48.89 s | 40.69 s |
| Cache preparation | 7.34 s | 3.36 s |
| Completed browsing working set | 1.69 GiB | 1.73 GiB |

These are sequential live-volume samples, not a controlled benchmark. Packed row links increase retained managed data by about 43 MiB; the gain is lower peak memory and less conversion work. The fixed hard-link fixture matched the embedded engine exactly for logical bytes, allocation, unique file counts and rows. Both live scans reported 366 unknown allocations, 5,612 API-verified records, zero parse errors and identical diagnostic counts. Whole-volume totals changed slightly while the filesystem was live.

Live cancellation tests passed during record collection and during file-path reconstruction. The latter checked partial flags on both directory and file rows and took 11.99 seconds to finish: cancellation still waits for remaining reconstruction/aggregation rather than interrupting every phase immediately. Run `Test-MftCancel.ps1 -DuringReconstruction -ReportPath <local-json-path>` for that case.

### 0.3.0: phase profiling and temporary storage

The profiled baseline collected 5,097,641 records: 4,406,097 had one filename, 342,492 had multiple names, and 349,052 had none. Single names now occupy the name collection directly, avoiding a separate List and backing array; multiple names use an ordered overflow list. Filename objects preserve reference semantics. The worker releases the original collection's references after handing records to reconstruction; directory lookup references are cleared after path resolution, and assembled record slots are released as file rows are produced. Public Build inputs remain reusable and unchanged.

| Measurement, same live C: volume | Profiled original storage | Optimized storage |
| --- | --- | --- |
| Peak process working set | 7.31 GiB | 6.85 GiB |
| Working set after record collection | 2.51 GiB | 2.20 GiB |
| Scan plus cache preparation | 49.47 s | 48.89 s |
| Completed browsing working set | 1.82 GiB | 1.69 GiB |

Peak reduction was about 469 MiB (6.3%). These are sequential live-volume samples, not a controlled speed benchmark. Managed samples include objects awaiting collection; working set is process memory, not exact ownership per structure. Profiling does not force collection at phase boundaries. The largest remaining growth occurs while creating full directory/file paths and the intermediate tree, before compact-cache conversion. Direct compact-index construction remains future work.

The shared MFT regression suite runs against the actual helper assembly via Test-Engine.ps1 on PowerShell 5.1 and 7, covering malformed records, extension assembly, input reuse, cycles, hard links, allocation, WOF and API verification. Existing compact-cache and protocol/client suites also pass.

A final live comparison matched the immutable hard-link fixture exactly against the embedded 0.4.4 engine. Both reported 366 unknown allocations, 5,612 API-verified records, zero parse errors and the same diagnostic causes/counts; live whole-volume totals differed slightly. The optimized helper was ready in 48.59 seconds in that run. Mid-scan cancellation also passed with explicitly partial, browsable results.

### 0.2.0: completed-cache compaction

Version 0.2.0 compacts the completed MFT tree into folder and row arrays. File rows retain names rather than full paths; paths are reconstructed only for the displayed page. Folder totals, parents, row types, hard-link accounting, reparse tags and uncertainty flags are preserved. The current folder's sort order is cached as integer indices. The shared scan engine is unchanged.

On a live C: scan with about 5.11 million cached rows and 1.72 million folders, completed browsing working set fell from 7.19 GiB before cleanup to 4.07 GiB after collection alone, then to 1.85 GiB with compaction. Managed memory after compaction was 1.63 GiB. These are separate live-volume samples. Peak working set remained about 7.34 GiB: this change reduces retained browsing memory, not peak scanning memory. Cache preparation adds time after scanning; the interface reports it separately.

The compact-cache test compares 3,940 synthetic rows across 41 folders, three sort orders and all pages, including Unicode, empty folders, parents, totals, kinds, reparse tags and partial/unknown flags. Protocol/client tests pass on PowerShell 5.1 and 7.

The final-build live comparison measured 42.39 seconds scanning plus 7.49 seconds cache preparation (2.80 seconds compaction, 4.70 seconds collection), ready at 49.89 seconds. Completed helper working set was 1.78 GiB in that run. Preparation currently runs synchronously during the completion status request; progress and cooperative cancellation resume only after preparation finishes.

The immutable hard-link fixture matched the embedded engine exactly for logical bytes, allocation, unique file count and cached rows. Both full-volume scans reported 366 unknown allocations, 5,612 API-verified records and zero parse errors. Whole-volume totals varied with live filesystem activity; they are not an equality assertion.

### Original 0.1.0 baseline

On 2026-11-05, protocol/client tests passed on Windows PowerShell 5.1 and PowerShell 7.6.5: exact fixture totals, hard page bounds, Unicode, ordering, navigation, invalid request recovery, cancellation, shutdown and checksum rejection. A live elevated comparison confirmed identical fixture allocation, logical totals, file counts and cached rows between the helper and embedded engine.

| Measurement | Result |
| --- | --- |
| Helper startup + checksum + handshake, five launches | 199, 78, 79, 80, 80 ms |
| Embedded Add-Type initialization, one launch | 175 ms |
| Helper full C: scan | 42.84 s |
| Embedded full C: scan, afterwards | 44.84 s |
| Files reported by each | 2,949,540 |
| Unknown allocations / API-verified records, each | 366 / 5,612 |
| Parse errors, each | 0 |
| Root page response | 3,407 bytes |
| Mid-scan cancellation after 50,343 records | Partial results available in 147 ms |
| PowerShell interface sampled working set | 101 MiB |
| Helper sampled working set | 7.25 GiB |
| Embedded baseline PowerShell sampled working set | 6.66 GiB |

These are sequential live-volume samples, not a controlled speed benchmark or peak-memory measurements. Whole-volume totals differed by 188,348 logical bytes and 151,552 allocated bytes; the immutable test fixture matched exactly. Caches, filesystem changes and GC timing affect measurements. Extraction isolates memory from PowerShell but does not yet reduce engine memory, and this comparison does not establish a reliable scan-speed improvement.

Tests: Test-Helper.ps1 (non-admin protocol), Test-Engine.ps1 (non-admin shared MFT regressions against the built helper), Test-CompactIndex.ps1 (non-admin cache equivalence), Test-MftCancel.ps1 (admin, cancellation after real MFT progress), Compare-Helper.ps1 (admin, helper then embedded full-volume comparison), Measure-Memory.ps1 (admin, full MFT scan, phase samples and memory collection with unchanged root-page assertion). Validation writes only build output, isolated TEMP fixtures and requested report files. Reports can contain local paths and should stay local.

### Keyboard browsing (0.8.1)
In an interactive console, Up/Down selects a row; Enter or Right enters a directory. Left, Backspace or Escape goes back. PageUp/PageDown changes pages. Ctrl+Enter (or O) opens the selected directory in Explorer; with a file selected it opens the current directory. Missing/inaccessible paths report an error. Existing commands remain available, including numbers followed by Enter. Redirected or unsupported hosts retain line input. The scanner remains read-only; Explorer is a separate Windows application.

Version 0.8.1 groups accounting, diagnostics and timing under F1: Reports (H with line input), with arrow/Enter selection. The browser shows compact navigation hints; legacy commands remain accepted. The root-only Unreconciled figure is volume-used minus included-file allocation, not missing files or a measured overhead total. Reports retain the exact difference and non-additive metadata caveats.


## Graduation: 1.0.0

Promoted to Storage option 1 with automatic scan-mode selection; the older Disk Usage 0.4.5 scanner remains option 2 as a compatibility fallback. No scanner/accounting algorithm was changed for graduation. The outer ZIP pin, inner executable checksum, manifest version and handshake checks remain enforced. There is no automatic elevation. The fallback is explicit, including when the helper runtime is unavailable.

Validated runtime: x64 Windows with .NET Framework 4.8 and PowerShell 5.1/7. The declared runtime minimum is still 4.5.1, but older Windows/.NET and 32-bit hosts are not validated. Cancellation is cooperative and can take longer during reconstruction. Unreconciled volume allocation is not a missing-file total or measured NTFS overhead. Historical measurements below describe their named versions rather than a guarantee for every machine.
