# Disk Usage 0.1.0

Read-only, ncdu-inspired console explorer for PowerShell 5.0+. Tested on Windows PowerShell 5.1 and PowerShell 7. No modules or administrator rights are required; elevated access can reduce permission-related omissions.

```powershell
irm https://tools.d0xd.com/win/disk/ | iex
```

Local: `./win/disk/Disk-Usage.ps1`, or `./win/disk/Disk-Usage.ps1 -Path 'C:\Users'`.

Lists all detected drives with total, used and free bytes, ordered by used space. Choose a drive or **F** for a folder. The scanner includes hidden files, recursively totals logical file lengths, then lists immediate folders and files largest-first. Select a folder number to drill down. **U** goes up, **N/P** changes pages, **R** rescans the chosen root, **E** shows exclusions/errors, and **0** returns to drives/exits. Ctrl+C cancels the launcher. No delete, cleanup or file execution actions exist.

Directory totals are cached for the session; individual file metadata is read when visiting a directory. Rescan after files change. Memory scales with directory count and the number of entries in the current folder. A full drive can take minutes or longer, especially on slow/network storage.

Junctions, symlinks, mounted-folder reparse points and cloud reparse placeholders are skipped to avoid cycles and crossing into other trees. Inaccessible/disappearing entries are counted and up to 100 examples retained; affected totals are marked **partial**. Skipped mounted volumes may need scanning through their own accessible root. File contents are never opened by the scanner.

These are **logical sizes**, not allocated disk space. Hard links count per pathname; compression, sparse files, filesystem metadata, snapshots, protected files and excluded cloud placeholders can make totals differ from drive used space. Directory/file totals can also differ when the filesystem changes during a scan.

The source is `Disk-Usage.ps1`; copy it byte-for-byte to `index.html` after edits for Pages. The network toolkit downloads a checksum-verified, commit-pinned copy when its disk explorer option is selected; update that pin when releasing a new explorer version.

Regression tests: `tests/Test-DiskUsage.ps1` in both shells. Tests use a small isolated temporary tree to verify nested totals, hidden files, empty folders, sorting, reparse-loop exclusion, navigation, no file changes and IEX startup. They do not scan entire production drives.
