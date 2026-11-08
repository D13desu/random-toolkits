# Random Toolkits

Personal system administration, investigation, and troubleshooting tools.

Maintainers: see [Architecture and maintenance](ARCHITECTURE.md) for the source-of-truth map, extension recipes, build process, and GitHub Actions walkthrough.

## Toolkits

| Toolkit | Purpose | Requirements |
| --- | --- | --- |
| [Windows Toolkit](win/README.md) | Windows diagnostics, inventory, troubleshooting, and confirmed repairs | Windows PowerShell 5.0+; 5.1 or 7 recommended |
| [M365 Toolkit](m365/README.md) | Read-only Microsoft 365 investigation and reporting | PowerShell 7.4+ and the relevant Microsoft 365 permissions |

## Windows Toolkit

```powershell
irm https://tools.d0xd.com/win | iex
```

See the [Windows menu catalog](win/README.md) for the available tools and changes.

## M365 Toolkit

```powershell
irm https://tools.d0xd.com/m365/ | iex
```

The M365 launcher verifies the downloaded toolkit before running it. Review remote scripts before execution.
