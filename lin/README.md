# Linux Toolkit v0.1.0

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

## Checks

- System identity, OS, kernel, architecture, uptime, and virtualization.
- CPU, memory, and the processes using the most CPU or memory.
- Filesystem capacity, inode usage, mounts, and block devices.
- Addresses, routes, DNS configuration, and listening TCP/UDP sockets.
- Failed systemd services and recent boot warnings, with basic non-systemd fallbacks.
- Firewall, SSH server, SELinux, and AppArmor status.
- Available updates from existing package metadata for APT, DNF/YUM, Zypper, Pacman, or APK.
- Docker and Podman inventory when installed.

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

## Supported environments

The script uses capability detection rather than requiring a specific distribution. Ubuntu/Debian and Fedora/RHEL are the primary targets; openSUSE, Arch, and Alpine package tools are recognized. Features remain visible through warnings when an optional command or service manager is unavailable.

## Development

Maintain the files in `modules/`, then run `../tests/Sync-LinuxToolkit.ps1`. This assembles `Linux-Toolkit.sh` and copies it byte-for-byte to `index.html`. Run `bash ../tests/Test-LinuxToolkit.sh` on Linux before publishing.
