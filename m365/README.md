# M365 Toolkit v0.4.0

Read-only Microsoft 365 investigation toolkit, based on the supplied v0.3.4.

## Added
- [M] Mail flow: message trace V2 (up to 90-day lookback, 10-day query chunks), delivery events, transport rules, connectors and domains.
- [Q] Security and quarantine: search, inspect, preview, export EML locally, and inspect policies.
- Unified email investigation combining trace and quarantine metadata.
- JSON and CSV exports in `reports/`. EML exports in `reports/quarantine/`.

## Cautions / limitations
- Requires appropriate Exchange Online / Defender permissions and supported ExchangeOnlineManagement module.
- The quarantine EML export expects an `Eml` Base64 payload; tenant/module variations may require adjustment.
- Message trace result sets reaching 5,000 per 10-day interval may be incomplete; narrow filters.
- Quarantine search is capped at 20,000 raw results, with 60 shown in interactive selector.
- Subject filtering is client-side and is not exhaustive when server result caps are hit.
- Exported EML files are untrusted and may contain malicious attachments. No release/delete actions are provided.
- **Not validated against a live Microsoft 365 tenant or PowerShell parser in this environment.** Test in a nonproduction tenant before operational use.

## Run
In PowerShell 7.4+:

```powershell
irm https://tools.d0xd.com/m365/ | iex
```

Run `Start-M365-Toolkit.cmd` on Windows, or `pwsh -File ./M365-Toolkit.ps1` on PowerShell 7.4+.

## Build and publication

Maintain `Launch-M365.ps1`, `M365-Toolkit.ps1`, and `Menu-Engine.ps1` as the web launcher, toolkit, and interactive-menu sources. Run `../tests/Sync-M365.ps1` after local edits, or `../tests/Sync-Site.ps1` to assemble every published endpoint. The build parses the menu engine and generated toolkit, injects the toolkit's SHA-256 into the launcher, and copies the launcher byte-for-byte to `m365/index.html`. GitHub Actions performs that build before deploying `main`; the launcher downloads the matching toolkit from the same Pages artifact and refuses to execute it if verification fails.

## v0.4.0 Interactive menus

Navigation menus now support arrow keys plus Enter, number or letter shortcuts, visible multi-digit input, Esc/Backspace to return, semantic highlighting, and incremental repainting of only the changed rows. Plain `Read-Host` selection remains available when raw console input or cursor positioning is unavailable. Authentication, UPN, date, filter, export, and confirmation prompts remain explicit data-entry fields.

Maintain `Menu-Engine.ps1`; `../tests/Sync-M365.ps1` embeds it into the downloadable toolkit before calculating the launcher checksum.

## v0.3.7 Identity Protection

Main menu R: risky users, risk detections and travel-related risk findings. Uses Microsoft Graph v1.0 Identity Protection endpoints and requests IdentityRiskyUser.Read.All and IdentityRiskEvent.Read.All delegated scopes. Requires appropriate Microsoft Entra ID Protection licensing and roles. No automatic geographical distance/speed calculation: travel results are Microsoft-generated detections. Tenant state is not changed. Risk findings are not proof of compromise.

## Microsoft 365 health dashboard

Main menu **H** shows the connected tenant's Microsoft-reported service health across the services returned by Graph (for example Exchange Online, Teams, SharePoint, OneDrive and other Microsoft 365 workloads). It summarizes overall health, lists per-service status, and lets you inspect active incidents/advisories, impact, and Microsoft updates. Use **R** to refresh or **E** to export the timestamped snapshot as JSON to `reports/`.

Requires the delegated Microsoft Graph `ServiceHealth.Read.All` permission with administrator consent and a supported service-health role (for example Service Support Administrator). Existing Graph sessions must disconnect and reconnect through **C** to request the new scope. Authorization errors are reported without changing tenant settings.

This is a point-in-time tenant service-health report, not a public global outage feed, connectivity test, security posture score, or SLA measurement. Missing/unknown service states and failed requests produce an unknown/incomplete overall result, never an all-clear. Successfully fetched services remain visible when the incident request fails. Resolved issues are excluded; unknown status values remain visible. A refresh replaces the prior snapshot.

## Global/public Microsoft 365 status

Main menu **G** (also available inside **H**) reads Microsoft's public RSS feed at <https://status.cloud.microsoft/api/feed/mac> without Graph authentication or tenant permissions. It shows Microsoft-published status, entry publication time, description, source URL and retrieval timestamp, with **R** to refresh and **E** to export JSON.

This feed backs the Microsoft 365 business public status card. It carries selected public announcements, especially widespread incidents or issues preventing access to the admin-center Service health dashboard; it is **not a complete global, per-service outage feed**. An `Available` notice or an empty feed does not prove every Microsoft 365 service is healthy. Entries may include resolved updates. Use **H** for the connected tenant's service health and incidents. Fetch/parse failures are shown explicitly, and refresh never retains old entries after failure.
