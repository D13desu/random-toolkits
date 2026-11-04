# Windows Toolkit 0.5.0

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

The root menu is **1 Network**, **2 Power and device health**, **3 Storage**. M365 remains separate at `/win/m365`. The older `/win/net` endpoint is an alias for the unified Windows menu. Under **Network**:

| Main menu | Checks | Repairs |
| --- | --- | --- |
| 1 Overview and quick diagnosis | Adapter/IP overview, combined quick check | None |
| 2 Connectivity and adapters | Gateway/host connectivity, TCP ports, adapter overview | Renew selected adapter DHCP lease |
| 3 DNS | DNS lookup | Flush DNS cache |
| 4 Active Directory and time | Membership, discovery/site, AD DNS, secure channel, time, shares | Repair member trust, resync local time |
| 5 Routing and proxy | Routes, WinHTTP/user proxy | None |
| 6 Firewall | Firewall profiles | None |

`0` returns from a submenu or exits the main menu. Unavailable actions remain visible with the reason underneath. Repair entries are yellow and marked `CHANGES SYSTEM`; minimum PowerShell and administrator requirements remain visible. The old `A` shortcut still opens Active Directory. Noninteractive check IDs are unchanged.

## Power and device health

- Laptop/portable detection uses firmware chassis codes, supplemented by battery presence. Battery-only detection is marked ambiguous (for example, UPS-equipped desktops).
- Shows battery charge/status, active classic power plan and available plans. Flags laptops not using the standard High performance GUID; Balanced/custom plans are not automatically considered faulty. Windows power-mode overlays are separate. Some hardware exposes only Balanced; the toolkit does not create unsupported plans or disable Modern Standby.
- Displays NIC AllowComputerToTurnOffDevice, SelectiveSuspend and DeviceSleepOnDisconnect where exposed by the driver. Errors are reported as unavailable.
- Reports supported sleep states, AC/battery sleep/display settings, power requests, last wake reason, uptime, fixed-drive free space (warns below 10%) and two common pending-reboot registry markers. These indicators are not exhaustive diagnoses.

Confirmed administrator repairs can select an existing power plan (previous plan shown for rollback) or disable supported sleep settings on one selected physical NIC. NIC changes preserve Wake-on-LAN and other offloads and pass `NoRestart`; a later manual NIC restart/reboot may be required. Values are read back and failures remain warnings. Keeping a NIC awake does not prevent Windows system sleep. Increased performance/less power saving can increase battery drain, heat and fan noise.

Power check IDs: `power`, `nic-power`, `sleep`, `wake`, `quality`. Storage check ID: `disk` (opens interactive explorer). Power repair IDs: `set-power-plan`, `nic-awake`.

## Storage

Choose **Storage > Open disk usage explorer**. It lists drive total/used/free space and scans a chosen drive or folder. Drill into folders ordered by size, navigate up, page through results and rescan. It never deletes files. See [Disk Usage documentation](../disk/README.md) for keys and limitations: totals are logical file sizes, links/cloud placeholders are skipped, and inaccessible trees are marked partial.

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

`win/net/Network-Toolkit.ps1` remains the source to preserve local script paths. Copy it byte-for-byte to both `win/index.html` and `win/net/index.html` after edits. GitHub Pages serves these raw scripts through directory indexes, including redirects from `/win` and `/win/net`. The Windows launcher does not rely on `$PSScriptRoot`; only the disk tool requires an additional HTTPS download. Update its pinned commit and SHA-256 together when releasing disk changes.

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
```

Tests cover parsing, source/endpoint parity, invalid input, compatibility gates, open/closed loopback TCP ports, adapter enumeration, localhost DNS, and IEX startup/exit. They require no tenant, elevation, package installation or public network probe. Historical Windows installations still need real-device validation.

AD regression tests use simulated CIM/domain responses and native commands. They cover all machine roles, unknown/access-denied detection, unavailable commands, secure-channel gating, healthy/broken trust, DC input validation, read-only native arguments, localized exit errors, partial DNS failures, independent share checks and menu recovery. Tested on PowerShell 5.1 and 7; **not yet validated against a live AD domain**.

Repair tests mock every modifying command: no real cache flush, renewal, resync or trust repair is executed during testing. They verify privilege/role gates, cancellation, WhatIf, exact command arguments, static-adapter rejection, DHCP result handling, credential flow, skipping healthy trust and post-repair verification. Real repair outcomes still require validation in a suitable test environment.

Menu tests verify that every action remains reachable, every category returns to the main menu, DNS repair cancellation preserves the yes/no prompt, and unavailable AD repairs are blocked before collecting inputs. Add or reorganize topics through `Get-NetworkCategories`; diagnostics and repairs continue to use their existing dispatchers and checks.

Power tests simulate laptop/desktop firmware, localized plan output, missing plans, confirmation/cancellation, and driver support. All changes are mocked. Read-only power/health provider calls were checked on a Windows desktop; real laptop and NIC modification outcomes still need device validation. Disk tests use isolated temporary files, including a junction loop. Windows PowerShell 5.0 remains targeted but not runtime-tested.
