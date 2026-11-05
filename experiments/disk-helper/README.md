# Standalone disk helper experiment 0.1.0

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

Q cancels scanning and opens partial results. Folder numbers, U, N/P, S and E provide navigation, paging, sorting and diagnostics. Exit disposes the helper process and releases its scan tree. Ctrl+C runs client cleanup. The client checks the executable against the package manifest before launch. This is an unsigned test binary; it performs no automatic installation, elevation or update.

The packaged runner needs Windows, the full .NET Framework 4.x runtime and PowerShell 5.1 or 7. Tests used .NET Framework 4.8.10008; older Windows/.NET installations and 32-bit hosts have not been validated. It does not require a modern dotnet SDK, NuGet, runtime Add-Type, or a network connection.

## Build from this repository

```powershell
.\experiments\disk-helper\Build-Helper.ps1
.\experiments\disk-helper\Start-DiskHelper.ps1 -Path C:\
```

The build invokes the installed .NET Framework csc.exe, producing an AnyCPU executable (x64 on the tested machine). Build output and local reports are ignored by Git. It extracts the shared C# engine from Disk-Usage.ps1 and checks that its MFT block matches MftScanner.cs before compiling. This avoids maintaining a divergent experimental copy of the scanner. Runtime execution does not parse the PowerShell scanner or compile C#.

## Protocol

UTF-8 JSON lines over redirected stdin/stdout, no network listener. The helper emits a versioned hello, then exactly one response per request. Progress is polled, so unsolicited output cannot interleave with replies.

| Command | Purpose |
| --- | --- |
| scan | Start local MFT or native scan; reject a second active scan |
| status | Progress, or a compact completed summary |
| cancel | Request cooperative cancellation and partial results |
| list | Cached folder page; allocated/logical/name sorting; maximum 100 rows |
| issues | Cause counts and a page of sampled diagnostics |
| quit / stdin EOF | Cancel and exit; no retained scan process |

Requests are limited to 64 KiB. Only paths in the cached scan can be browsed. All MFT file rows stay in C# memory; native mode caches the current directory listing. No write/delete/repair command exists.

## Validation and measured limits

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

Tests: Test-Helper.ps1 (non-admin), Test-MftCancel.ps1 (admin, cancellation after real MFT progress), Compare-Helper.ps1 (admin, helper then embedded full-volume comparison). Validation writes only isolated TEMP fixtures and requested report files. Reports can contain local paths and should stay local.
