# Disk Usage 0.3.3

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

The default engine uses directory enumeration. An opt-in **M** option now reads NTFS MFT records; see its experimental limitations below. It is not selected by Auto mode.

Measured on the development PC with PowerShell 7.6.5: 20,000 files in 40 folders, warm filesystem cache, three samples per engine with alternating order. Median native time **108.6 ms**, old PowerShell time **1,595.3 ms** (**14.7x**); all totals agreed. Separate one-time compilation: **4,830.3 ms**. This synthetic result includes polling overhead and is not a promised whole-drive speedup. Reproduce with `tests/Measure-DiskScannerPerformance.ps1`; the optional benchmark creates a small-file fixture in TEMP and tests cancellation without deleting it automatically.

In the default directory-enumeration engine, junctions, symlinks, mounted-folder reparse points and cloud reparse placeholders are skipped to avoid cycles and crossing into other trees. Inaccessible/disappearing entries are counted and up to 100 examples retained; affected totals are marked **partial**. Skipped mounted volumes may need scanning through their own accessible root. File contents are never opened by the scanner.

These are **logical sizes**, not allocated disk space. Hard links count per pathname; compression, sparse files, filesystem metadata, snapshots, protected files and excluded cloud placeholders can make totals differ from drive used space. Directory/file totals can also differ when the filesystem changes during a scan.

The source is `Disk-Usage.ps1`; copy it byte-for-byte to `index.html` after edits for Pages. The network toolkit downloads a checksum-verified, commit-pinned copy when its disk explorer option is selected; update that pin when releasing a new explorer version.

## Experimental MFT engine

From the same Windows launcher, choose **Storage > Open disk usage explorer > M**, then enter a local NTFS drive root such as `C:\`. Open PowerShell as administrator first; unavailable elevation is labelled in the menu. Local API: `Measure-DiskTree 'C:\' -Engine Mft` after dot-sourcing with `-NoMenu`. Folder paths, network shares, other filesystems, missing elevation and API failures fall back with a warning to the standard scanner. Auto continues to select the existing scanner.

The embedded C# helper opens a volume with read access and calls [FSCTL_GET_NTFS_VOLUME_DATA](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-ntfs_volume_data_buffer) and [FSCTL_GET_NTFS_FILE_RECORD](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_get_ntfs_file_record). It scans in-use records in descending order, parses unnamed data lengths and filename/parent references, validates parent sequence numbers, and reconstructs the directory tree without opening individual files. Supports NTFS 3.0/3.1. No raw-sector reads, disk writes, filesystem locks, journal creation or automatic elevation. Elevated volume metadata can include names of files that ordinary directory permissions hide.

This first implementation makes one filesystem-control request per record, **not a bulk sequential MFT read like a specialized disk analyzer may use**. Real-drive speed has not been measured in the development session because it lacks an elevated token. Do not assume it is faster than the native scanner yet. Memory scales with all file names and folders on the volume, potentially hundreds of MB or more on large volumes. Progress during collection is provisional; cached folder/file listings become available after reconstruction.

MFT results show **unique logical bytes**. Hard links are charged once to the first ordinal full path; other links remain visible as `LINK` with zero charged bytes. Therefore folder ownership can differ from directory enumeration, which counts every pathname. Sparse and compressed files use logical data length, not physical allocation. Named streams and NTFS system records are excluded. Matching extension records now supply missing names, reparse tags and initial unnamed data lengths. Base references include sequence numbers; stale extents are not attached. Assembled file names must reconcile with the base hard-link count, and base standard-information flags must be present. Incomplete/conflicting metadata, malformed records, cycles and missing/reused parents remain excluded. Known cloud-file and WOF file tags are included as logical metadata; junctions, symlinks and unknown reparse tags remain excluded. Directory sizes come from child records, not extended directory indexes. Any unresolved exclusion conservatively marks all folder totals partial. A live scan is not an atomic snapshot: changes during scanning can affect results. **R** preserves the selected engine; **Q** returns incomplete results where paths can be resolved.

Validation: `tests/Test-MftScanner.ps1` passes on PowerShell 5.1 and 7 using synthetic NTFS records for resident/nonresident logical sizes, compression/sparse flags, hard links, DOS aliases, Unicode, malformed bounds, reparse exclusions (including flags without a local reparse payload), WindowsApps-style directories with attribute lists, incomplete-directory and file attribute-list exclusions, stale parent references, cycles, cancellation and fallback. These do **not** substitute for testing real volume records.

For the next validation stage, run `tests/Test-MftLive.ps1` in an administrator PowerShell from this checkout. It creates a small isolated fixture on the TEMP volume with a hard link, sparse/compressed data, Unicode and a long path; scans that volume's MFT and checks exact expected fixture totals. It retains the fixture and never modifies existing files. Add `-CompareWholeVolume` to also time a full native scan; whole-volume totals may differ because of hard links and permissions. Automatic MFT selection remains disabled until live validation and useful performance improvement are demonstrated.

Maintain the C# source in `MftScanner.cs`, then run `tests/Sync-DiskMft.ps1` to embed it and refresh the raw Pages endpoint. No extra runtime download is introduced.

### Diagnosing incomplete MFT scans

Version 0.3.1 counts an unresolved file once, instead of once per missing parent link plus again for the omitted file. The display separately reports omitted files, omitted directories and unparsed records. **E** groups diagnostics by specific cause and keeps up to four examples per cause, so repeated directory failures cannot hide all other causes. An ancestor exclusion can affect many descendants; counts represent affected records, not necessarily independent disk faults. `Included logical size` is not a complete volume total when omissions exist.

To investigate without rescanning the drive, return to the drive menu and choose **D**, enter the NTFS drive root and a record number from the errors (digits only). This administrator-only diagnostic reads at most 64 records along that record's parent chain. It shows names, references, sequence numbers, name counts, reparse/extension flags and parser failures. It does not modify the drive. A record can change or be reused between the scan and this inspection; that condition is reported where detected. This diagnostic improvement does not establish the cause of an older generic exclusion message or guarantee that its missing totals are fixed.

Regression tests: `tests/Test-DiskUsage.ps1` in both shells. Tests use isolated temporary trees to verify nested totals, hidden files, empty folders, sorting, reparse-loop exclusion, navigation, no file changes, IEX startup, native/fallback parity, restricted-compilation fallback, Unicode and paths longer than MAX_PATH. They do not scan entire production drives.

Version 0.3.2 fixes a confirmed exclusion cascade: a WindowsApps directory with a valid base name was rejected solely because it had an attribute list. The scanner now reads reparse flags from resident standard information before accepting such a directory. The diagnostic D option shows attributeList and standardInfo separately from unsupported. Regression tests reproduce the affected ancestor/descendant structure; a new elevated scan is still required to verify totals on the affected volume. This does not add general extension-record support for files.

### Reparse and extension support in 0.3.3

MFT mode distinguishes known [cloud and WOF reparse tags](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-tags) from links. Cloud files/directories and WOF files are counted using MFT metadata only; their contents are never opened or hydrated. Cloud logical totals are displayed separately and may include online-only data. These totals can exceed locally occupied space. Name-surrogate links (junctions, symlinks, mount points), unknown tags and missing tags remain excluded. Diagnostic categories include the hexadecimal tag, and inherited exclusions retain their blocking ancestor.

The scan retains extension records and joins them to their exact base reference including the sequence number. It reconstructs names and initial unnamed DATA metadata without reading file contents or interpreting allocation runlists. Missing or conflicting metadata remains partial. This is targeted logical-size support, not a general NTFS parser or allocated-space accounting engine. NTFS system metadata trees are now labelled separately from missing user-directory parents. D remains a bounded base-record inspection; a full scan is needed to join extension records.

Tests cover cloud-tag variants, WOF, unknown tags, junctions/symlinks, extension-only names/data, stale base references, missing hard-link names and conflicting initial data extents in PowerShell 5.1 and 7. Live drive totals still require verification after upgrading.
