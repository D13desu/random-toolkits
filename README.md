# Random Toolkits

Personal system administration, investigation, and troubleshooting tools.

## Available tools

| Tool | Location | Requirements |
| --- | --- | --- |
| M365 Toolkit v0.3.7 | [win/m365](win/m365/README.md) | PowerShell 7.4+, Microsoft 365 permissions appropriate to the selected investigation |

## Run M365 Toolkit

In PowerShell 7.4+, once GitHub Pages and DNS are ready:

```powershell
irm https://tools.d0xd.com/win/m365/ | iex
```

The launcher downloads v0.3.7 from a pinned Git commit and verifies its SHA-256 checksum before execution. Missing modules are installed from PSGallery only after confirmation. On Windows, the toolkit and reports are stored under `%LOCALAPPDATA%/Random-Toolkits/m365/0.3.7/`. No administrator rights are required for installation. Review remote scripts before executing them.

While the custom domain is being configured, use:

```powershell
irm https://raw.githubusercontent.com/D13desu/random-toolkits/main/win/m365/Launch-M365.ps1 | iex
```

Download or clone this repository, then run from its root:

```powershell
pwsh -NoProfile -File ./win/m365/Install-Dependencies.ps1
pwsh -NoProfile -File ./win/m365/M365-Toolkit.ps1
```

On Windows, you can also run `win/m365/Start-M365-Toolkit.cmd` after installing dependencies. The dependency installer installs PowerShell modules for the current user. The toolkit authenticates interactively to Microsoft services.

The imported v0.3.7 toolkit investigates Microsoft 365 data without changing tenant state. It can write local reports and export quarantined email; handle these outputs as sensitive data. Generated `reports/` directories are excluded from Git. Review the tool's README for permissions and limitations.

## Layout and publication

Windows tools live under `win/<tool>/`. Additional platform directories can be added as tools are introduced.

GitHub Pages publishes `main` from the repository root, with `CNAME` specifying `tools.d0xd.com`. `.nojekyll` preserves static files without Jekyll processing. The `win/m365/index.html` file deliberately contains raw PowerShell, not HTML: Pages serves this directory index to `Invoke-RestMethod`. The extensionless `/win/m365` URL redirects to `/win/m365/`; the documented command uses the trailing slash directly.

Maintain `win/m365/Launch-M365.ps1` as the launcher source and copy it byte-for-byte to `win/m365/index.html` after edits. When upgrading the toolkit, update the pinned commit, version directory, and checksum together. The launcher runs the downloaded script as a local file so `$PSScriptRoot` and report paths work correctly.
