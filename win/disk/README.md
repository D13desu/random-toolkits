# Disk Usage 0.2.0

Read-only, ncdu-inspired console explorer for PowerShell 5.0+. Tested on Windows PowerShell 5.1 and PowerShell 7. No modules or administrator rights are required; elevated access can reduce permission-related omissions.

```powershell
irm https://tools.d0xd.com/win/disk/ | iex
```

Local: `./win/disk/Disk-Usage.ps1`, or `./win/disk/Disk-Usage.ps1 -Path 'C:\Users'`.

Lists all detected drives with total, used and free bytes, ordered by used space. Choose a drive or **F** for a folder. The scanner includes hidden files, recursively totals logical file lengths, then lists immediate folders and files largest-first. Select a folder number to drill down. **U** goes up, **N/P** changes pages, **R** rescans the chosen root, **E** shows exclusions/errors, and **0** returns to drives/exits. During native scans, live partial totals/top folders appear every three seconds; **Q** stops and opens partial results in a console supporting key polling. Ctrl+C cancels the launcher and signals the background scanner to stop. A currently blocked OS call may take time to return. No delete, cleanup or file execution actions exist.

Directory totals are cached for the session; individual file metadata is read when visiting a directory, then cached while paging through that directory. Rescan after files change. Memory scales with directory count and the number of entries in the current folder. A full drive can still take minutes or longer, especially on slow/network storage.

## Faster scanning

The default Windows engine compiles an embedded C# scanner once per process with Add-Type. It uses Unicode FindFirstFileEx/FindNextFile with larger directory-fetch buffers, obtains attributes and sizes from enumeration instead of issuing per-file metadata queries, and keeps the per-file loop out of PowerShell. Traversal runs on a background thread while the console displays progress. Long paths use the extended Windows path prefix. Sorting of native directory listings is compiled too; paging does not repeatedly enumerate/sort the same directory.

If compilation is restricted, Auto mode warns and uses the original PowerShell scanner. For local comparison after dot-sourcing with `-NoMenu`, use `Measure-DiskTree -LiteralPath PATH -Engine Native` or `-Engine PowerShell`. The fallback lacks live preview/Q-to-partial; Ctrl+C still exits.

This is **not an MFT reader**. [WizTree reads the NTFS Master File Table directly](https://diskanalyzer.com/), which avoids directory-by-directory traversal and can be substantially faster for whole NTFS volumes. This toolkit continues to use permission-respecting enumeration without raw volume access or administrator requirements. It reports logical sizes with the limitations below.

Measured on the development PC with PowerShell 7.6.5: 20,000 files in 40 folders, warm filesystem cache, three samples per engine with alternating order. Median native time **108.6 ms**, old PowerShell time **1,595.3 ms** (**14.7x**); all totals agreed. Separate one-time compilation: **4,830.3 ms**. This synthetic result includes polling overhead and is not a promised whole-drive speedup. Reproduce with `tests/Measure-DiskScannerPerformance.ps1`; the optional benchmark creates a small-file fixture in TEMP and tests cancellation without deleting it automatically.

Junctions, symlinks, mounted-folder reparse points and cloud reparse placeholders are skipped to avoid cycles and crossing into other trees. Inaccessible/disappearing entries are counted and up to 100 examples retained; affected totals are marked **partial**. Skipped mounted volumes may need scanning through their own accessible root. File contents are never opened by the scanner.

These are **logical sizes**, not allocated disk space. Hard links count per pathname; compression, sparse files, filesystem metadata, snapshots, protected files and excluded cloud placeholders can make totals differ from drive used space. Directory/file totals can also differ when the filesystem changes during a scan.

The source is `Disk-Usage.ps1`; copy it byte-for-byte to `index.html` after edits for Pages. The network toolkit downloads a checksum-verified, commit-pinned copy when its disk explorer option is selected; update that pin when releasing a new explorer version.

Regression tests: `tests/Test-DiskUsage.ps1` in both shells. Tests use isolated temporary trees to verify nested totals, hidden files, empty folders, sorting, reparse-loop exclusion, navigation, no file changes, IEX startup, native/fallback parity, restricted-compilation fallback, Unicode and paths longer than MAX_PATH. They do not scan entire production drives.
