# Standalone disk helper experiment 0.3.0

An opt-in C# executable with a PowerShell interface. The executable owns scanning, aggregation, the MFT tree, sorting, diagnostics and cached navigation. PowerShell receives progress and at most one page of rows per request. Engine semantics are the same as Disk Usage 0.4.4, including WOF verification and explicit unknown allocations.

## Try the packaged experiment

Extract the package, open PowerShell in its directory, and run:

```powershell
.\Start-DiskHelper.ps1
```

MFT mode requires an administrator PowerShell and a local NTFS volume. Enter selects the first fixed drive. To choose a drive directly:

```powershell
.\Start-DiskHelper.ps1 -Path C:\ -Engine mft
```

For an unelevated folder test:

```powershell
.\Start-DiskHelper.ps1 -Path "$env:USERPROFILE\Documents" -Engine native
```

Q cancels scanning and opens partial results. Folder numbers, U, N/P, S and E provide navigation, paging, sorting and diagnostics. T shows MFT phase timings and memory samples; progress names the current phase. Exit disposes the helper process and releases its scan tree. Ctrl+C runs client cleanup. The client checks the executable against the package manifest before launch. This is an unsigned test binary; it performs no automatic installation, elevation or update.

The packaged runner needs Windows, the full .NET Framework 4.x runtime and PowerShell 5.1 or 7. Tests used .NET Framework 4.8.10008; older Windows/.NET installations and 32-bit hosts have not been validated. It does not require a modern dotnet SDK, NuGet, runtime Add-Type, or a network connection.

## Build from this repository

```powershell
.\experiments\disk-helper\Build-Helper.ps1
.\experiments\disk-helper\Start-DiskHelper.ps1 -Path C:\
```

The build invokes the installed .NET Framework csc.exe, producing an AnyCPU executable (x64 on the tested machine). Build output and local reports are ignored by Git. It extracts the shared C# engine from Disk-Usage.ps1 and checks that its MFT block matches MftScanner.cs before compiling. This avoids maintaining a divergent experimental copy of the scanner. Runtime execution does not parse the PowerShell scanner or compile C#.

Transform-Engine.ps1 applies experiment-only profiling hooks and storage adaptations to the extracted MFT block. Every replacement requires exactly one matching anchor and fails the build if the maintained source changes unexpectedly. Production sources and launcher pins are untouched. Build with `-BaselineStorage -OutputDirectory out/baseline` to retain original filename storage and record lifetimes while keeping identical profiling hooks. The manifest records the storage mode and generated engine hash.

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
