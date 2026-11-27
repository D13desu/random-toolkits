# Linux Toolkit changes

## 0.6.0

- Remove the unused Sysinternals-style menu, its module and associated command-line checks.
- Keep the existing menu numbers for Maintenance (12) and Synology (13). General resource, network and service diagnostics remain in their own sections.

## 0.5.0

- Add DSM-only Synology NAS Troubleshooting menu with command compatibility, SMB sessions/handles, ACLs, identity lookup, Office owner-file inspection, shared-folder views, storage, services/packages, system/network views and a guided read-only-file workflow.
- Keep unavailable/version-dependent commands explicit; reuse generic resource helpers; no dependency installation or automatic escalation.
- Add root-gated, same-filesystem Office owner-file quarantine/restore with structured handle checks, no-overwrite moves and private recovery manifests.
- Export curated guided findings to private timestamped text files; raw configuration/logs/owner-file bytes are excluded.
- Add supplied production command-availability fixture, mocked diagnostic coverage and isolated filesystem transaction tests. Native DSM behavior still requires physical NAS validation.
