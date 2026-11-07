# Windows Toolkit

Interactive Windows diagnostics, inventory, troubleshooting, and repair tools in one PowerShell menu.

## Run

```powershell
irm https://tools.d0xd.com/win | iex
```

Requires Windows PowerShell 5.0 or later; PowerShell 5.1 or 7 is recommended. The toolkit does not install modules or elevate itself.

## Controls

- Use arrow keys and Enter, or type a menu number.
- Use **B**, **Esc**, or **0** to go back.
- Lists may offer **F** to filter, **R** to refresh, and **N/P** to change pages.
- Unavailable tools remain visible with their missing requirement.
- Category menus keep labels concise; runtime text is shown only when PowerShell 7 or newer is required.

## Tools by menu

### 1. Computer and user details

- Current identity, SID, authentication type, administrator token, and group memberships.
- Manufacturer, model, domain/workgroup membership, CPU, memory, fixed storage, Windows version, architecture, last boot, and uptime.
- Internet-route private IPv4 and public IP summary.
- Main header device uptime, formatted as days/hours/minutes for quick restart context.
- Main header security summary with active Defender product/signature versions, or registered third-party antivirus names when Defender is passive.

### 2. Network

- Adapter, IP, gateway, DNS, and MAC overview.
- Gateway/host connectivity and TCP port checks.
- IPv4 device and TCP-port discovery with optional IEEE vendor lookup.
- Active TCP/UDP connections with PID, process, and executable path.
- DNS lookup, routing table, proxy, and firewall status.
- Active Directory membership, DC discovery, DNS, secure channel, time, SYSVOL/NETLOGON, Kerberos identity, DC service ports, LDAP RootDSE, FSMO roles, replication, selected DCDiag tests, recent DC events, site/subnet mapping, targeted user/computer diagnostics, SPN queries, and per-resolver AD DNS checks.
- Confirmed repairs: renew DHCP, flush DNS, repair member trust, and resync time.

### 3. Power and device health

- Battery and laptop detection, active power plan, sleep states, and sleep blockers.
- NIC power-saving settings, disk headroom, uptime, and restart indicators.
- Confirmed changes: select an existing power plan or disable supported NIC sleep settings.

### 4. Storage

- Disk Usage 1.3.0 with automatic MFT or native scanning, modified dates, available space, live refresh, and clean rescans.
- Compatibility disk scanner for drives, folders, and files sorted by size.

### 5. Printing

- Installed printers, queues, jobs, ports, drivers, spooler status, and printing events.
- Confirmed change: start or restart the Print Spooler service.

### 6. Group Policy

- Applied user and computer policy results.
- Group Policy event log browser.
- Confirmed changes: scoped user or computer policy refresh.

### 7. Event Logs

- Presets for common Windows, PowerShell, Defender, Update, Group Policy, and printing logs.
- Custom log selection, time/event/severity/provider/message filters, paging, full messages, and XML details.

### 8. Registry tweaks

- Inspect, apply, or reset classic Outlook PST/OST size limits.
- Inspect, apply, or reset the Remote Desktop redirection warning compatibility setting.
- Changes create a `.reg` undo file before writing.

### 9. Health dashboard

- Read-only summary of storage, servicing/restart indicators, services, crashes, update failures, power, NICs, network configuration, and AD membership.
- Optional live gateway, DNS, and member secure-channel checks.
- Findings link to the relevant diagnostic or repair menu.

### 10. Startup apps and scheduled tasks

- Startup entry inventory and executable-path assessment.
- Scheduled-task state, result, account, action, and trigger details.
- Task Scheduler events and shortcuts to Windows management interfaces.
- Inventory is read-only; it does not run, disable, or delete entries.

### 11. Services

- Local service state, startup mode, executable, account, description, and dependencies.
- Service Control Manager event lookup.
- Confirmed changes: start, stop, or restart a service. Stop and restart refuse active dependents.

### 12. Windows repair centre

- DISM CheckHealth and ScanHealth.
- SFC verify-only.
- Confirmed repairs: DISM RestoreHealth and SFC scannow.
- The toolkit does not reboot automatically or reset Windows Update components.

### 13. Microsoft Sysinternals Live

- Microsoft-hosted shortcuts for Process Explorer, Process Monitor, Autoruns, TCPView, RAMMap, WinObj, VMMap, DebugView, ZoomIt, and Disk2vhd.
- Tools run from Microsoft's network share; the toolkit does not download, install, or cache them.

### 14. Windows Security

- Microsoft Defender protection and detection history, plus registered antivirus providers.
- TPM, Secure Boot, VBS/Credential Guard, code integrity, BitLocker, audit policy, and firewall status.
- Security and Microsoft Defender event browsers.
- Security checks are read-only and do not reveal BitLocker recovery keys.

### 15. Windows Update

- Update service state, configured policy, Windows Update Agent history, installed hotfixes, and reboot indicators.
- Optional confirmed search for applicable updates using the configured update service.
- The toolkit does not accept licenses, download, install, hide, uninstall, or reboot for updates.

### 99. Toolkit cleanup

- Preview and remove recognized toolkit temporary packages, reports, test fixtures, and download caches.
- Cleanup is limited to known toolkit data and requires confirmation.

## Safety

- Actions that change the system are identified, require their normal Windows permissions, and ask for confirmation.
- The toolkit does not automatically join or leave a domain, reset the network stack, alter service startup types, or reboot Windows.
- The disk helper is downloaded only when selected and is verified against a pinned SHA-256 checksum.
- Sysinternals shortcuts run Microsoft-hosted executables and may show their own elevation or EULA prompts.
- Review remote scripts before execution.

## Local use

```powershell
.\win\Windows-Toolkit.ps1
.\win\Windows-Toolkit.ps1 -Check tcp -Target localhost -Port 443
.\win\Windows-Toolkit.ps1 -Check quick -Target example.com
```
