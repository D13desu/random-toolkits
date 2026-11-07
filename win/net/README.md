# Windows Toolkit 0.20.0

Use **B** (or **0**) to return from a menu. Data-entry prompts show **B: back** to cancel the current action; blank input keeps its documented default. Disk explorers use **B** for parent folder, then drive selection, then Storage. During native/MFT scans, **B** cancels back to drives; **Q** stops and opens partial results. Completed one-shot checks return with Enter. Only the top-level Exit closes the Windows launcher.

Windows diagnosis and repair, grouped by troubleshooting area. Each submenu separates **CHECKS** from **REPAIRS**, which change system state only after explicit confirmation. No modules are installed and the toolkit does not elevate itself; open PowerShell as administrator to use repairs. Probes send network traffic to the selected host and local gateways. The disk explorer is downloaded on demand from a pinned Git commit and verified with SHA-256 before local execution.

```powershell
irm https://tools.d0xd.com/win | iex
```

Requires Windows and PowerShell 5.0 or later. Tested with Windows PowerShell 5.1 and PowerShell 7; 5.0 uses the same compatible syntax/APIs but has not been runtime-tested. PowerShell 5.1 is recommended for legacy machines. This does not change the M365 toolkit's PowerShell 7.4+ requirement.

If an old Windows PowerShell session cannot negotiate HTTPS, enable TLS 1.2 for that session before downloading (OS TLS/certificate support is still required):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
irm https://tools.d0xd.com/win | iex
```

## Menu layout

The root menu is **1 Network**, **2 Power and device health**, **3 Storage**, **4 Printing**, **5 Group Policy**, **6 Event Logs**, **7 Registry tweaks**, **8 Cleanup**, **9 Health dashboard**, **10 Startup/tasks**, **11 Services**, and **12 Windows repair centre**. M365 remains separate at `/m365`. The older `/win/net` endpoint is an alias for the unified Windows menu. Under **Network**:

The root menu also shows a cached system summary: current username and security groups, hostname, public and private IPv4 addresses, aggregate fixed-disk capacity/free space, CPU, physical RAM, and Windows version/build. Public-IP discovery makes one HTTPS request to `api.ipify.org` with a three-second timeout when the menu starts; a failed or blocked lookup is shown as unavailable and does not block use of the toolkit.

| Main menu | Checks | Repairs |
| --- | --- | --- |
| 1 Overview and quick diagnosis | Adapter/IP overview, combined quick check | None |
| 2 Connectivity and adapters | Gateway/host connectivity, TCP ports, adapter overview | Renew selected adapter DHCP lease |
| 3 DNS | DNS lookup | Flush DNS cache |
| 4 Active Directory and time | Membership, discovery/site, AD DNS, secure channel, time, shares | Repair member trust, resync local time |
| 5 Routing and proxy | Routes, WinHTTP/user proxy | None |
| 6 Firewall | Firewall profiles | None |

`0` returns from a submenu or exits the main menu. Unavailable actions remain visible with the reason underneath. Repair entries are yellow and marked `CHANGES SYSTEM`; minimum PowerShell and administrator requirements remain visible. The old `A` shortcut still opens Active Directory. Noninteractive check IDs are unchanged.

## Storage

**1** opens **Disk Usage 1.3.0**, the preferred C# helper, in automatic mode: elevated fixed local NTFS drive roots use MFT; folders, other filesystems and unelevated sessions use native enumeration. Native scans show logical sizes, not physical allocation. The browser shows each visible entry's current modified date, the containing volume's space available to the current user and volume-wide reconciliation of NTFS metadata and reserved storage. **2** retains **Disk Usage 0.4.6** as the compatibility scanner. F1 opens helper accounting, diagnostics and timing reports; legacy A/E/T commands still work. PowerShell 5.1+, .NET Framework 4.5.1+ and archive/hash commands are required for the helper; missing requirements are marked unavailable. The compatibility option supports PowerShell 5.0+. There is no automatic elevation or silent retry of an MFT failure using a different scan mode.

In Disk Usage 1.3.0, `L` polls visible files every two seconds and highlights growth, shrinkage, replacement or deletion without reading file contents. Visible directories share one round-robin background native probe, with the selected row first, so their logical sizes can follow extraction or copy activity without concurrent subtree scans. ON DISK directory allocation, page totals, sorting, new top-level rows and reconciliation remain cached. `R` releases the old helper process and performs a full same-engine refresh, returning to the current folder when possible. Automatic live polling requires an interactive ConsoleHost; `R` remains available in line-input hosts.

The helper downloads from a pinned GitHub release, with the ZIP's SHA-256 checked before extraction. Its client verifies the executable hash and version handshake. It runs from an isolated temporary directory that is removed on exit. No separate `irm` command or permanent installation is required. The noninteractive action ID is `disk-helper`.

## Power and device health

- Laptop/portable detection uses firmware chassis codes, supplemented by battery presence. Battery-only detection is marked ambiguous (for example, UPS-equipped desktops).
- Shows battery charge/status, active classic power plan and available plans. Flags laptops not using the standard High performance GUID; Balanced/custom plans are not automatically considered faulty. Windows power-mode overlays are separate. Some hardware exposes only Balanced; the toolkit does not create unsupported plans or disable Modern Standby.
- Displays NIC AllowComputerToTurnOffDevice, SelectiveSuspend and DeviceSleepOnDisconnect where exposed by the driver. Errors are reported as unavailable.
- Reports supported sleep states, AC/battery sleep/display settings, power requests, last wake reason, uptime, fixed-drive free space (warns below 10%) and two common pending-reboot registry markers. These indicators are not exhaustive diagnoses.

Confirmed administrator repairs can select an existing power plan (previous plan shown for rollback) or disable supported sleep settings on one selected physical NIC. NIC changes preserve Wake-on-LAN and other offloads and pass `NoRestart`; a later manual NIC restart/reboot may be required. Values are read back and failures remain warnings. Keeping a NIC awake does not prevent Windows system sleep. Increased performance/less power saving can increase battery drain, heat and fan noise.

Power check IDs: `power`, `nic-power`, `sleep`, `wake`, `quality`. Storage check ID: `disk` (opens interactive explorer). Power repair IDs: `set-power-plan`, `nic-awake`.

## Storage

Choose **Storage > Open disk usage explorer**. Disk Usage 0.4.6 lists drive total/used/free space, with cached folder navigation and partial results. The default native directory scanner reports logical sizes; optional elevated **M** mode reads local NTFS metadata and sorts by **On disk** allocation alongside logical size. It accounts for compressed, sparse, resident and named-stream data, charges hard links once, and reads reparse records without following their targets. Unknown allocation and omissions remain explicit lower bounds. See [Disk Usage documentation](../disk/README.md) for limitations and validation.

## Printing

Lists installed printers (CIM fallback when Get-Printer is missing), per-printer queued jobs, ports/drivers and the local spooler status. Queue access errors are reported per printer so other results remain visible. Printing events default to `Microsoft-Windows-PrintService/Admin`; enter `Microsoft-Windows-PrintService/Operational` if that log is already enabled. No log is enabled automatically.

The confirmed administrator repair starts a stopped spooler or restarts a running one, then waits up to 15 seconds for Running. It does not force-stop dependent services, delete spool files, remove printers or intentionally cancel jobs. Printing and remote clients of a print server can be interrupted. A running spooler does not prove a printer can print.

## Group Policy

Uses `gpresult /scope user /r` for the current account and `gpresult /scope computer /r` for computer results (administrator). An elevated session running as another user reports that user's policy. Membership/role and `Microsoft-Windows-GroupPolicy/Operational` event browsing are included. No RSOP data, missing domain connectivity or permissions are shown as errors rather than healthy policy results; local/workgroup PCs may still have local policy.

Confirmed refresh runs `gpupdate /target:user /force /wait:0` or `/target:computer /force /wait:0`. It requests background processing; command success is **not proof of policy completion**. Inspect policy events/results afterward. No `/boot` or `/logoff` option is used. Policy itself can apply settings and configured scripts/extensions, and some changes need a later reboot/logoff.

## Event Logs via CLI

List logs using a name pattern, or browse one exact log name. Filters: lookback hours (1-8760), comma-separated IDs (0-65535), levels (0-5), provider name/wildcard, literal case-insensitive message text, and maximum recent candidates (1-1000, default 200). Log/time/ID/level/provider filtering runs in the event service via FilterHashtable. Text filtering runs **after** the candidate cap, so older text matches may be omitted. Results are newest-first, up to five per page (fewer in short consoles), with a three-line message preview beneath each event. Arrow keys select events; Enter opens the full message and X shows the cached XML. Line-input hosts retain numbered navigation.

Security and protected logs may require elevation or Event Log Readers membership. Disabled/missing logs and access errors are not treated as empty matches. No logs are cleared or enabled and nothing is exported automatically. Messages may contain sensitive usernames/document names; inspect locally before sharing.

Noninteractive checks: `printers`, `print-jobs`, `print-ports`, `spooler`, `gp-user`, `gp-computer`. Event choices (`print-events`, `gp-events`, `event-logs`, `event-browser`) are interactive. For scripted filtering:

```powershell
. ./win/net/Network-Toolkit.ps1 -NoMenu
Get-PcEventRecords -LogName System -Hours 48 -Ids 7031,7034 -Levels 2,3 -Limit 100
```

## Registry tweaks

Root option **7 Registry tweaks** has separate **1 Outlook** and **2 Remote Desktop** submenus. Each submenu inspects its own values, applies a tweak, or removes its override to use defaults. Each mutation requires `y`/`yes`, saves a unique `.reg` undo file under `%LOCALAPPDATA%\Random-Toolkits\registry-backups`, then reads back the values. If backup fails, nothing is changed. If a write fails partway through, the error names the undo file. Import it with Registry Editor under the same account (elevated for RDP) to restore the exact previous values, including deleting values that were originally absent. Resetting defaults is distinct from restoring that backup. No unrelated values are removed.

- **Classic Outlook local PST/OST limit:** Office `16.0` current-user preferences, Unicode files only. Choose a whole number of GB (1â€“1000; default 100). Sets `MaxLargeFileSize` in MB and `WarnLargeFileSize` to 95% of that maximum. This threshold stops adding data; it does not produce an advance warning popup. Close Outlook first. The tool blocks changes when size values exist in the corresponding current-user policy key. Run as the intended Outlook user; elevation under another account targets that account. This does not increase Exchange/Microsoft 365 server mailbox quotas or configure new Outlook. Above 50 GB can reduce performance; archive or reduce cached mail where practical. Resetting after a file has grown beyond the default may prevent adding mail until its size is reduced.
- **Older RDP redirection warning:** administrator required. Sets `HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services\Client\RedirectionWarningDialogVersion` to DWORD `1`. This machine-wide compatibility setting reduces the newer resource-consent protection for connections opened from RDP files; it does not turn off certificate validation or NLA. Use for trusted connections. Microsoft may remove support in a future update. Reset deletes the override; managed policy can reapply it. Start a new connection after changing it.

Sources: [Microsoft Outlook size configuration](https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/data-files/configure-size-limit-outlook-data-files), [Microsoft RDP warning documentation](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/remotepc/understanding-security-warnings), and the [requested LazyAdmin walkthrough](https://lazyadmin.nl/it/fix-remote-desktop-security-warning/).

`Invoke-PcRegistryTweak outlook -SizeGB 100 -WhatIf` previews a change after dot-sourcing with `-NoMenu`. Both apply and reset support `-WhatIf`. `tests/Test-RegistryTweaks.ps1` tests cancellation, preview, values, backup contents, defaults, elevation, policy gating and backup failure with mocked writes. Live registry changes are not exercised.

Maintain `Registry-Tweaks.ps1`, then run `tests/Sync-RegistryTweaks.ps1` to update its embedded launcher block and both Pages endpoints. The launcher retains the generated embedded copy so `irm ... | iex` remains a single, offline-after-download entry point.

## Checks

| Check | Behavior / limitations |
| --- | --- |
| Overview | Adapter state, addresses, gateways, DNS servers and MAC addresses using .NET |
| Connectivity | Active-adapter gateways and selected host via ICMP, then selected host TCP 443 |
| DNS | Resolve-DnsName when present; system resolver fallback without TTL/type metadata |
| TCP | User-selected host/port; 3-second connection timeout including DNS; reports handshake only |
| Routes | Native route.exe print for IPv4/IPv6 |
| Proxy | WinHTTP and current-user Internet Settings; applications may use other settings |
| Firewall | Profile state and default actions; requires Get-NetFirewallProfile; effective policy/rules may differ |
| Quick | Overview, connectivity and DNS; errors in one section do not stop the others |

Default probe target is `example.com`; prompts allow another hostname/IP. ICMP may be filtered. TCP success does not establish HTTP, TLS, authentication, or service health. DNS and ICMP name resolution use the system resolver and can take longer on broken DNS configurations.

Each menu entry displays its minimum PowerShell version. Missing commands, incompatible versions and administrator requirements are labeled `UNAVAILABLE` and blocked before execution. Runtime access errors return to the menu. No AD PowerShell module or dependency installation is required.

## Repairs within each topic

All repairs require administrator access and an `Apply this change? [y/N]` confirmation after displaying the target and effects. Only `y` or `yes` proceeds (case-insensitive); pressing Enter or any other response cancels. The underlying `Invoke-NetworkRepair` function supports `-WhatIf`; `-Confirm:$false` does not bypass this confirmation. Diagnostics never automatically initiate repairs.

| Repair | Changes and checks |
| --- | --- |
| Flush DNS cache | Runs ipconfig /flushdns on the local PC. |
| Renew DHCP | Lists IP-enabled DHCP adapters, requires a selected InterfaceIndex and renews only that adapter's IPv4 lease using RenewDHCPLease. Rechecks the adapter before acting. Does not release addresses or modify static IP configuration. May disconnect a remote session. |
| Resync time | Runs w32tm /resync locally using existing configuration. May change system time; does not change time servers or restart services. |
| Repair computer trust | Domain members only. Uses the same DC for precheck, Test-ComputerSecureChannel -Repair, and postcheck. Skips healthy trust; prompts for authorized domain credentials only when repair is needed. Credentials are not saved by the toolkit. |

A **workgroup computer has no AD trust channel** to test or repair. Joining it to AD is a separate operation and is not performed by this menu. Secure-channel repair remains blocked on workgroups, DCs and unknown roles. The toolkit performs no automatic reboot, domain leave/rejoin, firewall reset or network-stack reset.

Repairs report native exit codes or CIM result codes. Successful command completion is not a guarantee that the original problem is fixed; rerun the relevant diagnostics afterward. Secure-channel repair performs its own postcheck. Runtime failures return to the menu without an automatic retry.

## Active Directory and time [4]

| Check | Requirements / behavior |
| --- | --- |
| Domain membership and role | Local CIM query; distinguishes workgroup, member workstation/server, DC, and unknown role. Entra join alone does not count as AD membership. |
| DC discovery and site | Domain membership and nltest.exe; uses only /dsgetdc and /dsgetsite. |
| AD DNS | Domain membership and Resolve-DnsName; LDAP DC-locator and Kerberos SRV queries, followed by target address resolution through configured DNS. |
| Computer secure channel | Domain-member workstation/server only; Test-ComputerSecureChannel without repair. Blocked on DCs, workgroups and unknown roles. |
| Time diagnostics | Domain membership, administrator, w32tm.exe; local source/status and three offset samples against the selected DC. No resync or configuration changes. |
| SYSVOL / NETLOGON | Domain membership; checks access to each share root using current Windows credentials. Does not validate contents or replication. |

Secure-channel, time and share checks accept an optional DC hostname. Blank selects a DC automatically; use an explicit hostname for repeatable tests. DC discovery and DNS checks use the local computer's AD domain. Diagnostic checks use current Windows credentials; only trust repair prompts for credentials. Native output is preserved in its original language alongside the exit code; a successful command is not a declaration that the whole domain is healthy. A time sample is diagnostic output, not an automatic Kerberos health verdict.

Domain discovery, DNS and SMB operations use Windows timeouts and can take time when infrastructure is unavailable. Ctrl+C interrupts the running launcher. Permission errors are preserved rather than reported as broken trust. This release does not include dcdiag/repadmin checks.

The secure-channel restriction follows [Microsoft's Test-ComputerSecureChannel documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-computersecurechannel?view=powershell-5.1). Time diagnostics use the read-only query and stripchart operations from [Windows Time service tools](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

## Local and noninteractive use

```powershell
.\win\net\Network-Toolkit.ps1
.\win\net\Network-Toolkit.ps1 -Check tcp -Target localhost -Port 443
.\win\net\Network-Toolkit.ps1 -Check quick -Target example.com
.\win\net\Network-Toolkit.ps1 -Check ad-context
.\win\net\Network-Toolkit.ps1 -Check ad-secure -DomainController dc01.example.com
.\win\net\Network-Toolkit.ps1 -Check ad-dns
```

Noninteractive checks return objects (route.exe/netsh.exe also emit native text). A failed connectivity probe returns `Status=WARN`; it does not set a failing process exit code. Use returned status fields when automating.

## Maintenance and validation

Add checks to `Get-NetworkChecks`, supplying minimum PS version, required commands, elevation requirement and an action. Keep the launcher itself parseable on PowerShell 5.0; future newer-language implementations must live in separate files loaded only after compatibility checks.

AD entries live in `Get-AdChecks` and also declare allowed machine roles. Both the menu and noninteractive dispatcher enforce requirements; secure-channel testing additionally rechecks the role immediately before invoking the cmdlet. AD check IDs are `ad-context`, `ad-discovery`, `ad-dns`, `ad-secure`, `ad-time`, and `ad-shares`.

`win/net/Network-Toolkit.ps1` remains the assembled launcher source. After editing any maintained module, run `tests/Sync-WindowsToolkit.ps1` for a local build; it synchronizes every embedded Windows module and copies the assembled launchers byte-for-byte to `win/index.html` and `win/net/index.html`. GitHub Actions runs the same build for pushes and pull requests, then deploys the freshly generated site artifact from `main`. Configure the repository's Pages source as **GitHub Actions**. GitHub Pages serves the generated raw scripts through directory indexes, including redirects from `/win` and `/win/net`. The Windows launcher does not rely on `$PSScriptRoot`; only the disk tool requires an additional HTTPS download. Update its pinned commit and SHA-256 together when releasing disk changes.

Run the regression checks in both shells:

```powershell
powershell.exe -NoProfile -File tests/Test-NetworkToolkit.ps1
pwsh.exe -NoProfile -File tests/Test-NetworkToolkit.ps1
powershell.exe -NoProfile -File tests/Test-AdToolkit.ps1
pwsh.exe -NoProfile -File tests/Test-AdToolkit.ps1
powershell.exe -NoProfile -File tests/Test-NetworkRepairs.ps1
pwsh.exe -NoProfile -File tests/Test-NetworkRepairs.ps1
powershell.exe -NoProfile -File tests/Test-NetworkMenus.ps1
pwsh.exe -NoProfile -File tests/Test-NetworkMenus.ps1
powershell.exe -NoProfile -File tests/Test-PowerToolkit.ps1
pwsh.exe -NoProfile -File tests/Test-PowerToolkit.ps1
powershell.exe -NoProfile -File tests/Test-DiskUsage.ps1
pwsh.exe -NoProfile -File tests/Test-DiskUsage.ps1
powershell.exe -NoProfile -File tests/Test-AdminTools.ps1
pwsh.exe -NoProfile -File tests/Test-AdminTools.ps1
```

Tests cover parsing, source/endpoint parity, invalid input, compatibility gates, open/closed loopback TCP ports, adapter enumeration, localhost DNS, and IEX startup/exit. They require no tenant, elevation, package installation or public network probe. Historical Windows installations still need real-device validation.

AD regression tests use simulated CIM/domain responses and native commands. They cover all machine roles, unknown/access-denied detection, unavailable commands, secure-channel gating, healthy/broken trust, DC input validation, read-only native arguments, localized exit errors, partial DNS failures, independent share checks and menu recovery. Tested on PowerShell 5.1 and 7; **not yet validated against a live AD domain**.

Repair tests mock every modifying command: no real cache flush, renewal, resync or trust repair is executed during testing. They verify privilege/role gates, cancellation, WhatIf, exact command arguments, static-adapter rejection, DHCP result handling, credential flow, skipping healthy trust and post-repair verification. Real repair outcomes still require validation in a suitable test environment.

Menu tests verify that every action remains reachable, every category returns to the main menu, DNS repair cancellation preserves the yes/no prompt, and unavailable AD repairs are blocked before collecting inputs. Add or reorganize topics through `Get-NetworkCategories`; diagnostics and repairs continue to use their existing dispatchers and checks.

Power tests simulate laptop/desktop firmware, localized plan output, missing plans, confirmation/cancellation, and driver support. All changes are mocked. Read-only power/health provider calls were checked on a Windows desktop; real laptop and NIC modification outcomes still need device validation. Disk tests use isolated temporary files, including a junction loop. Windows PowerShell 5.0 remains targeted but not runtime-tested.

Printing/policy/event tests cover query filters (including level 0), literal message matching, empty vs access-denied results, invalid input, paging/detail navigation, per-printer errors, repair cancellation, spooler state handling and scoped gpupdate arguments. Mutations are mocked. Read-only printer inventory and System event retrieval were smoke-tested locally; real service restart and domain policy processing are not exercised by tests.

Experimental disk browsing supports Up/Down selection, Enter/Right to enter a folder, Left/Backspace/Escape to return, and Ctrl+Enter (or O) to open the selected directory in Explorer. With a file selected, Explorer opens the current directory. Line-input navigation remains available in redirected hosts.

## Network discovery

Open Network > Connectivity and adapters > Discover network devices / TCP ports (option 4). Enter an IPv4 CIDR such as `192.168.1.0/24`, a single IPv4 address, or a full range such as `192.168.1.10-192.168.1.50`. Local adapter prefixes are shown for reference; scanning starts only after target, ports and timeout are entered.

Uses .NET ICMP and ordinary TCP connections, with no Nmap installation or administrator requirement. Compatible with PowerShell 5.0+; tested on 5.1 and 7. Limits: 1024 addresses, 16 distinct TCP ports, 32 concurrent hosts by default and 100-2000 ms per probe. ICMP failure does not skip TCP checks. Default ports: 22, 80, 443, 445, 3389, 9100. No UDP scan, service/banner interrogation, OS fingerprinting or credential attempts.

B/Esc during scanning stops queued work, disposes workers, and opens completed partial results. Results initially show responding addresses; A toggles all completed addresses. N/P pages, E exports all completed rows to a new CSV (including scope and completion counters), and B returns to Connectivity. No response is not proof a device is offline; a short timeout or firewall may hide it. TCP refusal is distinct from unanswered probes and other errors. Port numbers alone do not identify applications. Testing uses loopback listeners, not a LAN sweep.

`win/net/Network-Discovery.ps1` is the maintained module source, embedded between markers in the self-contained launcher. Keep the embedded block and both Pages copies synchronized; `tests/Test-NetworkDiscovery.ps1` checks the block.

### MAC and IEEE assignment lookup

Discovery now displays exact-IP Windows neighbor-cache MACs and the IEEE registered organization. MAC status distinguishes local/randomized, multicast/broadcast, no match, missing data and conflicting MACs across interfaces. Cached entries (including Stale) are observations, not proof of liveness; no gateway MAC is substituted for a routed target. Proxy ARP can still represent a proxy rather than the endpoint. The assignee is not a verified device manufacturer or model.

D toggles MAC and TCP-detail views. M looks up a MAC manually; colon, hyphen, dotted and plain hexadecimal forms are accepted. CSV includes MAC, matched prefix/length, vendor, status, interface indexes, neighbor state and registry retrieval time/status.

The [IEEE public MA-L, MA-M and MA-S registries](https://standards.ieee.org/products-programs/regauth/) are downloaded over HTTPS and cached under `%LOCALAPPDATA%\Random-Toolkits\oui`. Matching prefers /36, then /28, then /24. No discovered IP or MAC is sent to IEEE. Cache refresh is attempted after 30 days, with at least 24 hours between attempts; a failed refresh retains the last valid data. With no data, discovery continues and reports lookup unavailable. The neighbor table is read using [Get-NetNeighbor](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netneighbor); unavailable neighbor support does not block scanning. Local/randomized MACs deliberately receive no IEEE vendor inference.

Use `tests/Sync-NetworkDiscovery.ps1` after editing the maintained module. Tests cover synthetic prefixes, special MACs, ambiguous interfaces, missing/routed neighbors, cache downloads, offline fallback and retry throttling on PowerShell 5.1 and 7.

## Toolkit cleanup

Windows menu **8** previews recognized temporary packages, local diagnostic reports and test fixtures, download caches, or both. It lists each candidate path, size and eligibility before a yes/no deletion prompt. Only the current account's resolved TEMP directory and `%LOCALAPPDATA%\Random-Toolkits` are considered. This is not a general Windows Temp cleaner.

Normal disk-launcher exits already remove their downloaded packages. Diagnostic JSON reports may contain local file paths and machine details. Network/M365 exports can contain sensitive data; being in TEMP does not make a file harmless. The OUI cache contains public IEEE assignments.

Cleanup preserves user-chosen exports, M365 reports, registry undo files, installed modules and authentication sessions. It recognizes specific toolkit package/test naming patterns and toolkit diagnostic-report prefixes; it does not search arbitrary locations or remove the source repository/build output. The cache option removes the IEEE cache and known cached M365 script files, retaining the M365 reports subdirectory. Removing the IEEE cache requires a later download for vendor lookup.

Items modified within ten minutes, helper packages while DiskHelper is running, inaccessible paths, and trees containing links/reparse points are skipped. Paths and contents are revalidated after confirmation. Deletion is nonrecursive, permanent and not a secure erase. A failure can leave partially removed contents and is reported. No existing reports/caches were removed while implementing this option; validation used isolated synthetic fixtures.

Maintain `win/net/Toolkit-Cleanup.ps1`, then run `tests/Sync-ToolkitCleanup.ps1` to update its embedded launcher block and Pages copies. `tests/Test-ToolkitCleanup.ps1` verifies boundaries, links, preservation, changed contents, active/recent items and declined confirmation on PowerShell 5.1 and 7.

### Event log picker

Windows menu **6: Event Logs** now offers Application, System, Security, Setup, Forwarded Events, Windows PowerShell, PowerShell Operational, Defender, Windows Update, Group Policy and Printing. Selecting a preset immediately displays up to 200 recent events from the last 24 hours, including all levels (Security audit events are not filtered out). Disabled/missing/inaccessible logs report their status without enabling logs or changing permissions.

Inside a log, R refreshes the current query, F opens a filtered child view for that log, an event number displays full details, and N/P pages. B returns to the previous view/menu. Empty results keep the browser available so filters can widen the time window. C in the picker opens a custom exact log name and advanced filters; L lists/searches available logs. Advanced filters retain time, event IDs, levels, provider and literal message search, with a candidate cap of 1000. Message filtering applies after the candidate cap. Security and some operational logs may require elevated access.

Event browsing in 0.7.4 supports Up/Down in both the log picker and event list; selection crosses page boundaries. Enter/Right opens the highlighted item, Left/Esc returns, PageUp/PageDown changes event pages, and Home/End jumps to the first/last item. Event bodies appear inline as up to three wrapped lines, with an ellipsis for longer messages. Full original messages and XML remain unchanged in the detail view (M and X); Enter returns to the same event selection. The XML snapshot is captured with the original event, so opening details does not query a potentially changed log. Unsupported/redirected hosts use typed commands. Preview, selection, cross-page navigation and cached XML tests pass on PowerShell 5.1 and 7.

## Windows health dashboard

Menu **9: Health dashboard â€” start here** collects a read-only local snapshot and initially shows only WARN, REVIEW and UNAVAILABLE findings. Press **A** to show all INFO and PASS results; open any row for its evidence and related tools. It covers fixed-drive free space (warning below 10%), Windows storage-provider health, two servicing reboot indicators, non-running automatic services, Application Error/1000 crashes over 24 hours, update-install failures (ID 20) over seven days, power plan, NIC sleep, active network configuration and AD membership. NIC power policy and virtual adapters without a gateway are informational rather than health failures.

Up/Down selects a finding; Enter shows evidence and offers its related checks/repair menu. N/P pages; R refreshes; B/Esc returns. Repairs retain existing admin/role requirements and yes/no confirmation; collection never invokes repair functions. Missing permissions/providers become UNAVAILABLE, not a pass. Trigger-start services and historic failures are REVIEW items; Balanced is informational. Unaddressed virtual/filter interfaces are grouped to avoid false fault floods. PASS applies only to the stated check, not the entire PC.

**C** adds live gateway ICMP (up to three gateways), system DNS resolution (AD domain, otherwise example.com), and a read-only secure-channel test on domain-member computers only. Subsequent refreshes include those checks. Workgroups and domain controllers do not run the member trust test. DNS waits two seconds; an underlying OS resolver operation may complete later. Secure-channel timing is controlled by the Windows cmdlet. No full disk surface scan, update installation, internet speed test or service restart is performed.

The local smoke test on this PC returned 18 findings in 3.3 seconds (4 INFO, 6 PASS, 6 REVIEW and 2 unavailable NIC-driver settings). This is one live sample, not a speed guarantee or a health certification. Synthetic tests on PowerShell 5.1 and 7 cover thresholds, review vs fault classification, provider errors, AD-role gates and navigation. Maintain `Health-Dashboard.ps1` and use `tests/Sync-HealthDashboard.ps1` to synchronize the embedded launcher and both Pages endpoints.

## Startup apps and scheduled tasks

Windows menu **10** provides read-only startup inventory, scheduled-task inspection, the Task Scheduler event log, and explicit shortcuts to Windows Startup Apps settings and Task Scheduler. Inventory does not execute commands, run tasks, disable entries or change configuration.

The startup view uses Win32_StartupCommand and shows command, user, registry/folder location and a conservative executable-path assessment. It does not claim to include every packaged startup app or determine StartupApproved/disabled state. Quoted local commands can be checked for file existence; ambiguous unquoted paths, relative executables, user-dependent variables, UNC paths and COM actions are UNVERIFIED. Network paths are not probed. Arguments, script files and dependencies are not validated merely because their launcher exists.

The scheduled-task view shows state, last/next run, missed runs, unsigned hexadecimal result, run-as user, actions, working directories and selected trigger fields. Running, ready, queued, disabled and never-run scheduler statuses are informational. Other nonzero codes are REVIEW items because application exit-code semantics can vary. See [Microsoft's scheduler result constants](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants). Per-task metadata failures preserve other rows; permissions may limit the task inventory.

Up/Down and Enter navigate; N/P pages; F filters literal name/location text; C toggles all versus review/unavailable entries; R refreshes; B/Esc returns. Selecting an item displays its full metadata. There are no run/disable/delete actions in this browser. The management shortcuts open the standard Windows interfaces only when chosen.

Tests on PowerShell 5.1 and 7 cover path ambiguity, missing files, network/user-context paths, scheduler informational codes, unsigned/signed results, per-task permission failures, filtering and navigation. A live read-only sample inspected 19 startup entries and 212 visible tasks in 2.45 seconds; counts and speed vary by PC. Maintain Startup-Tasks.ps1 and run tests/Sync-StartupTasks.ps1 to update the embedded launcher and Pages endpoints.


## Services and Windows repair centre (0.10.0)

Root **11 Services** lists local Win32 services with state, startup mode and executable command. Arrow keys select; Enter opens service account, description, dependencies and actions. F filters name/display name/path, R refreshes, N/P page, B/Esc returns. Start/stop/restart require administrator rights and yes/no confirmation. Stop/restart refuse active dependents and never use Force. The toolkit does not alter startup types. Starting a service can start its prerequisites; stopping services may interrupt applications or connectivity. Windows enforces service permissions and protected-service restrictions.

The detail view opens the existing event browser on System / Service Control Manager, matching the service display name in rendered messages. This is a last-24-hours, capped-candidate search, not a comprehensive service history; localized messages or missing rendered text can omit matches. Filters remain available in the event viewer.

Root **12 Windows repair centre** offers DISM CheckHealth (recorded corruption), ScanHealth (component-store scan), SFC /verifyonly, DISM RestoreHealth, and SFC /scannow. All require elevation. Only repairs ask for confirmation; checks do not repair but Windows may write diagnostic logs. Repair choices are separate: review DISM RestoreHealth results before selecting SFC scannow. DISM may obtain repair content from Windows Update or configured sources; custom source selection is not included in this version. The toolkit never automatically reboots or resets Windows Update components.

Native output stays visible until Enter returns to the menu. Exit code, elapsed time and DISM/CBS log paths are shown. A zero exit code is not interpreted as proof of a healthy system, and 3010 is reported as restart required. Commands use explicit Windows system binary paths, including Sysnative for a 32-bit process on 64-bit Windows; health commands require Windows 8 / Server 2012 or later. Source: [Microsoft's Windows image repair guidance](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image) and [System File Checker guidance](https://support.microsoft.com/en-us/windows/experience/backup-recovery/using-system-file-checker-in-windows).

Maintain `System-Maintenance.ps1`, then run `tests/Sync-SystemMaintenance.ps1` to update the embedded launcher and Pages copies. `tests/Test-SystemMaintenance.ps1` mocks all service mutations and native repairs, checking confirmations, elevation, dependent-service protection, fixed arguments and navigation. No live repair or service mutation is performed by the tests.

## Shared menu engine (passes 1-3)

`Menu-Engine.ps1` supplies `Show-PcMenu`, keyboard mapping/input, bounded row formatting and `Confirm-PcMenuChange` (yes/no, default No). It is embedded in the launcher. Root/category menus and the Windows list browsers now use it.

Items require unique nonempty `Id` and `Label`; optional fields are `Kind` (Check, Change, Menu), `Detail`, and `DisabledReason`. Unavailable entries cannot be selected, including by number. The engine returns `Action` (Select, Refresh, Back), `Item`, and `State`, and never executes actions. Callers own execution, availability checks and confirmation. Reuse a hashtable through `-State` to preserve `SelectedId` and `Filter` across calls; missing selections fall back to the first matching row.

Up/Down select; Enter opens; Esc/Backspace return; Home/End and PageUp/PageDown navigate. Numbers plus Enter work; Backspace edits pending digits. B/0 return and N/P page. Optional F filters labels/details literally, and R returns a refresh request. Filter entry uses B to cancel and blank to clear. Empty menus remain navigable. `-Plain` forces numbered input; redirected streams and non-ConsoleHost sessions use it automatically. EOF returns Back. Interactive page capacity adapts to terminal height and rows are clipped to width.

Example (no actions are executed):

```powershell
$state = @{}
$choice = Show-PcMenu -Title 'Windows > Example' -State $state -Filterable -Refreshable -Items @(
    [pscustomobject]@{Id='inspect';Label='Inspect';Kind='Check';Detail='Read current state'},
    [pscustomobject]@{Id='repair';Label='Repair';Kind='Change';DisabledReason='Requires administrator'}
)
```

Run `tests/Sync-MenuEngine.ps1` after editing the module. Tests cover navigation, disabled items, empty views, state preservation, filtering/cancellation, fallback input, confirmations and source synchronization on PowerShell 5.1 and 7. Root/category and list-browser migration is complete.


### Menu migration (0.11.0)

The shared renderer now drives Windows root, Network and its categories (including Power, Storage, Printing and Group Policy), Registry and both tweak submenus, the Event Log picker, Startup/tasks, Cleanup, service actions, and Windows repair centre. Arrows/Enter select, Escape/Backspace return one level, and Home/End/PageUp/PageDown navigate. Existing numbered shortcuts remain stable even when a menu is reordered or paged (Health remains 9). The legacy Network A shortcut, event picker C/L, and service D/E shortcuts are also supported. Backspace edits a partially typed number before acting as Back.

Selection is retained on return from a submenu or action. Check/Change/Browse/Menu labels distinguish intent, and unavailable operations show a reason and cannot be selected. Action-time permission and availability checks remain in place. Interactive output is paused before redraw; text-input prompts retain B-to-cancel. Service actions now have a D details choice for the full account/path/dependency view. Repair-centre checks also display administrator, binary and OS requirements.

Optional item `Key` preserves shortcuts independently of row order; duplicate/reserved keys are rejected. `Description` adds context under the breadcrumb. `New-PcMenuItem` and `Read-PcCategoryMenu` adapt existing dispatch loops without executing actions inside the engine. `tests/Test-MenuMigration.ps1` exercises nested keyboard dispatch with mocked actions, plus the existing regression suites on PowerShell 5.1 and 7. Event, service, startup/task, discovery and health list browsers use this renderer as of 0.12.0. Disk Helper retains its separate renderer.


### List browser migration (0.12.0)

Events, Services, Startup/tasks, Health and Discovery use the shared renderer: arrows/Enter, Esc/Backspace/B, Home/End, PageUp/PageDown, F filtering and R refresh. Text input retains B-to-cancel. Filters search cached rows literally, and selection is preserved by identity when an item remains present. Numbers correspond to the displayed stable shortcuts and can have gaps when filtering. Unavailable diagnostic rows remain inspectable; only unavailable actions are blocked.

Events keep inline message previews (three lines for the selected event) and cached full-message/XML details. F filters the fetched candidates by header/message; C opens the advanced query for time, IDs, levels and provider. Refresh repeats the active query without changing the local filter. Older candidates outside the query cap remain excluded. Startup shows command and registry/folder source inline; C toggles review-only. Service filtering includes account and executable path. Health C explicitly runs live network checks; opening a finding does not repair anything.

Discovery now supports selection and full device details, F text filtering, R rescan of the same scope/ports/timeout, A all/responding, D MAC/probe view, M lookup, E export, and L scan/vendor notes. Rescan replaces the snapshot; cancellation retains explicitly partial results. CSV export still includes every collected scan row and partial-scan context, irrespective of the current filter. Vendor data and neighbor observations retain their previous limitations.

The menu engine accepts nonconflicting `Commands`, multiline details, expanded selected previews, and opaque `Data` carried back to callers. Shared detail screens accept Enter/Esc/Backspace/B. Disk Helper already follows arrows/Enter, Esc/Backspace and PageUp/PageDown and retains Ctrl+Enter for Explorer, sorting and F1 reports; its scanner/package is unchanged by this UI release.


### Disk Usage graduation (Windows 0.13.0 / helper 1.0.0)

The default disk tool is now the C# helper; its source remains under `experiments/disk-helper` to preserve build paths/history. The production release is `disk-helper-v1.0.0`. Package and executable hashes plus the version handshake remain mandatory. No scanner/accounting algorithm changed for this promotion. Compatibility scanning remains a separate menu choice, including on older or restricted systems.

Validated environments are x64 Windows with .NET Framework 4.8 and PowerShell 5.1/7. Older Windows/.NET and 32-bit hosts are not validated. Cancellation is cooperative; reconstruction can take time to finish. Intentional metadata exclusions and unknown allocations remain visible, and unreconciled allocation is not a missing-file total or measured NTFS overhead.

Graduation validation on the maintainer's PC: packaged-launcher/hash checks, native protocol/navigation, MFT regression and compact-cache suites passed on PowerShell 5.1 and 7. The elevated C: comparison reported 2,949,533 files, zero parse errors, 40.3 seconds to browsing, and exact hard-link fixture equality with the compatibility engine. An early cancellation check returned partial results in 172 ms. These are live-volume observations, not performance guarantees; reports remain local.


## Network connections (0.14.0)

Open **Network > Connectivity and adapters > Network connections** (item 5). This is a read-only, numeric endpoint snapshot similar to `ss -antp`: protocol, TCP state, local/remote IPv4 or bracketed IPv6 endpoint, PID, process name and executable path. Default view is all TCP states. L selects TCP listeners; E selects established TCP; A shows all states in the current protocol; T cycles TCP, UDP and both. F searches visible endpoint/process/path text literally, R recollects, Enter opens cached full details, and Esc/Backspace/B returns. C shows collection errors and limitations. Existing DHCP renewal follows the new check at item 6.

Connection rows use field-level colours for faster scanning: yellow ports, cyan binary names, magenta PIDs, gray executable paths, white/gray addresses, and state-specific green/yellow/cyan/gray. Red remains reserved for actual failures rather than ordinary socket metadata.

No DNS lookups, outbound probes, process termination or firewall changes are performed. UDP records are bound local sockets; their remote peer is shown as `*`, not invented connection state. A listener is not proof of reachability through the firewall. Process metadata is gathered once per snapshot; paths can be unavailable without elevation or for protected/exited processes. PID 0 is unattributed. If the current process started after the socket, attribution is withheld as possible PID reuse. Collection is not atomic, so all remaining PID mappings are best effort. Partial TCP/UDP/process collection failures remain visible under C rather than being presented as a complete empty list.

The Windows NetTCPIP cmdlets must be available; missing TCP support is marked unavailable in the menu. UDP collection failure preserves TCP results. PowerShell 5.1 and 7 fixtures cover IPv6 formatting, duplicate endpoint tuples, stale process IDs, unavailable metadata, partial collection and keyboard/filter/refresh navigation. Live loopback tests verified listening/established TCP and bound UDP with the correct owning PID on both shells.

Maintain `Network-Connections.ps1` and run `tests/Sync-NetworkConnections.ps1` to update the embedded launcher and Pages copies. Sources: [Microsoft Get-NetTCPConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection) and [Get-NetUDPEndpoint](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netudpendpoint).


### Navigation adjustment (0.14.1)

Root, section and action menus now use compact numbered selection (number/shortcut followed by Enter), showing every choice without paging or an arrow cursor. B/0 returns. Checks remain distinct from changes; unavailable actions retain their reasons and cannot run. Scrollable results such as Events, Connections, Services, Startup/tasks, Health and Discovery retain arrow navigation and filtering. Disk Usage retains its existing folder navigation. Selected result descriptions, including multiple preview lines, now use the same highlight colour as their heading. This supersedes the category-menu arrow behaviour introduced in 0.11.0.

The root heading is `WINDOWS TOOLKIT 0.20.0`; submenus retain `WINDOWS 0.20.0 | ...` breadcrumbs so the current location remains visible.

Data-heavy result browsers use a shared semantic palette: green for healthy/running/success, yellow for warnings and review states, red for confirmed errors, cyan for primary names and identifiers, magenta for numeric identifiers, white for primary values, gray for paths and secondary metadata, and dark gray for inactive or unavailable fields. Plain-text labels remain intact for filtering, redirected output and accessibility.

Scrollable browsers calculate page size from the current terminal height and the number of preview lines per item. Nine rows are reserved for headings, controls, wrapping and the selection prompt; a typical 29-row connection view therefore shows ten two-line entries. The shared default maximum is 100, so terminal height normally determines the page size; individual browsers can still request a smaller cap.

Within a page, Up/Down/Home/End repaint only the previously selected and newly selected rows through console cursor positioning, avoiding a full-screen clear on every key. Page changes, filtering, refreshes, terminal resizes and variable-height expanded previews redraw the complete frame. Redirected output and hosts without cursor control retain the full-redraw fallback.


### Compact hybrid menus (0.14.2)

Navigation and action menus accept both arrow selection plus Enter and existing number/letter shortcuts. All options are shown without paging, using one clipped line per option. Selection is retained on return; Esc/Backspace/B/0 goes back. Unsupported/redirected consoles retain line input. Change labels and unavailable-action checks remain in place. This replaces the number-only input introduced in 0.14.1; scrollable result lists remain unchanged.


### Visible numeric input (0.14.3)

Interactive shared menus display `Selection: _` beneath their controls. Typed digits appear immediately, Backspace edits them, and Enter submits the number. Enter with no digits activates the highlighted row. Esc cancels and returns. Each new prompt starts with an empty numeric buffer. This retains unambiguous selection of 1 versus 10/11/12; unsupported consoles continue to use visible Read-Host input.


### Toolkit build and browser refresh (0.15.0)

The Windows Toolkit now ships the maintained registry module through the generated launcher, uses automated site builds for synchronized downloadable copies, applies semantic field colours across data-heavy browsers, scales result pages to the available terminal height with a maximum of 100 entries, and repaints only changed rows during same-page cursor movement.


### Microsoft Sysinternals Live shortcuts (0.16.0)

The main menu includes a Microsoft Sysinternals Live section for Process Explorer, Process Monitor, Autoruns, TCPView, RAMMap, WinObj, VMMap, DebugView, ZoomIt and Disk2vhd. Each entry launches the architecture-appropriate executable directly from Microsoft's `\\live.sysinternals.com\tools` WebDAV share; ARM64 tools use its `ARM64` folder. The toolkit does not download, cache, redistribute, auto-elevate or auto-accept the EULA for these binaries.

The section can also open the complete tools share for command-line and specialist utilities. Sysmon, SDelete, PsExec and other service-changing, destructive or argument-sensitive programs are deliberately not one-click actions. Sysinternals Live requires internet and WebDAV access and may be blocked by corporate policy, proxy settings or the Windows WebClient service.


### Disk Usage modified dates and available space (Windows 0.17.0 / helper 1.1.0)

Disk Usage now displays a `MODIFIED` date for every visible file and directory and reports the containing volume's available space in the summary. Dates are retrieved only for the current page, preserving the compact MFT cache and large-scan memory profile; they reflect the live filesystem and can therefore be newer than the cached size scan. Available space uses the current user's `DriveInfo.AvailableFreeSpace` value.


### Faster and reconciled Disk Usage (Windows 0.18.0 / helper 1.2.0)

The MFT helper avoids full-path construction for ordinary single-name records, reducing the path phase and peak memory on large scans. Reports now reconcile attributable DATA allocation with allocated non-DATA NTFS attributes, resident DATA overlap, Windows reserved bytes and the volume storage reserve. Folder rows remain limited to attributable file allocation; filesystem metadata, reservations, unknown allocations and any live residual remain clearly separated at volume level.


### Live Disk Usage changes (Windows 0.19.0 / helper 1.3.0)

`L` monitors visible files and checks visible directory subtrees in a bounded round-robin cycle, prioritising the selected directory. Logical growth, shrinkage, replacement, deletion and unavailable paths are highlighted without reading file contents. `R` performs a clean same-engine rescan for new rows, refreshed sorting and totals, and current ON DISK directory allocation.


### Main-menu system summary (0.20.0)

The Windows root menu displays cached identity, group membership, network addresses, aggregate fixed-storage capacity, CPU, physical memory and Windows version/build information above its actions. Public IP precedes the potentially long private-address list so it remains visible in narrow terminals. Unavailable providers do not prevent the menu from opening.
