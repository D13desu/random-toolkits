# Remaining metadata gaps in Disk Usage 0.4.3

Read-only investigation on 2026-11-05, Windows PowerShell 5.1. A fresh C: scan reproduced 171 unsupported files and 534 included records with uncertain allocation in 45.0 seconds. This investigation changes diagnostic tooling only; the published scanner remains 0.4.3.

## Complete population breakdown

| Status | Metadata type | Count |
| --- | --- | ---: |
| Unsupported | WOF, tag 0x80000017 | 171 |
| Included, allocation uncertain | WOF, tag 0x80000017 | 165 |
| Included, allocation uncertain | WCI, tag 0x80000018 | 110 |
| Included, allocation uncertain | WCI variant, tag 0x90001018 | 28 |
| Included, allocation uncertain | Reparse flag present, tag unavailable | 228 |
| Included, allocation uncertain | Ordinary files, hard-link API returns error 50 | 3 |

All groups have DATA and STANDARD_INFORMATION metadata but an unreadable nonresident attribute list. Windows returns “The request is not supported” for the raw list read. The current API fallback deliberately excludes every MFT reparse record, which explains why WOF records remain even when their metadata can be independently checked.

## Independent sample

The diagnostic retained both unsupported and uncertain records, selected group representatives and records spread through the population, and queried 64 unique records. It opened by full file ID using FILE_READ_ATTRIBUTES, OPEN_REPARSE_POINT and OPEN_NO_RECALL. No file contents were read. Path-based hard-link enumeration was skipped where the opened handle reported the reparse attribute.

**WOF:** 29 samples (14 unsupported, 15 uncertain) matched Windows' visible link count, enumerated link count, unnamed logical size and sum of stream allocation, with zero query failures or mismatches. The MFT WOF tag and the opened handle's attributes differed in these samples: the handle did not report FILE_ATTRIBUTE_REPARSE_POINT. This supports testing a narrow WOF exception to the initial MFT reparse gate, while retaining identity, path and stream checks and rejecting a handle that still reports a reparse point. It does not establish that all 336 WOF records will pass.

**Container/unknown-tag reparses:** eight sampled records reported API allocation different from their local MFT allocation. For example, one OSClient.NET.dll record had zero accounted MFT allocation but Windows reported 53,751,808 allocated bytes. Other sampled records agreed at zero. Do not replace local allocation with Windows' reported value or claim completeness based solely on readable API metadata: the views can differ. The precise cause of the difference remains unproven; a filtered/projected view is a hypothesis, not a confirmed diagnosis.

**Ordinary files:** chrome.dll, guest.data and vulkan_nvidia.data all have one visible MFT name and one Windows-reported link. Logical size and stream allocation match, and their identity and opened-handle path are available. Only FindFirstFileName fails, with error 50. This supports a single-link verification path using the handle's path, provided it exactly matches the cached path and identity/link count remain stable across repeated checks. Multi-link files must still require complete enumeration.

## Recommended next implementation

1. Allow a narrowly scoped WOF verification attempt. Keep current checks for exact record identity, complete cached paths, stream names, per-stream allocation and repeated agreement. Preserve exclusion on any discrepancy or unsupported operation. Validate against real WOF fixtures before release.
2. Handle Windows' hard-link enumeration error 50 for ordinary single-link files by checking the opened handle's path against the single cached MFT path, with the same repeated identity and allocation validation. Do not treat access-denied, arbitrary errors or multi-link cases as equivalent.
3. Keep container and unknown-tag reparse allocations explicitly uncertain. Recovering tags and understanding the differing allocation views is separate work.

The first two changes target 336 WOF records plus three ordinary files; these are candidates, not guaranteed recovery counts. The other 366 uncertain records should not be forced into a complete total.

Reproduce with `tests/Inspect-MftUnsupported.ps1 -Drive C:\ -ReportPath <local-json-path>` in an administrator PowerShell. The local JSON includes filenames and paths; this summary omits private paths.

References: [Microsoft reparse tags](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-tags), [OpenFileById flags](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-openfilebyid), [stream allocation information](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_stream_info).
