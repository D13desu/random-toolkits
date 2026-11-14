# Linux Toolkit v0.3.0

Portable Linux diagnostics and carefully confirmed maintenance actions in one Bash menu.

## Run

Review remote scripts before execution:

```bash
curl -fsSLo Linux-Toolkit.sh https://tools.d0xd.com/lin/
less Linux-Toolkit.sh
bash Linux-Toolkit.sh
```

The concise launcher is:

```bash
curl -fsSL https://tools.d0xd.com/lin/ | bash
```

Interactive input is read from `/dev/tty`, so the menu continues to work when the script is piped to Bash. Bash 4 or newer is required.

Interactive terminals use semantic colours for navigation, read-only checks, warnings, errors, and change actions. Set `NO_COLOR=1` or pass `--no-color` for plain output; redirected output is plain automatically.

## Checks

- Combined health summary with explicit thresholds and `OK`, `INFO`, `REVIEW`, `WARNING`, or `UNAVAILABLE` states.
- System identity, OS, kernel, architecture, uptime, and virtualization.
- CPU, memory, and the processes using the most CPU or memory.
- Friendly filesystem capacity, inode, swap, and disk summaries instead of command-shaped output.
- Primary connection, DNS, and listening-service summaries with cautious exposure labels.
- Failed-service counts and concise recent-log context, with basic non-systemd fallbacks.
- Firewall, SSH server, SELinux, and AppArmor status.
- Friendly update counts and package tables from existing APT, DNF/YUM, Zypper, Pacman, or APK metadata.
- Docker and Podman inventory when installed.
- Apache version, service state, syntax validation, enabled sites/modules, and bounded virtual-host details.
- Nginx version, service state, syntax validation, and safe operational directives without full configuration dumps.
- PostgreSQL readiness, clusters, selected effective settings, and database sizes when local authentication is already available.
- Expiry and subject summaries for certificates referenced by Apache, Nginx, or Let's Encrypt.
- Docker/Podman container state, health, published ports, disk use, Compose projects, networks, volumes, and selected-container details including environment values.

Friendly summaries retain access to the underlying evidence. Press `R` from a supported interactive screen or use:

```bash
bash Linux-Toolkit.sh --check storage --raw
bash Linux-Toolkit.sh --check network --raw
bash Linux-Toolkit.sh --check nginx --raw
bash Linux-Toolkit.sh --check containers --raw
```

Run a single read-only check without the menu:

```bash
bash Linux-Toolkit.sh --list
bash Linux-Toolkit.sh --check storage
```

## Maintenance safety

The maintenance menu can restart one validated, loaded systemd service or clear the detected package-manager download cache. Both operations:

- are labelled `CHANGES SYSTEM`;
- require an existing root session and never invoke `sudo`;
- describe their scope and default to cancellation;
- target only the selected service or detected package cache;
- verify that a restarted service is active afterward.

The toolkit does not change repositories, install packages, modify firewall or SSH settings, reboot, or enable services.

Application-service checks do not dump complete Nginx configuration, TLS private keys, PostgreSQL authentication files, or complete container inspect documents. Selected-container details display environment-variable values. PostgreSQL checks use existing local authentication and never request or store a password.

## Supported environments

The script uses capability detection rather than requiring a specific distribution. Ubuntu/Debian and Fedora/RHEL are the primary targets; openSUSE, Arch, and Alpine package tools are recognized. Features remain visible through warnings when an optional command or service manager is unavailable.

## Development

Maintain the files in `modules/`, then run `../tests/Sync-LinuxToolkit.ps1`. This assembles `Linux-Toolkit.sh` and copies it byte-for-byte to `index.html`. Run `bash ../tests/Test-LinuxToolkit.sh` on Linux before publishing.
