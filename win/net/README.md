# Windows Network Toolkit 0.1.0

Read-only, self-contained network diagnostics. No modules are installed and no elevation is requested. Probes send network traffic to the selected host and local gateways; settings are not changed.

```powershell
irm https://tools.d0xd.com/win/net/ | iex
```

Requires Windows and PowerShell 5.0 or later. Tested with Windows PowerShell 5.1 and PowerShell 7; 5.0 uses the same compatible syntax/APIs but has not been runtime-tested. PowerShell 5.1 is recommended for legacy machines. This does not change the M365 toolkit's PowerShell 7.4+ requirement.

If an old Windows PowerShell session cannot negotiate HTTPS, enable TLS 1.2 for that session before downloading (OS TLS/certificate support is still required):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
irm https://tools.d0xd.com/win/net/ | iex
```

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

Each menu entry displays its minimum PowerShell version. Missing commands, incompatible versions and any future administrator requirements are labeled `UNAVAILABLE` and blocked before execution. Runtime access errors return to the menu. No AD module, packet capture, firewall changes, resets, DNS flushes or dependency installation are included in this initial version.

## Local and noninteractive use

```powershell
.\win\net\Network-Toolkit.ps1
.\win\net\Network-Toolkit.ps1 -Check tcp -Target localhost -Port 443
.\win\net\Network-Toolkit.ps1 -Check quick -Target example.com
```

Noninteractive checks return objects (route.exe/netsh.exe also emit native text). A failed connectivity probe returns `Status=WARN`; it does not set a failing process exit code. Use returned status fields when automating.

## Maintenance and validation

Add checks to `Get-NetworkChecks`, supplying minimum PS version, required commands, elevation requirement and an action. Keep the launcher itself parseable on PowerShell 5.0; future newer-language implementations must live in separate files loaded only after compatibility checks.

`Network-Toolkit.ps1` is the source. Copy it byte-for-byte to `index.html` after edits. GitHub Pages serves this raw script through the directory index; `/win/net` redirects to `/win/net/`. There are no extra script downloads and no reliance on `$PSScriptRoot` in the launcher.

Run the regression checks in both shells:

```powershell
powershell.exe -NoProfile -File tests/Test-NetworkToolkit.ps1
pwsh.exe -NoProfile -File tests/Test-NetworkToolkit.ps1
```

Tests cover parsing, source/endpoint parity, invalid input, compatibility gates, open/closed loopback TCP ports, adapter enumeration, localhost DNS, and IEX startup/exit. They require no tenant, elevation, package installation or public network probe. Historical Windows installations still need real-device validation.
