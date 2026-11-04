# M365 Toolkit v0.3.7

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
Run `Start-M365-Toolkit.cmd` on Windows, or `pwsh -File ./M365-Toolkit.ps1` on PowerShell 7.4+.

## v0.3.7 Identity Protection

Main menu R: risky users, risk detections and travel-related risk findings. Uses Microsoft Graph v1.0 Identity Protection endpoints and requests IdentityRiskyUser.Read.All and IdentityRiskEvent.Read.All delegated scopes. Requires appropriate Microsoft Entra ID Protection licensing and roles. No automatic geographical distance/speed calculation: travel results are Microsoft-generated detections. Tenant state is not changed. Risk findings are not proof of compromise.
