# Random Toolkits

Personal system administration, investigation, and troubleshooting tools.

## Available tools

| Tool | Location | Requirements |
| --- | --- | --- |
| M365 Toolkit v0.3.7 | [win/m365](win/m365/README.md) | PowerShell 7.4+, Microsoft 365 permissions appropriate to the selected investigation |

## Run M365 Toolkit

Download or clone this repository, then run from its root:

```powershell
pwsh -NoProfile -File ./win/m365/Install-Dependencies.ps1
pwsh -NoProfile -File ./win/m365/M365-Toolkit.ps1
```

On Windows, you can also run `win/m365/Start-M365-Toolkit.cmd` after installing dependencies. The dependency installer installs PowerShell modules for the current user. The toolkit authenticates interactively to Microsoft services.

The imported v0.3.7 toolkit investigates Microsoft 365 data without changing tenant state. It can write local reports and export quarantined email; handle these outputs as sensitive data. Generated `reports/` directories are excluded from Git. Review the tool's README for permissions and limitations.

## Layout and publication

Windows tools live under `win/<tool>/`. Additional platform directories can be added as tools are introduced.

This initial import preserves the supplied toolkit source. GitHub Pages and the planned `https://tools.d0xd.com/win/m365` launcher are not configured yet. Run the toolkit from local files: it relies on its script directory for report output.
