# Disk Usage 0.4.2: unsupported-record investigation

Date: 2026-11-05. Read-only C: investigation using Windows PowerShell 5.1. Production scanner behavior and the published version remain unchanged.

## Findings

A full scan reproduced exactly 4,966 unsupported files in 39.8 seconds. The earlier 91.8-second run is not sufficient evidence of a persistent performance regression.

| Cause | Count |
| --- | ---: |
| Nonresident attribute list unreadable: Windows returns “The request is not supported”; data and standard-information metadata present | 4,962 |
| NTFS metadata records with no unnamed DATA stream: `$Quota`, `$ObjId`, `$Reparse`, `$UsnJrnl` | 4 |

The four NTFS metadata records are currently tested for unsupported file metadata before their excluded ancestry is classified. Their missing unnamed DATA streams do not make them malformed user files.

The ordinary-file group still falls back to comparing assembled FILE_NAME attributes with the MFT header link count because its attribute list cannot be read. That comparison rejects records whose available metadata can nevertheless agree with Windows' current file view. This investigation does not establish why the raw volume provider rejects reads, or why the header counts differ.

## Independent sample

Selected the reported examples, representatives from each failure group, and 48 evenly spaced ordinary records ordered by reference. Deduplication produced 56 samples: 52 ordinary files and four metadata records.

For all 52 ordinary files:

- OpenFileById succeeded using FILE_READ_ATTRIBUTES, OPEN_REPARSE_POINT and OPEN_NO_RECALL.
- The returned file reference matched the requested reference, including its sequence.
- GetFileInformationByHandle link count and FindFirstFileName/FindNextFileName enumeration count matched the scanner's visible filename count (excluding DOS-only aliases).
- Logical size matched Windows' file information.
- MFT-accounted allocation matched the sum returned by GetFileInformationByHandleEx(FileStreamInfo).
- Stream enumeration succeeded. Each sampled file had only the unnamed DATA stream; this sample does not validate named-stream or compressed/sparse fallback behavior.

There were zero mismatches among those 52 files. The four system metadata records returned error 2 from OpenFileById and were not treated as successful API comparisons.

| File | Header count | Visible MFT names | Windows links | Enumerated links |
| --- | ---: | ---: | ---: | ---: |
| botDetection.md | 8 | 7 | 7 | 7 |
| StartMenu.NET.dll | 6 | 1 | 1 | 1 |
| zxing_reader.wasm | 44 | 4 | 4 | 4 |
| OSClient.NET.dll | 4 | 1 | 1 | 1 |

OSClient.NET.dll has two raw filename attributes but only one displayed name; its DOS alias is not another visible hard link.

## Recommended implementation

1. Classify excluded NTFS metadata ancestry before requiring an unnamed DATA stream.
2. When raw attribute-list access fails, attempt a bounded Windows metadata fallback for affected files only. Verify record identity, enumerate links and streams completely, and reconcile paths against the cached directory graph before attributing allocation. Retain explicit uncertainty on errors, stale IDs, incomplete enumeration, or changing metadata.
3. Validate the fallback on resident, named-stream, sparse, compressed and reparse fixtures before release. The 52-file sample supports this approach but is not proof that all 4,962 records are recoverable.

The reader must not simply ignore the header count for every unreadable attribute list. This investigation establishes an independent verification route, not blanket permission to accept incomplete records.

## Reproduce

Run `tests/Inspect-MftUnsupported.ps1 -Drive C:\ -ReportPath <local-json-path>` from an administrator PowerShell. It instruments an in-memory copy of the scanner, retains unsupported records, and probes at most 64 samples. It does not modify toolkit source at runtime or read file contents. The JSON contains local filenames and paths; keep it local when sharing only aggregate findings.

API references: [OpenFileById](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-openfilebyid), [hard-link enumeration](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findfirstfilenamew), [stream information](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_stream_info).
