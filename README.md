# Random Toolkits

Personal system administration, investigation, and troubleshooting tools.

## Available tools

| Tool | Location | Requirements |
| --- | --- | --- |
| Windows Toolkit v0.13.0 | [Windows tools](win/net/README.md) | Windows, PowerShell 5.0+ (tested on 5.1 and 7) |
| M365 Toolkit v0.3.7 | [m365](m365/README.md) | PowerShell 7.4+, Microsoft 365 permissions appropriate to the selected investigation |

## Run all Windows tools

```powershell
irm https://tools.d0xd.com/win | iex
```

One entry point: **1 Network**, **2 Power and device health**, **3 Storage**, **4 Printing**, **5 Group Policy**, **6 Event Logs**, **7 Registry tweaks**, **8 Toolkit cleanup**, **9 Health dashboard**, **10 Startup apps and scheduled tasks**, **11 Services**, and **12 Windows repair centre**. Network contains overview, connectivity, DNS, AD/time, routing/proxy and firewall checks. Power includes laptop/battery detection, plans, NIC sleep settings, sleep blockers, disk headroom and restart indicators. Storage opens a read-only explorer of drives, folders and files sorted by size. M365 stays separate.

Printing includes inventory, queues, ports/drivers, spooler status and printing events. Group Policy shows applied user/computer results and policy events. Confirmed fixes can restart/start the local spooler or request a scoped policy refresh. Event Logs offers log discovery and a paginated CLI viewer filtered by time, IDs, severity, provider and message text.

The old `/win/net` URL also opens this unified menu. No separate command is needed for the disk explorer: its pinned, checksum-verified script downloads when selected. See [compatibility, legacy TLS and local execution](win/net/README.md) and [disk size limitations](win/disk/README.md).

**Storage > 1** opens **Disk Usage 1.0.0**, the preferred C# helper. Auto mode uses MFT for elevated fixed local NTFS drive roots and native enumeration for other paths or unelevated sessions. PowerShell 5.1+ and .NET Framework 4.5.1+ are required; no automatic elevation occurs. The pinned ZIP and executable checksums/version are verified, and the temporary package is removed on exit. **Storage > 2** retains the older Disk Usage 0.4.5 compatibility scanner.

Disk Usage 0.4.5 offers native directory scanning and an optional elevated NTFS MFT view with On disk allocation, logical sizes, cached navigation and explicit incomplete totals. See its documentation for allocation semantics and independent Windows API validation.

Repairs appear beside their related checks: DHCP renewal under Connectivity, cache flush under DNS, and trust repair/time resync under Active Directory and time. Repairs require an administrator session and yes/no confirmation. Workgroup PCs have no AD trust to repair; the toolkit does not automatically join domains.

Power repairs can select an existing power plan or disable supported sleep settings on a selected physical NIC. Unsupported plans/features are not forced. NIC changes do not automatically restart the adapter.

## Run M365 Toolkit

In PowerShell 7.4+, once GitHub Pages and DNS are ready:

```powershell
irm https://tools.d0xd.com/m365/ | iex
```

The launcher downloads v0.3.7 from a pinned Git commit and verifies its SHA-256 checksum before execution. Missing modules are installed from PSGallery only after confirmation. On Windows, the toolkit and reports are stored under `%LOCALAPPDATA%/Random-Toolkits/m365/0.3.7/`. No administrator rights are required for installation. Review remote scripts before executing them.

While the custom domain is being configured, use:

```powershell
irm https://raw.githubusercontent.com/D13desu/random-toolkits/main/m365/Launch-M365.ps1 | iex
```

Download or clone this repository, then run from its root:

```powershell
pwsh -NoProfile -File ./m365/Install-Dependencies.ps1
pwsh -NoProfile -File ./m365/M365-Toolkit.ps1
```

On Windows, you can also run `m365/Start-M365-Toolkit.cmd` after installing dependencies. The dependency installer installs PowerShell modules for the current user. The toolkit authenticates interactively to Microsoft services.

The imported v0.3.7 toolkit investigates Microsoft 365 data without changing tenant state. It can write local reports and export quarantined email; handle these outputs as sensitive data. Generated `reports/` directories are excluded from Git. Review the tool's README for permissions and limitations.

## Layout and publication

Windows tools live under `win/<tool>/`. The cross-platform M365 toolkit lives under `m365/`.

GitHub Pages publishes `main` from the repository root, with `CNAME` specifying `tools.d0xd.com`. `.nojekyll` preserves static files without Jekyll processing. The `m365/index.html` file deliberately contains raw PowerShell, not HTML: Pages serves this directory index to `Invoke-RestMethod`. The extensionless `/m365` URL redirects to `/m365/`; the documented command uses the trailing slash directly.

Maintain `m365/Launch-M365.ps1` as the launcher source and copy it byte-for-byte to `m365/index.html` after edits. When upgrading the toolkit, update the pinned commit, version directory, and checksum together. The launcher runs the downloaded script as a local file so `$PSScriptRoot` and report paths work correctly.

The launcher's pinned download still uses `win/m365/M365-Toolkit.ps1` because that is the file's location in the historical release commit.
