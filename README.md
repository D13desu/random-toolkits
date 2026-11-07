# Random Toolkits

Personal system administration, investigation, and troubleshooting tools.

## Available tools

| Tool | Location | Requirements |
| --- | --- | --- |
| Windows Toolkit v0.20.0 | [Windows tools](win/net/README.md) | Windows, PowerShell 5.0+ (tested on 5.1 and 7) |
| M365 Toolkit v0.4.0 | [m365](m365/README.md) | PowerShell 7.4+, Microsoft 365 permissions appropriate to the selected investigation |

## Run all Windows tools

```powershell
irm https://tools.d0xd.com/win | iex
```

One entry point: **1 Network**, **2 Power and device health**, **3 Storage**, **4 Printing**, **5 Group Policy**, **6 Event Logs**, **7 Registry tweaks**, **8 Toolkit cleanup**, **9 Health dashboard**, **10 Startup apps and scheduled tasks**, **11 Services**, and **12 Windows repair centre**. Network contains overview, connectivity, DNS, AD/time, routing/proxy and firewall checks, plus a numeric TCP/UDP connection viewer with PID/process paths. Power includes laptop/battery detection, plans, NIC sleep settings, sleep blockers, disk headroom and restart indicators. Storage opens a read-only explorer of drives, folders and files sorted by size. M365 stays separate.

Printing includes inventory, queues, ports/drivers, spooler status and printing events. Group Policy shows applied user/computer results and policy events. Confirmed fixes can restart/start the local spooler or request a scoped policy refresh. Event Logs offers log discovery and a paginated CLI viewer filtered by time, IDs, severity, provider and message text.

The old `/win/net` URL also opens this unified menu. No separate command is needed for the disk explorer: its pinned, checksum-verified script downloads when selected. See [compatibility, legacy TLS and local execution](win/net/README.md) and [disk size limitations](win/disk/README.md).

**Storage > 1** opens **Disk Usage 1.3.0**, the preferred C# helper. Auto mode uses MFT for elevated fixed local NTFS drive roots and native enumeration for other paths or unelevated sessions. Browsing shows current modified dates, available volume space and reconciled volume accounting. `L` monitors visible files and directories for live logical-size changes; `R` performs a clean rescan. PowerShell 5.1+ and .NET Framework 4.5.1+ are required; no automatic elevation occurs. The pinned ZIP and executable checksums/version are verified, and the temporary package is removed on exit. **Storage > 2** retains the older Disk Usage 0.4.6 compatibility scanner.

Disk Usage 0.4.6 offers native directory scanning and an optional elevated NTFS MFT view with On disk allocation, logical sizes, cached navigation and explicit incomplete totals. See its documentation for allocation semantics and independent Windows API validation.

Repairs appear beside their related checks: DHCP renewal under Connectivity, cache flush under DNS, and trust repair/time resync under Active Directory and time. Repairs require an administrator session and yes/no confirmation. Workgroup PCs have no AD trust to repair; the toolkit does not automatically join domains.

Power repairs can select an existing power plan or disable supported sleep settings on a selected physical NIC. Unsupported plans/features are not forced. NIC changes do not automatically restart the adapter.

## Run M365 Toolkit

In PowerShell 7.4+, once GitHub Pages and DNS are ready:

```powershell
irm https://tools.d0xd.com/m365/ | iex
```

The launcher downloads the CI-built v0.4.0 toolkit from the same Pages deployment and verifies its generated SHA-256 checksum before execution. Missing modules are installed from PSGallery only after confirmation. On Windows, the toolkit and reports are stored under `%LOCALAPPDATA%/Random-Toolkits/m365/0.4.0/`. No administrator rights are required for installation. Review remote scripts before executing them.

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

The imported v0.4.0 toolkit investigates Microsoft 365 data without changing tenant state. It can write local reports and export quarantined email; handle these outputs as sensitive data. Generated `reports/` directories are excluded from Git. Review the tool's README for permissions and limitations.

## Layout and publication

Windows tools live under `win/<tool>/`. The cross-platform M365 toolkit lives under `m365/`.

GitHub Actions runs `tests/Sync-Site.ps1` to assemble the self-contained Windows and M365 endpoints, then deploys the generated repository-root artifact from `main`; configure the Pages source as **GitHub Actions**. `CNAME` specifies `tools.d0xd.com`, and `.nojekyll` preserves static files without Jekyll processing. The `m365/index.html` file deliberately contains raw PowerShell, not HTML: Pages serves this directory index to `Invoke-RestMethod`. The extensionless `/m365` URL redirects to `/m365/`; the documented command uses the trailing slash directly.

Maintain `m365/Launch-M365.ps1` and `m365/M365-Toolkit.ps1` as the launcher and toolkit sources. Run `tests/Sync-M365.ps1` for an M365-only local build or `tests/Sync-Site.ps1` for the complete site; CI runs the complete build before deployment, injects the toolkit's SHA-256 into the launcher, and publishes `m365/index.html` byte-for-byte from it. The launcher downloads the toolkit from the same Pages artifact, verifies it, and runs it as a local file so `$PSScriptRoot` and report paths work correctly. Update the version directory together with toolkit version changes.
