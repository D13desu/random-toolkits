#!/usr/bin/env bash
# Random Toolkits | Linux Toolkit 0.1.1
# Generated from lin/modules/*.sh by tests/Sync-LinuxToolkit.ps1.
set -o pipefail
LIN_TOOLKIT_VERSION='0.1.1'

# BEGIN CORE
# Shared output, capability, and input helpers.

LIN_RESET=''
LIN_CYAN=''
LIN_GREEN=''
LIN_YELLOW=''
LIN_RED=''
LIN_DIM=''
LIN_BOLD=''

lin_setup_colors() {
    LIN_RESET=''
    LIN_CYAN=''
    LIN_GREEN=''
    LIN_YELLOW=''
    LIN_RED=''
    LIN_DIM=''
    LIN_BOLD=''
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        LIN_RESET=$'\033[0m'
        LIN_CYAN=$'\033[36m'
        LIN_GREEN=$'\033[32m'
        LIN_YELLOW=$'\033[33m'
        LIN_RED=$'\033[31m'
        LIN_DIM=$'\033[2m'
        LIN_BOLD=$'\033[1m'
    fi
}

lin_header() {
    local title=${1:-Main menu}
    printf '\n%s%sLINUX TOOLKIT %s%s%s | %s%s\n' "$LIN_BOLD" "$LIN_CYAN" "$LIN_TOOLKIT_VERSION" "$LIN_RESET" "$LIN_CYAN" "$title" "$LIN_RESET"
    printf '%sRead-only unless an action is explicitly labelled %sCHANGES SYSTEM%s%s.%s\n\n' "$LIN_DIM" "$LIN_YELLOW" "$LIN_RESET" "$LIN_DIM" "$LIN_RESET"
}

lin_has() { command -v "$1" >/dev/null 2>&1; }

lin_warn() { printf '%sWARNING: %s%s\n' "$LIN_YELLOW" "$*" "$LIN_RESET" >&2; }
lin_error() { printf '%sERROR: %s%s\n' "$LIN_RED" "$*" "$LIN_RESET" >&2; }
lin_section() { printf '\n%s%s%s%s\n' "$LIN_BOLD" "$LIN_CYAN" "$1" "$LIN_RESET"; }
lin_field() { printf '%s%s:%s %s\n' "$LIN_CYAN" "$1" "$LIN_RESET" "$2"; }
lin_menu_item() { printf '  %s[%s]%s %s\n' "${3:-$LIN_GREEN}" "$1" "$LIN_RESET" "$2"; }

lin_read() {
    local prompt=$1
    local value=''
    if [[ -r /dev/tty ]]; then
        IFS= read -r -p "$prompt" value </dev/tty || return 1
    else
        IFS= read -r -p "$prompt" value || return 1
    fi
    printf '%s' "$value"
}

lin_pause() {
    if [[ -r /dev/tty ]]; then
        IFS= read -r -p 'Press Enter to return' _ </dev/tty || true
    fi
}

lin_confirm() {
    local prompt=$1
    local answer
    answer=$(lin_read "$prompt [y/N] ") || return 1
    [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

lin_require_root() {
    if (( EUID != 0 )); then
        lin_error 'This action requires root. Re-run the downloaded local script as root after reviewing it.'
        return 1
    fi
}

lin_os_release_value() {
    local key=$1
    local value=''
    if [[ -r /etc/os-release ]]; then
        value=$(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); gsub(/^"|"$/, ""); print; exit}' /etc/os-release)
    fi
    printf '%s' "$value"
}

lin_package_manager() {
    local candidate
    for candidate in apt-get dnf yum zypper pacman apk; do
        if lin_has "$candidate"; then printf '%s' "$candidate"; return 0; fi
    done
    return 1
}
# END CORE

# BEGIN SYSTEM
lin_check_system() {
    lin_header 'System and user summary'
    lin_field 'Hostname' "$(hostname 2>/dev/null || printf 'Unavailable')"
    lin_field 'Operating system' "$(lin_os_release_value PRETTY_NAME)"
    lin_field 'Kernel' "$(uname -srmo 2>/dev/null || uname -a)"
    lin_field 'Architecture' "$(uname -m)"
    lin_field 'User' "$(id -un) (uid $(id -u))"
    lin_field 'Groups' "$(id -Gn 2>/dev/null || printf 'Unavailable')"
    lin_field 'Shell' "${SHELL:-Unknown}"
    lin_field 'Uptime' "$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'Unavailable')"
    if [[ -r /proc/uptime ]]; then lin_field 'Boot time' "$(uptime -s 2>/dev/null || printf 'Unavailable')"; fi
    if lin_has systemd-detect-virt; then lin_field 'Virtualization' "$(systemd-detect-virt 2>/dev/null || printf 'none detected')"; fi
}

lin_check_resources() {
    lin_header 'CPU, memory, and processes'
    if lin_has lscpu; then lscpu | awk -F: '/^(Architecture|CPU\(s\)|Model name|Thread|Core|Socket|Virtualization):/ {gsub(/^[ \t]+/, "", $2); printf "%-20s %s\n", $1 ":", $2}'; else uname -m; fi
    lin_section 'Memory'
    if lin_has free; then free -h; elif [[ -r /proc/meminfo ]]; then head -n 8 /proc/meminfo; else lin_warn 'Memory information unavailable.'; fi
    lin_section 'Highest CPU processes'
    ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 11 || ps aux | head -n 11
    lin_section 'Highest memory processes'
    ps -eo pid,user,comm,%cpu,%mem --sort=-%mem 2>/dev/null | head -n 11 || true
}
# END SYSTEM

# BEGIN STORAGE
lin_check_storage() {
    lin_header 'Storage, mounts, and inodes'
    lin_section 'Filesystems'
    df -hT 2>/dev/null || df -h
    lin_section 'Inode usage'
    df -i 2>/dev/null || lin_warn 'Inode reporting unavailable.'
    if lin_has lsblk; then
        lin_section 'Block devices'
        lsblk -o NAME,TYPE,FSTYPE,SIZE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS 2>/dev/null || lsblk
    fi
}
# END STORAGE

# BEGIN NETWORK
lin_check_network() {
    lin_header 'Network configuration'
    if lin_has ip; then
        lin_section 'Addresses'; ip -brief address
        lin_section 'Routes'; ip route show
    elif lin_has ifconfig; then
        ifconfig
    else
        lin_warn 'Neither ip nor ifconfig is available.'
    fi
    lin_section 'DNS configuration'
    if lin_has resolvectl; then resolvectl status 2>/dev/null || true; elif [[ -r /etc/resolv.conf ]]; then cat /etc/resolv.conf; else lin_warn 'DNS configuration unavailable.'; fi
    lin_section 'Listening sockets'
    if lin_has ss; then ss -lntup 2>/dev/null || ss -lntu; elif lin_has netstat; then netstat -lntup 2>/dev/null || netstat -lntu; else lin_warn 'Neither ss nor netstat is available.'; fi
}
# END NETWORK

# BEGIN SERVICES
lin_check_services() {
    lin_header 'Services and recent logs'
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        lin_section 'Failed services'
        systemctl --failed --no-pager --plain || true
        lin_section 'Recently failed service units'
        systemctl list-units --type=service --state=failed --no-pager --plain || true
    else
        lin_warn 'systemd is not the active service manager.'
        if lin_has rc-status; then rc-status --crashed 2>/dev/null || rc-status; fi
    fi
    lin_section 'Recent boot warnings/errors (latest 50)'
    if lin_has journalctl && [[ -d /run/systemd/system ]]; then
        journalctl -b -p warning -n 50 --no-pager 2>&1 || lin_warn 'Journal access was denied or unavailable.'
    elif [[ -r /var/log/syslog ]]; then tail -n 50 /var/log/syslog
    elif [[ -r /var/log/messages ]]; then tail -n 50 /var/log/messages
    else lin_warn 'No supported readable system log was found.'
    fi
}
# END SERVICES

# BEGIN SECURITY
lin_check_security() {
    lin_header 'Firewall and SSH inspection'
    lin_section 'Firewall'
    if lin_has ufw; then ufw status verbose 2>&1 || true
    elif lin_has firewall-cmd; then firewall-cmd --state 2>&1 || true; firewall-cmd --list-all 2>&1 || true
    elif lin_has nft; then nft list ruleset 2>&1 || lin_warn 'Root may be required to list the nftables ruleset.'
    elif lin_has iptables; then iptables -S 2>&1 || lin_warn 'Root may be required to list iptables rules.'
    else lin_warn 'No supported firewall frontend was found.'; fi

    lin_section 'SSH server configuration highlights'
    if lin_has sshd; then
        sshd -T 2>/dev/null | awk '$1 ~ /^(permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries|allowusers|allowgroups)$/' || lin_warn 'Effective sshd settings could not be read.'
    elif [[ -r /etc/ssh/sshd_config ]]; then
        awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|X11Forwarding|MaxAuthTries|AllowUsers|AllowGroups)[[:space:]]/ {print}' /etc/ssh/sshd_config
    else lin_warn 'OpenSSH server configuration was not found.'; fi

    lin_section 'Mandatory access control'
    if lin_has getenforce; then lin_field 'SELinux' "$(getenforce)"; fi
    if lin_has aa-status; then aa-status 2>&1 || true; fi
    if ! lin_has getenforce && ! lin_has aa-status; then lin_warn 'No SELinux/AppArmor status command was found.'; fi
}
# END SECURITY

# BEGIN UPDATES
lin_check_updates() {
    lin_header 'Available package updates'
    local manager
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
    lin_field 'Package manager' "$manager"
    printf 'This reads currently available update metadata; it does not refresh caches or install packages.\n\n'
    case $manager in
        apt-get) apt list --upgradable 2>/dev/null || true ;;
        dnf) dnf --cacheonly check-update || [[ $? -eq 100 ]] ;;
        yum) yum -C check-update || [[ $? -eq 100 ]] ;;
        zypper) zypper --non-interactive list-updates ;;
        pacman) pacman -Qu || true ;;
        apk) apk version -l '<' ;;
    esac
}
# END UPDATES

# BEGIN CONTAINERS
lin_check_containers() {
    lin_header 'Container inventory'
    local found=0
    if lin_has docker; then
        found=1; lin_section 'Docker'; docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}' 2>&1 || true; docker ps -a --no-trunc 2>&1 || true
    fi
    if lin_has podman; then
        found=1; lin_section 'Podman'; podman version 2>&1 || true; podman ps -a --no-trunc 2>&1 || true
    fi
    if (( ! found )); then lin_warn 'Docker and Podman are not installed.'; fi
}
# END CONTAINERS

# BEGIN MAINTENANCE
lin_restart_service() {
    lin_header 'Restart a service [CHANGES SYSTEM]'
    lin_require_root || return 1
    if ! lin_has systemctl || [[ ! -d /run/systemd/system ]]; then lin_error 'An active systemd installation is required.'; return 1; fi
    local service
    service=$(lin_read 'Service unit name (for example, sshd.service; B to cancel): ') || return 1
    [[ ${service^^} == B ]] && return 0
    if [[ ! $service =~ ^[A-Za-z0-9_.@:-]+(\.service)?$ ]]; then lin_error 'Invalid service unit name.'; return 1; fi
    [[ $service == *.service ]] || service="${service}.service"
    if [[ $(systemctl show "$service" -p LoadState --value 2>/dev/null) != loaded ]]; then lin_error "Service is not loaded: $service"; return 1; fi
    systemctl status "$service" --no-pager --lines=8 || true
    printf '\nThis interrupts the selected service and may disconnect users or applications.\n'
    lin_confirm "Restart only $service?" || { printf 'Cancelled.\n'; return 0; }
    systemctl restart "$service"
    systemctl is-active "$service" --quiet || { lin_error 'The service is not active after restart.'; systemctl status "$service" --no-pager --lines=20 || true; return 1; }
    printf '%sService restarted and verified active: %s%s\n' "$LIN_GREEN" "$service" "$LIN_RESET"
}

lin_clean_package_cache() {
    lin_header 'Clear package cache [CHANGES SYSTEM]'
    lin_require_root || return 1
    local manager
    manager=$(lin_package_manager) || { lin_error 'No supported package manager was found.'; return 1; }
    lin_field 'Package manager' "$manager"
    printf 'This removes cached package downloads. Installed packages and repository configuration are not removed.\n'
    lin_confirm "Clear the $manager package cache?" || { printf 'Cancelled.\n'; return 0; }
    case $manager in
        apt-get) apt-get clean ;;
        dnf) dnf clean packages ;;
        yum) yum clean packages ;;
        zypper) zypper --non-interactive clean --all ;;
        pacman) pacman -Sc --noconfirm ;;
        apk) rm -f /var/cache/apk/*.apk ;;
    esac
    printf '%sPackage cache cleanup completed.%s\n' "$LIN_GREEN" "$LIN_RESET"
}

lin_maintenance_menu() {
    while true; do
        lin_header 'Maintenance [CHANGES SYSTEM]'
        lin_menu_item '1' 'Restart one loaded systemd service [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item '2' 'Clear the detected package-manager cache [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 'B' 'Back' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_restart_service; lin_pause ;;
            2) lin_clean_package_cache; lin_pause ;;
            B|0) return 0 ;;
            *) lin_warn 'Choose 1, 2, or B.' ;;
        esac
    done
}
# END MAINTENANCE

# BEGIN MENU
lin_list_checks() {
    cat <<'EOF'
system       System and user summary
resources    CPU, memory, and resource-heavy processes
storage      Filesystems, mounts, block devices, and inodes
network      Addresses, routes, DNS, and listening sockets
services     Failed services and recent boot warnings
security     Firewall, SSH, and mandatory-access-control status
updates      Available package updates using existing metadata
containers   Docker and Podman inventory
EOF
}

lin_run_check() {
    case ${1:-} in
        system) lin_check_system ;;
        resources) lin_check_resources ;;
        storage) lin_check_storage ;;
        network) lin_check_network ;;
        services) lin_check_services ;;
        security) lin_check_security ;;
        updates) lin_check_updates ;;
        containers) lin_check_containers ;;
        *) lin_error "Unknown check: ${1:-<blank>}"; printf 'Available checks:\n'; lin_list_checks; return 2 ;;
    esac
}

lin_main_menu() {
    while true; do
        lin_header 'Main menu'
        lin_menu_item '1' 'System and user summary'
        lin_menu_item '2' 'CPU, memory, and heavy processes'
        lin_menu_item '3' 'Storage, mounts, and inode usage'
        lin_menu_item '4' 'Network configuration and listening sockets'
        lin_menu_item '5' 'Failed services and recent logs'
        lin_menu_item '6' 'Firewall and SSH inspection'
        lin_menu_item '7' 'Available package updates'
        lin_menu_item '8' 'Docker and Podman inventory'
        lin_menu_item '9' 'Maintenance actions [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 'Q' 'Quit' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_check_system; lin_pause ;;
            2) lin_check_resources; lin_pause ;;
            3) lin_check_storage; lin_pause ;;
            4) lin_check_network; lin_pause ;;
            5) lin_check_services; lin_pause ;;
            6) lin_check_security; lin_pause ;;
            7) lin_check_updates; lin_pause ;;
            8) lin_check_containers; lin_pause ;;
            9) lin_maintenance_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-9 or Q.' ;;
        esac
    done
}

lin_usage() {
    cat <<EOF
Linux Toolkit $LIN_TOOLKIT_VERSION

Usage:
  Linux-Toolkit.sh                 Open the interactive menu
  Linux-Toolkit.sh --list          List command-line checks
  Linux-Toolkit.sh --check ID      Run one read-only check
  Linux-Toolkit.sh --no-color      Disable ANSI colours
  Linux-Toolkit.sh --help          Show this help

Maintenance actions are interactive only, require root, and never invoke sudo.
EOF
}

lin_main() {
    lin_setup_colors
    case ${1:-} in
        --help|-h) lin_usage ;;
        --list) lin_list_checks ;;
        --check) [[ -n ${2:-} ]] || { lin_error '--check requires an ID.'; return 2; }; lin_run_check "$2" ;;
        --no-color) NO_COLOR=1; lin_setup_colors; lin_main_menu ;;
        '') lin_main_menu ;;
        *) lin_error "Unknown argument: $1"; lin_usage; return 2 ;;
    esac
}
# END MENU

if [[ -z ${BASH_SOURCE[0]:-} || ${BASH_SOURCE[0]} == "$0" ]]; then lin_main "$@"; fi
