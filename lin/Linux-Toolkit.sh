#!/usr/bin/env bash
# Random Toolkits | Linux Toolkit 0.5.0
# Generated from lin/modules/*.sh by tests/Sync-LinuxToolkit.ps1.
set -o pipefail
LIN_TOOLKIT_VERSION='0.5.0'

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

lin_status_color() {
    case $1 in
        OK) printf '%s' "$LIN_GREEN" ;;
        INFO|UNAVAILABLE) printf '%s' "$LIN_CYAN" ;;
        REVIEW) printf '%s' "$LIN_YELLOW" ;;
        WARNING) printf '%s' "$LIN_RED" ;;
        *) printf '%s' "$LIN_RESET" ;;
    esac
}

lin_status_row() {
    local status=$1 title=$2 detail=$3 color
    color=$(lin_status_color "$status")
    printf '%s%-11s%s %-24s %s\n' "$color" "$status" "$LIN_RESET" "$title" "$detail"
}

lin_usage_status() {
    local percent=${1:-0}
    if (( percent >= 90 )); then printf 'WARNING'
    elif (( percent >= 80 )); then printf 'REVIEW'
    else printf 'OK'
    fi
}

lin_truncate() {
    local text=${1//$'\n'/ } width=${2:-60}
    if (( ${#text} > width )); then printf '%s...' "${text:0:width-3}"; else printf '%s' "$text"; fi
}

lin_raw_hint() {
    printf '\n%sRaw evidence:%s bash Linux-Toolkit.sh --check %s --raw\n' "$LIN_DIM" "$LIN_RESET" "$1"
}

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
lin_storage_root_percent() {
    df -P / 2>/dev/null | awk 'NR == 2 {gsub(/%/, "", $5); print $5; exit}'
}

lin_check_storage() {
    lin_header 'Storage summary'
    local rows overall='OK' filesystem type size used available percent mount status number
    rows=$(df -hPT 2>/dev/null) || { lin_warn 'Filesystem capacity is unavailable.'; return 0; }

    printf '%-24s %-8s %8s %8s %6s  %s\n' 'Mount' 'Type' 'Used' 'Free' 'Use' 'Status'
    printf '%-24s %-8s %8s %8s %6s  %s\n' '------------------------' '--------' '--------' '--------' '------' '-------'
    while read -r filesystem type size used available percent mount; do
        [[ $percent == Use% ]] && continue
        number=${percent%%%}
        [[ $number =~ ^[0-9]+$ ]] || continue
        status=$(lin_usage_status "$number")
        [[ $status == WARNING ]] && overall='WARNING'
        [[ $status == REVIEW && $overall == OK ]] && overall='REVIEW'
        printf '%-24s %-8s %8s %8s %6s  %s%s%s\n' "$(lin_truncate "$mount" 24)" "$type" "$used" "$available" "$percent" "$(lin_status_color "$status")" "$status" "$LIN_RESET"
    done <<<"$rows"

    lin_section 'Other capacity indicators'
    local inode_percent='Unavailable' inode_status='UNAVAILABLE' swap='Unavailable' disks='Unavailable'
    inode_percent=$(df -Pi / 2>/dev/null | awk 'NR == 2 {print $5; exit}') || true
    if [[ ${inode_percent%%%} =~ ^[0-9]+$ ]]; then inode_status=$(lin_usage_status "${inode_percent%%%}"); fi
    if lin_has free; then swap=$(free -h | awk '/^Swap:/ {print $3 " of " $2 " used"}'); fi
    if lin_has lsblk; then disks=$(lsblk -dn -o TYPE 2>/dev/null | awk '$1 == "disk" {count++} END {print count+0}'); fi
    lin_status_row "$inode_status" 'Root inode usage' "$inode_percent"
    lin_status_row 'INFO' 'Swap' "$swap"
    lin_status_row 'INFO' 'Physical disks' "$disks"

    printf '\n'
    case $overall in
        WARNING) printf '%sOverall status: WARNING%s — at least one filesystem is 90%% full or higher.\n' "$LIN_RED" "$LIN_RESET" ;;
        REVIEW) printf '%sOverall status: REVIEW%s — at least one filesystem is 80%% full or higher.\n' "$LIN_YELLOW" "$LIN_RESET" ;;
        OK) printf '%sOverall status: OK%s — all reported filesystems are below 80%%.\n' "$LIN_GREEN" "$LIN_RESET" ;;
    esac
    lin_raw_hint storage
}

lin_raw_storage() {
    lin_header 'Storage raw evidence'
    lin_section 'df -hT'; df -hT 2>&1 || df -h
    lin_section 'df -i'; df -i 2>&1 || true
    if lin_has lsblk; then lin_section 'lsblk'; lsblk -o NAME,TYPE,FSTYPE,SIZE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS 2>&1 || lsblk; fi
}
# END STORAGE

# BEGIN NETWORK
lin_listener_rows() {
    lin_has ss || return 1
    local proto state recv send local_endpoint peer process address exposure status
    while read -r proto state recv send local_endpoint peer process; do
        [[ -n $local_endpoint ]] || continue
        address=${local_endpoint%:*}
        case $address in
            127.*|'[::1]'|::1|localhost) exposure='Local only'; status='OK' ;;
            0.0.0.0|'[::]'|::|'*') exposure='All interfaces'; status='REVIEW' ;;
            *) exposure='Specific address'; status='REVIEW' ;;
        esac
        process=${process:-Unavailable}
        process=${process#users:((}
        process=${process%%,*}
        process=${process//\"/}
        printf '%s\t%s\t%s\t%s\t%s\n' "$proto" "$local_endpoint" "$process" "$exposure" "$status"
    done < <(ss -H -lntup 2>/dev/null || ss -H -lntu 2>/dev/null)
}

lin_public_listener_count() {
    lin_listener_rows 2>/dev/null | awk -F'\t' '$4 != "Local only" {count++} END {print count+0}'
}

lin_check_network() {
    lin_header 'Network summary'
    local interface='Unavailable' gateway='Unavailable' address='Unavailable' state='Unavailable' speed='Unavailable'
    if lin_has ip; then
        local default_route
        default_route=$(ip route show default 2>/dev/null | head -n 1)
        interface=$(awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}' <<<"$default_route")
        gateway=$(awk '{for(i=1;i<=NF;i++) if($i=="via"){print $(i+1);exit}}' <<<"$default_route")
        [[ -n $interface ]] || interface='Unavailable'
        [[ -n $gateway ]] || gateway='Direct / unavailable'
        if [[ $interface != Unavailable ]]; then
            address=$(ip -o -4 address show dev "$interface" scope global 2>/dev/null | awk 'NR == 1 {print $4}')
            [[ -n $address ]] || address='No global IPv4 address'
            [[ -r /sys/class/net/$interface/operstate ]] && state=$(<"/sys/class/net/$interface/operstate")
            if [[ -r /sys/class/net/$interface/speed ]]; then speed="$(<"/sys/class/net/$interface/speed") Mbps"; fi
        fi
    fi

    lin_section 'Primary connection'
    lin_field 'Interface' "$interface"
    lin_field 'IPv4 address' "$address"
    lin_field 'Gateway' "$gateway"
    lin_field 'Link state' "$state"
    lin_field 'Link speed' "$speed"
    local dns
    dns=$(awk '/^nameserver[ \t]+/ {printf "%s%s", separator, $2; separator=", "}' /etc/resolv.conf 2>/dev/null)
    lin_field 'DNS servers' "${dns:-Unavailable}"

    lin_section 'Listening services'
    local rows local_count public_count
    rows=$(lin_listener_rows 2>/dev/null) || rows=''
    local_count=$(awk -F'\t' '$4 == "Local only" {count++} END {print count+0}' <<<"$rows")
    public_count=$(awk -F'\t' '$4 != "Local only" && NF {count++} END {print count+0}' <<<"$rows")
    lin_status_row 'OK' 'Local-only listeners' "$local_count"
    if (( public_count )); then lin_status_row 'REVIEW' 'Non-local listeners' "$public_count"; else lin_status_row 'OK' 'Non-local listeners' '0'; fi

    if [[ -n $rows ]]; then
        printf '\n%-6s %-28s %-18s %-18s %s\n' 'Proto' 'Endpoint' 'Process' 'Exposure' 'Status'
        while IFS=$'\t' read -r proto local_endpoint process exposure status; do
            printf '%-6s %-28s %-18s %-18s %s%s%s\n' "$proto" "$(lin_truncate "$local_endpoint" 28)" "$(lin_truncate "$process" 18)" "$exposure" "$(lin_status_color "$status")" "$status" "$LIN_RESET"
        done <<<"$rows"
    else
        lin_warn 'Listening socket details are unavailable; install iproute2/ss for this view.'
    fi
    printf '\nREVIEW means the socket is bound beyond localhost; it does not prove firewall reachability.\n'
    lin_raw_hint network
}

lin_raw_network() {
    lin_header 'Network raw evidence'
    if lin_has ip; then lin_section 'ip -brief address'; ip -brief address; lin_section 'ip route'; ip route show; fi
    lin_section '/etc/resolv.conf'; cat /etc/resolv.conf 2>&1 || true
    if lin_has resolvectl; then lin_section 'resolvectl status'; resolvectl status 2>&1 || true; fi
    if lin_has ss; then lin_section 'ss -lntup'; ss -lntup 2>&1 || ss -lntu; fi
}
# END NETWORK

# BEGIN SERVICES
lin_failed_service_count() {
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        systemctl --failed --type=service --no-legend --plain 2>/dev/null | awk 'NF {count++} END {print count+0}'
    else
        printf '0'
    fi
}

lin_check_services() {
    lin_header 'Services and logs summary'
    if ! lin_has systemctl || [[ ! -d /run/systemd/system ]]; then
        lin_status_row 'UNAVAILABLE' 'Service manager' 'systemd is not active'
        if lin_has rc-status; then lin_field 'OpenRC crashed services' "$(rc-status --crashed 2>/dev/null | wc -l | tr -d ' ')"; fi
        lin_raw_hint services
        return 0
    fi

    local failed count
    failed=$(systemctl --failed --type=service --no-legend --plain 2>/dev/null | sed 's/^[●*[:space:]]*//')
    count=$(awk 'NF {count++} END {print count+0}' <<<"$failed")
    if (( count )); then lin_status_row 'WARNING' 'Failed services' "$count unit(s)"; else lin_status_row 'OK' 'Failed services' 'None'; fi

    if [[ -n $failed ]]; then
        printf '\n%-34s %-10s %-10s %s\n' 'Unit' 'Active' 'Substate' 'Description'
        while read -r unit load active sub description; do
            [[ -n $unit ]] || continue
            printf '%-34s %-10s %-10s %s\n' "$(lin_truncate "$unit" 34)" "$active" "$sub" "$(lin_truncate "$description" 50)"
        done <<<"$failed"
    fi

    lin_section 'Recent boot warnings/errors'
    local journal journal_count
    journal=$(journalctl -b -p warning -n 50 --no-pager -o short-iso 2>/dev/null | grep -v '^-- No entries --$' || true)
    journal_count=$(awk 'NF {count++} END {print count+0}' <<<"$journal")
    if (( journal_count )); then lin_status_row 'REVIEW' 'Recent entries' "$journal_count (latest 5 shown)"; else lin_status_row 'OK' 'Recent entries' 'None visible'; fi
    if [[ -n $journal ]]; then tail -n 5 <<<"$journal" | while IFS= read -r line; do printf '  %s\n' "$(lin_truncate "$line" 110)"; done; fi
    printf '\nHistorical log entries are context, not proof that a problem is still active.\n'
    lin_raw_hint services
}

lin_raw_services() {
    lin_header 'Services and logs raw evidence'
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        lin_section 'systemctl --failed'; systemctl --failed --no-pager --plain 2>&1 || true
        lin_section 'journalctl warnings/errors'; journalctl -b -p warning -n 50 --no-pager 2>&1 || true
    elif [[ -r /var/log/syslog ]]; then tail -n 50 /var/log/syslog
    elif [[ -r /var/log/messages ]]; then tail -n 50 /var/log/messages
    else lin_warn 'No supported service manager or readable system log was found.'; fi
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
lin_collect_updates() {
    local manager=${1:-}
    case $manager in
        apt-get)
            apt list --upgradable 2>/dev/null | awk 'NR > 1 && $1 ~ /\// {split($1,n,"/"); old=$NF; gsub(/^\[upgradable from: |\]$/, "", old); print n[1] "\t" $2 "\tfrom " old}' ;;
        dnf)
            dnf --cacheonly check-update 2>/dev/null | awk '$1 ~ /\./ && NF >= 3 {print $1 "\t" $2 "\t" $3}' ;;
        yum)
            yum -C check-update 2>/dev/null | awk '$1 ~ /\./ && NF >= 3 {print $1 "\t" $2 "\t" $3}' ;;
        zypper)
            zypper --non-interactive list-updates 2>/dev/null | awk -F'|' 'NF >= 6 && $1 ~ /v/ {for(i=2;i<=6;i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $3 "\t" $5 "\t" $2}' ;;
        pacman)
            pacman -Qu 2>/dev/null | awk 'NF >= 4 {print $1 "\t" $4 "\tfrom " $2}' ;;
        apk)
            apk version -l '<' 2>/dev/null | awk 'NF {print $1 "\tavailable\tupgrade"}' ;;
    esac
    return 0
}

lin_update_count() {
    local manager rows
    manager=$(lin_package_manager) || { printf '0'; return 0; }
    rows=$(lin_collect_updates "$manager")
    awk 'NF {count++} END {print count+0}' <<<"$rows"
}

lin_check_updates() {
    lin_header 'Available updates summary'
    local manager rows count shown=0 name version source
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
    rows=$(lin_collect_updates "$manager")
    count=$(awk 'NF {count++} END {print count+0}' <<<"$rows")
    lin_field 'Package manager' "$manager"
    if (( count )); then lin_status_row 'REVIEW' 'Available updates' "$count package(s)"; else lin_status_row 'OK' 'Available updates' 'None in current metadata'; fi
    printf 'Package metadata is not refreshed and no packages are installed.\n'

    if [[ -n $rows ]]; then
        printf '\n%-36s %-24s %s\n' 'Package' 'Available version' 'Context'
        while IFS=$'\t' read -r name version source; do
            (( shown+=1 ))
            (( shown > 20 )) && break
            printf '%-36s %-24s %s\n' "$(lin_truncate "$name" 36)" "$(lin_truncate "$version" 24)" "$(lin_truncate "$source" 35)"
        done <<<"$rows"
        (( count > 20 )) && printf '... and %d more package(s).\n' "$((count-20))"
    fi
    lin_raw_hint updates
}

lin_raw_updates() {
    lin_header 'Available updates raw evidence'
    local manager
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
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
lin_container_engine() {
    if lin_has docker; then printf 'docker'; return 0; fi
    if lin_has podman; then printf 'podman'; return 0; fi
    return 1
}

lin_container_summary() {
    local engine rows running=0 stopped=0 unhealthy=0 restarting=0 name image state ports status
    engine=$(lin_container_engine) || { printf 'UNAVAILABLE\tDocker/Podman not installed'; return 0; }
    $engine info >/dev/null 2>&1 || { printf 'UNAVAILABLE\t%s installed; service unavailable or access denied' "$engine"; return 0; }
    rows=$(lin_container_rows "$engine") || { printf 'UNAVAILABLE\t%s inventory unavailable' "$engine"; return 0; }
    while IFS=$'\t' read -r name image state ports; do
        [[ -n $name ]] || continue
        if [[ $state == Up* ]]; then ((running+=1)); else ((stopped+=1)); fi
        [[ $state == *unhealthy* ]] && ((unhealthy+=1))
        [[ $state == Restarting* ]] && ((restarting+=1))
    done <<<"$rows"
    if (( unhealthy || restarting )); then status='WARNING'; elif (( stopped )); then status='REVIEW'; else status='OK'; fi
    printf '%s\t%s | %s running, %s stopped, %s unhealthy, %s restarting' "$status" "$engine" "$running" "$stopped" "$unhealthy" "$restarting"
}

lin_container_rows() {
    local engine=$1
    $engine ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
}

lin_check_containers() {
    lin_header 'Container summary'
    local engine rows running=0 stopped=0 unhealthy=0 restarting=0 total=0 name image state ports status
    local summary detail
    summary=$(lin_container_summary); IFS=$'\t' read -r status detail <<<"$summary"
    if [[ $status == UNAVAILABLE ]]; then lin_status_row "$status" 'Container engine' "$detail"; return 0; fi
    engine=$(lin_container_engine)
    lin_field 'Engine' "$engine"
    rows=$(lin_container_rows "$engine") || { lin_status_row 'UNAVAILABLE' 'Engine service' 'Installed but unavailable or access denied'; return 0; }
    while IFS=$'\t' read -r name image state ports; do
        [[ -n $name ]] || continue; ((total+=1))
        if [[ $state == Up* ]]; then ((running+=1)); else ((stopped+=1)); fi
        [[ $state == *unhealthy* ]] && ((unhealthy+=1))
        [[ $state == Restarting* ]] && ((restarting+=1))
    done <<<"$rows"
    lin_status_row "$status" 'Containers' "$running running | $stopped stopped | $unhealthy unhealthy | $restarting restarting"
    lin_field 'Networks' "$($engine network ls -q 2>/dev/null | awk 'NF {count++} END {print count+0}')"
    lin_field 'Volumes' "$($engine volume ls -q 2>/dev/null | awk 'NF {count++} END {print count+0}')"

    if [[ -n $rows ]]; then
        printf '\n%-24s %-28s %-26s %s\n' 'Name' 'Image' 'State / health' 'Published ports'
        while IFS=$'\t' read -r name image state ports; do
            printf '%-24s %-28s %-26s %s\n' "$(lin_truncate "$name" 24)" "$(lin_truncate "$image" 28)" "$(lin_truncate "$state" 26)" "$(lin_truncate "$ports" 45)"
        done <<<"$rows"
    fi

    lin_section 'Disk use'
    $engine system df 2>/dev/null | head -n 12 || lin_warn 'Container disk-use data is unavailable.'
    if [[ $engine == docker ]] && docker compose version >/dev/null 2>&1; then lin_section 'Compose projects'; docker compose ls 2>/dev/null || true; fi
    lin_raw_hint containers
}

lin_container_details() {
    local engine target exists env_lines
    engine=$(lin_container_engine) || { lin_warn 'Docker and Podman are not installed.'; return 0; }
    target=$(lin_read 'Container name or ID (B to cancel): ') || return 0
    [[ ${target^^} == B ]] && return 0
    [[ $target =~ ^[A-Za-z0-9_.-]+$ ]] || { lin_error 'Invalid container name or ID.'; return 1; }
    exists=$($engine ps -a --format '{{.ID}} {{.Names}}' 2>/dev/null | awk -v target="$target" '$1 == target || $2 == target || index($1,target) == 1 {print $1; exit}')
    [[ -n $exists ]] || { lin_error 'Container was not found.'; return 1; }
    lin_header "Container details: $target"
    $engine inspect --format $'Name:\t{{.Name}}\nImage:\t{{.Config.Image}}\nState:\t{{.State.Status}}\nHealth:\t{{if .State.Health}}{{.State.Health.Status}}{{else}}Not configured{{end}}\nRestart policy:\t{{.HostConfig.RestartPolicy.Name}}\nStarted:\t{{.State.StartedAt}}' "$exists" 2>/dev/null || true
    lin_section 'Published ports'; $engine port "$exists" 2>/dev/null || printf '  None.\n'
    lin_section 'Mounts'; $engine inspect --format '{{range .Mounts}}{{println .Type .Source "->" .Destination}}{{end}}' "$exists" 2>/dev/null || true
    lin_section 'Environment variables'
    env_lines=$($engine inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$exists" 2>/dev/null)
    if [[ -n $env_lines ]]; then printf '%s\n' "$env_lines" | sed 's/^/  /'; else printf '  None visible.\n'; fi
}

lin_raw_containers() {
    lin_header 'Container bounded raw evidence'
    local engine
    engine=$(lin_container_engine) || { lin_warn 'Docker and Podman are not installed.'; return 0; }
    lin_section "$engine ps -a"; $engine ps -a --no-trunc 2>&1 || true
    lin_section "$engine system df"; $engine system df 2>&1 || true
    lin_section 'Networks'; $engine network ls 2>&1 || true
    lin_section 'Volumes'; $engine volume ls 2>&1 || true
    printf '\nComplete inspect output is intentionally excluded; use selected-container details to view environment values.\n'
}
# END CONTAINERS

# BEGIN APPLICATIONSERVICES
lin_service_running() {
    local name
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        for name in "$@"; do systemctl is-active "$name" --quiet 2>/dev/null && return 0; done
    fi
    for name in "$@"; do pgrep -x "$name" >/dev/null 2>&1 && return 0; done
    return 1
}

lin_apache_command() {
    local command
    for command in apache2ctl apachectl httpd; do lin_has "$command" && { printf '%s' "$command"; return 0; }; done
    return 1
}

lin_apache_summary() {
    local command version config status detail
    command=$(lin_apache_command) || { printf 'UNAVAILABLE\tNot installed'; return 0; }
    version=$($command -v 2>/dev/null | awk -F': ' '/Server version/ {print $2; exit}')
    config=$($command configtest 2>&1); status='OK'
    if [[ $? -ne 0 ]]; then status='WARNING'; detail="config test failed"
    elif ! lin_service_running apache2 httpd; then status='REVIEW'; detail='config syntax OK; service not detected running'
    else detail='running; config syntax OK'; fi
    printf '%s\t%s%s' "$status" "${version:-Apache}" " | $detail"
}

lin_check_apache() {
    lin_header 'Apache summary'
    local command summary status detail sites=0 modules=0 vhosts
    command=$(lin_apache_command) || { lin_status_row 'UNAVAILABLE' 'Apache' 'Not installed'; return 0; }
    summary=$(lin_apache_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'Apache' "$detail"
    [[ -d /etc/apache2/sites-enabled ]] && sites=$(find /etc/apache2/sites-enabled -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | awk 'NF {count++} END {print count+0}')
    modules=$($command -M 2>/dev/null | awk '/_module/ {count++} END {print count+0}')
    lin_field 'Enabled sites' "$sites"
    lin_field 'Loaded modules' "$modules"
    lin_section 'Virtual hosts (bounded)'
    vhosts=$($command -S 2>&1 || true)
    if [[ -n $vhosts ]]; then printf '%s\n' "$vhosts" | grep -E '(^VirtualHost|namevhost|default server|port [0-9]+)' | head -n 15 | while IFS= read -r line; do printf '  %s\n' "$(lin_truncate "$line" 110)"; done
    else lin_warn 'Virtual-host information is unavailable.'; fi
    lin_raw_hint apache
}

lin_raw_apache() {
    lin_header 'Apache raw evidence'
    local command
    command=$(lin_apache_command) || { lin_warn 'Apache is not installed.'; return 0; }
    lin_section 'Version'; $command -v 2>&1 || true
    lin_section 'Configuration test'; $command configtest 2>&1 || true
    lin_section 'Virtual hosts'; $command -S 2>&1 || true
    lin_section 'Loaded modules'; $command -M 2>&1 || true
}

lin_nginx_summary() {
    local version config status detail
    lin_has nginx || { printf 'UNAVAILABLE\tNot installed'; return 0; }
    version=$(nginx -v 2>&1 | sed 's|.*/||')
    config=$(nginx -t 2>&1); status='OK'
    if [[ $? -ne 0 ]]; then
        if grep -qiE 'permission denied|operation not permitted' <<<"$config"; then status='UNAVAILABLE'; detail='config test needs additional access'
        else status='WARNING'; detail='config test failed'; fi
    elif ! lin_service_running nginx; then status='REVIEW'; detail='config syntax OK; service not detected running'
    else detail='running; config syntax OK'; fi
    printf '%s\tnginx %s | %s' "$status" "${version:-unknown}" "$detail"
}

lin_nginx_config_files() {
    [[ -d /etc/nginx ]] || return 0
    find /etc/nginx \( -type f -o -type l \) \( -name '*.conf' -o -path '*/sites-enabled/*' \) 2>/dev/null | sort -u
}

lin_check_nginx() {
    lin_header 'Nginx summary'
    local summary status detail files highlights count
    summary=$(lin_nginx_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'Nginx' "$detail"
    [[ $detail == 'Not installed' ]] && return 0
    files=$(lin_nginx_config_files); count=$(awk 'NF {count++} END {print count+0}' <<<"$files")
    lin_field 'Configuration files' "$count readable file(s)"
    lin_section 'Operational directives (values only; secrets excluded)'
    highlights=''
    while IFS= read -r file; do
        [[ -r $file ]] || continue
        while IFS= read -r line; do highlights+="$(lin_truncate "$line" 105)"$'\n'; done < <(grep -Eh '^[[:space:]]*(listen|server_name|root|proxy_pass|upstream|ssl_certificate)[[:space:]]' "$file" 2>/dev/null | grep -Ev 'ssl_certificate_key|password|secret|token')
    done <<<"$files"
    if [[ -n $highlights ]]; then printf '%s' "$highlights" | sed '/^[[:space:]]*$/d' | sort -u | head -n 25 | sed 's/^/  /'; else lin_warn 'No readable operational directives were found.'; fi
    lin_raw_hint nginx
}

lin_raw_nginx() {
    lin_header 'Nginx bounded raw evidence'
    lin_has nginx || { lin_warn 'Nginx is not installed.'; return 0; }
    lin_section 'Version and build'; nginx -V 2>&1 || true
    lin_section 'Configuration test'; nginx -t 2>&1 || true
    lin_section 'Configuration files'; lin_nginx_config_files
    printf '\nThe complete nginx -T dump is intentionally excluded because configuration may contain credentials.\n'
}

lin_postgres_summary() {
    local version ready status detail
    lin_has psql || { printf 'UNAVAILABLE\tClient not installed'; return 0; }
    version=$(psql --version 2>/dev/null | sed 's/^psql (PostgreSQL) //')
    if lin_has pg_isready; then
        ready=$(pg_isready -t 3 2>&1)
        if [[ $? -eq 0 ]]; then status='OK'; detail="$ready"
        else status='REVIEW'; detail="$ready"; fi
    elif lin_service_running postgresql postgres; then status='INFO'; detail='service detected; pg_isready unavailable'
    else status='REVIEW'; detail='client installed; server readiness unavailable'; fi
    printf '%s\tPostgreSQL %s | %s' "$status" "${version:-unknown}" "$detail"
}

lin_postgres_settings() {
    PGCONNECT_TIMEOUT=3 psql -X -w -A -t -F $'\t' -c "SELECT name, setting || COALESCE(unit, '') FROM pg_settings WHERE name IN ('config_file','hba_file','port','listen_addresses','ssl','max_connections','shared_buffers','work_mem','log_destination','logging_collector') ORDER BY name" 2>/dev/null
}

lin_check_postgres() {
    lin_header 'PostgreSQL summary'
    local summary status detail settings clusters databases
    summary=$(lin_postgres_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'PostgreSQL' "$detail"
    [[ $detail == 'Client not installed' ]] && return 0
    if lin_has pg_lsclusters; then
        clusters=$(pg_lsclusters --no-header 2>/dev/null || true)
        lin_section 'Detected clusters'
        if [[ -n $clusters ]]; then printf '%s\n' "$clusters" | head -n 10 | sed 's/^/  /'; else printf '  None detected.\n'; fi
    fi
    settings=$(lin_postgres_settings || true)
    lin_section 'Effective settings'
    if [[ -n $settings ]]; then
        while IFS=$'\t' read -r name value; do lin_field "$name" "$value"; done <<<"$settings"
        databases=$(PGCONNECT_TIMEOUT=3 psql -X -w -A -t -F $'\t' -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datallowconn ORDER BY pg_database_size(datname) DESC LIMIT 10" 2>/dev/null || true)
        if [[ -n $databases ]]; then lin_section 'Largest databases'; while IFS=$'\t' read -r name size; do printf '  %-36s %s\n' "$(lin_truncate "$name" 36)" "$size"; done <<<"$databases"; fi
    else
        lin_status_row 'UNAVAILABLE' 'Authenticated settings' 'Local connection unavailable; no password was requested'
    fi
    lin_raw_hint postgres
}

lin_raw_postgres() {
    lin_header 'PostgreSQL bounded raw evidence'
    lin_has psql || { lin_warn 'PostgreSQL client is not installed.'; return 0; }
    lin_section 'Client version'; psql --version
    if lin_has pg_isready; then lin_section 'Readiness'; pg_isready -t 3 2>&1 || true; fi
    if lin_has pg_lsclusters; then lin_section 'Clusters'; pg_lsclusters 2>&1 || true; fi
    lin_section 'Safe pg_settings selection'; lin_postgres_settings || lin_warn 'Authentication is required; no password was requested.'
}

lin_referenced_certificates() {
    local directory
    for directory in /etc/nginx /etc/apache2 /etc/httpd; do
        [[ -d $directory ]] || continue
        grep -RhsE '^[[:space:]]*(ssl_certificate|SSLCertificateFile)[[:space:]]+' "$directory" 2>/dev/null |
            grep -Ev 'ssl_certificate_key' |
            sed -E 's/^[[:space:]]*(ssl_certificate|SSLCertificateFile)[[:space:]]+//; s/[;[:space:]]+$//; s/^"|"$//'
    done
    if [[ -d /etc/letsencrypt/live ]]; then find /etc/letsencrypt/live -maxdepth 2 -name fullchain.pem 2>/dev/null; fi
}

lin_tls_days_status() {
    local days=${1:-99999}
    if (( days < 0 )); then printf 'WARNING'
    elif (( days <= 30 )); then printf 'REVIEW'
    else printf 'OK'; fi
}

lin_check_tls() {
    lin_header 'Referenced TLS certificates'
    lin_has openssl || { lin_status_row 'UNAVAILABLE' 'OpenSSL' 'Not installed'; return 0; }
    local paths path end_text end_epoch now days status subject count=0
    paths=$(lin_referenced_certificates | sed '/^[[:space:]]*$/d' | sort -u)
    [[ -n $paths ]] || { lin_status_row 'UNAVAILABLE' 'Certificates' 'No referenced certificate files were found'; return 0; }
    printf '%-8s %8s %-42s %s\n' 'Status' 'Days' 'Certificate' 'Subject'
    while IFS= read -r path; do
        [[ $path == /* && -r $path ]] || { lin_status_row 'UNAVAILABLE' "$(lin_truncate "$path" 24)" 'Unreadable or variable-based path'; continue; }
        end_text=$(openssl x509 -in "$path" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
        subject=$(openssl x509 -in "$path" -noout -subject 2>/dev/null | sed 's/^subject=//')
        end_epoch=$(date -d "$end_text" +%s 2>/dev/null || printf '')
        if [[ -n $end_epoch ]]; then now=$(date +%s); days=$(( (end_epoch-now)/86400 )); status=$(lin_tls_days_status "$days")
        else days='?'; status='UNAVAILABLE'; fi
        printf '%s%-8s%s %8s %-42s %s\n' "$(lin_status_color "$status")" "$status" "$LIN_RESET" "$days" "$(lin_truncate "$path" 42)" "$(lin_truncate "$subject" 45)"
        ((count+=1))
    done <<<"$paths"
    lin_field 'Certificates inspected' "$count"
}

lin_check_applications() {
    lin_header 'Application services summary'
    local summary status detail certificates
    summary=$(lin_apache_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Apache' "$detail"
    summary=$(lin_nginx_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Nginx' "$detail"
    summary=$(lin_postgres_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'PostgreSQL' "$detail"
    certificates=$(lin_referenced_certificates | sed '/^[[:space:]]*$/d' | sort -u | awk 'NF {count++} END {print count+0}')
    if (( certificates )); then lin_status_row 'INFO' 'TLS certificates' "$certificates referenced file(s)"; else lin_status_row 'UNAVAILABLE' 'TLS certificates' 'No references found'; fi
    summary=$(lin_container_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Containers' "$detail"
}

lin_application_menu() {
    while true; do
        lin_header 'Application services'
        lin_menu_item '1' 'Combined application summary'
        lin_menu_item '2' 'Apache settings and virtual hosts'
        lin_menu_item '3' 'Nginx settings and server directives'
        lin_menu_item '4' 'PostgreSQL readiness and settings'
        lin_menu_item '5' 'Referenced TLS certificate expiry'
        lin_menu_item 'B' 'Back' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_show_check applications ;;
            2) lin_show_check apache ;;
            3) lin_show_check nginx ;;
            4) lin_show_check postgres ;;
            5) lin_show_check tls ;;
            B|0) return 0 ;;
            *) lin_warn 'Choose 1-5 or B.' ;;
        esac
    done
}
# END APPLICATIONSERVICES

# BEGIN SYSINTERNALS
lin_tool_available() {
    local tool
    for tool in "$@"; do
        if lin_has "$tool"; then printf '%s' "$tool"; return 0; fi
    done
    return 1
}

lin_sysinternals_tool_row() {
    local label=$1 official=$2 fallback=$3 found status detail
    if [[ -n $official ]]; then
        found=$(lin_tool_available $official 2>/dev/null || true)
        if [[ -n $found ]]; then
            status='OK'; detail="$found installed"
        else
            found=$(lin_tool_available $fallback 2>/dev/null || true)
            if [[ -n $found ]]; then status='INFO'; detail="Microsoft port not installed; native fallback is $found"; else status='UNAVAILABLE'; detail='No supported tool detected'; fi
        fi
    else
        found=$(lin_tool_available $fallback 2>/dev/null || true)
        if [[ -n $found ]]; then status='OK'; detail="Native Linux view uses $found"; else status='UNAVAILABLE'; detail='No supported native tool detected'; fi
    fi
    lin_status_row "$status" "$label" "$detail"
}

lin_check_sysinternals() {
    lin_header 'Sysinternals-style Linux toolkit'
    printf 'Microsoft provides individual Linux ports, not a complete Linux Sysinternals Suite.\n'
    lin_sysinternals_tool_row 'Process Explorer' '' 'ps top htop pidstat'
    lin_sysinternals_tool_row 'TCPView' '' 'ss lsof netstat'
    lin_sysinternals_tool_row 'Handle' '' 'lsof fuser'
    lin_sysinternals_tool_row 'Process Monitor' 'procmon' 'strace bpftrace perf'
    lin_sysinternals_tool_row 'Autoruns' '' 'systemctl crontab'
    lin_sysinternals_tool_row 'VMMap / RAMMap' '' 'pmap smem ps'
    lin_sysinternals_tool_row 'ProcDump' 'procdump' 'coredumpctl gcore'
    lin_sysinternals_tool_row 'Sysmon' 'sysmon sysmonforlinux' 'auditctl journalctl'
    lin_section 'Official Microsoft ports'
    printf '  ProcDump: https://github.com/microsoft/procdump-for-linux\n'
    printf '  ProcMon:  https://github.com/microsoft/ProcMon-for-Linux\n'
    printf '  Sysmon:   https://github.com/microsoft/SysmonForLinux\n'
    printf '\nUse the Sysinternals-style menu for live read-only views. Tracing and dump capture are not started automatically.\n'
}

lin_check_processes() {
    lin_header 'Process Explorer-style summary'
    lin_field 'Processes' "$(ps -e --no-headers 2>/dev/null | awk 'END {print NR+0}')"
    lin_field 'Threads' "$(ps -eLf --no-headers 2>/dev/null | awk 'END {print NR+0}')"
    lin_section 'Highest CPU use'
    ps -eo pid,user,stat,pcpu,pmem,rss,etime,comm --sort=-pcpu 2>/dev/null | awk 'NR <= 16' || lin_warn 'Process data is unavailable.'
    lin_section 'Highest memory use'
    ps -eo pid,user,stat,pcpu,pmem,rss,etime,comm --sort=-rss 2>/dev/null | awk 'NR <= 16' || true
    lin_raw_hint processes
}

lin_check_connections() {
    lin_header 'TCPView-style connection summary'
    local tool
    tool=$(lin_tool_available ss lsof netstat 2>/dev/null || true)
    [[ -n $tool ]] || { lin_status_row 'UNAVAILABLE' 'Network sockets' 'Install iproute2 (ss) or lsof'; return 0; }
    lin_field 'Source' "$tool"
    if [[ $tool == ss ]]; then
        lin_field 'TCP connections' "$(ss -Htan 2>/dev/null | awk 'END {print NR+0}')"
        lin_field 'UDP sockets' "$(ss -Huan 2>/dev/null | awk 'END {print NR+0}')"
        lin_section 'Listening endpoints'
        ss -H -lntup 2>/dev/null | awk 'NR <= 30' || true
    elif [[ $tool == lsof ]]; then
        lsof -nP -i 2>/dev/null | awk 'NR <= 31' || true
    else
        netstat -tulpen 2>/dev/null | awk 'NR <= 31' || true
    fi
    printf '\nProcess names may be hidden when the current user cannot inspect their owners.\n'
    lin_raw_hint connections
}

lin_check_handles() {
    lin_header 'Handle-style open-file summary'
    if lin_has lsof; then
        lin_field 'Open entries visible' "$(lsof -nP 2>/dev/null | awk 'END {print NR > 0 ? NR-1 : 0}')"
        lin_section 'Processes with the most visible open entries'
        lsof -nP 2>/dev/null | awk 'NR > 1 {count[$1 FS $2]++} END {for (key in count) print count[key], key}' | sort -nr | awk 'NR <= 20 {printf "%-8s %s\n", $1, substr($0,index($0,$2))}' || true
    else
        lin_status_row 'INFO' 'lsof' 'Not installed; selected-PID details can inspect /proc/PID/fd'
    fi
    lin_raw_hint handles
}

lin_check_tracing() {
    lin_header 'Process Monitor-style tracing readiness'
    lin_sysinternals_tool_row 'Microsoft ProcMon' 'procmon' 'strace'
    lin_sysinternals_tool_row 'System-wide tracing' '' 'bpftrace perf'
    lin_sysinternals_tool_row 'Audit framework' '' 'auditctl ausearch'
    printf '\nNo trace is started by this check. Tracing may require root and can collect sensitive process data.\n'
}

lin_check_autoruns() {
    lin_header 'Autoruns-style startup summary'
    if lin_has systemctl; then
        lin_section 'Enabled system services'
        systemctl list-unit-files --type=service --state=enabled --no-legend --no-pager 2>/dev/null | awk 'NR <= 35' || true
        lin_section 'Enabled system timers'
        systemctl list-unit-files --type=timer --state=enabled --no-legend --no-pager 2>/dev/null | awk 'NR <= 20' || true
    else
        lin_status_row 'INFO' 'systemd' 'Not detected'
    fi
    lin_section 'Cron locations'
    local path found=0
    for path in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        if [[ -e $path ]]; then printf '  %s\n' "$path"; found=1; fi
    done
    (( found )) || printf '  No standard system cron locations found.\n'
    if lin_has crontab; then lin_section 'Current user crontab'; crontab -l 2>/dev/null || printf '  No current-user crontab or access unavailable.\n'; fi
    lin_raw_hint autoruns
}

lin_check_memorymaps() {
    lin_header 'VMMap / RAMMap-style memory summary'
    lin_section 'Largest resident process sets'
    ps -eo pid,user,rss,vsz,pmem,comm --sort=-rss 2>/dev/null | awk 'NR <= 21' || lin_warn 'Process memory data is unavailable.'
    local rollups=0
    [[ -r /proc/self/smaps_rollup ]] && rollups=1
    lin_field 'Detailed maps' "$([[ $rollups == 1 ]] && printf '/proc/PID/smaps_rollup available' || printf 'use pmap when installed')"
    printf '\nChoose selected-PID details from the interactive menu for mappings and open files.\n'
    lin_raw_hint memorymaps
}

lin_check_dumps() {
    lin_header 'ProcDump-style capture readiness'
    lin_sysinternals_tool_row 'Microsoft ProcDump' 'procdump' 'coredumpctl gcore'
    if lin_has coredumpctl; then lin_section 'Recent recorded dumps'; coredumpctl list --no-pager 2>/dev/null | awk 'NR <= 20' || true; fi
    printf '\nThis check never captures a dump. Process dumps may contain credentials and other in-memory data.\n'
}

lin_pid_details() {
    local pid cmd
    pid=$(lin_read 'PID (B to cancel): ') || return 0
    [[ ${pid^^} == B ]] && return 0
    [[ $pid =~ ^[1-9][0-9]*$ && -d /proc/$pid ]] || { lin_error 'PID was not found.'; return 1; }
    lin_header "Process details: $pid"
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
    lin_field 'Command line' "${cmd:-Unavailable}"
    lin_section 'Status'; awk '/^(Name|State|Pid|PPid|Uid|Gid|Threads|VmPeak|VmSize|VmRSS|RssAnon|RssFile|voluntary_ctxt_switches|nonvoluntary_ctxt_switches):/' "/proc/$pid/status" 2>/dev/null || true
    lin_section 'Memory map summary'
    if lin_has pmap; then pmap -x "$pid" 2>/dev/null | awk 'NR <= 35' || true
    elif [[ -r /proc/$pid/smaps_rollup ]]; then cat "/proc/$pid/smaps_rollup" 2>/dev/null
    else printf '  Detailed map unavailable to the current user.\n'; fi
    lin_section 'Open file descriptors'
    if lin_has lsof; then lsof -nP -p "$pid" 2>/dev/null | awk 'NR <= 40' || true
    else ls -l "/proc/$pid/fd" 2>/dev/null | awk 'NR <= 40' || true; fi
}

lin_raw_sysinternals() {
    lin_header 'Sysinternals-style raw evidence'
    lin_section 'Processes'; ps -ef 2>&1
    lin_section 'Sockets'; if lin_has ss; then ss -tunap 2>&1; elif lin_has netstat; then netstat -tunap 2>&1; else printf 'No socket inventory tool detected.\n'; fi
}

lin_raw_processes() { lin_header 'Process raw evidence'; ps -eF 2>&1; }
lin_raw_connections() { lin_header 'Connection raw evidence'; if lin_has ss; then ss -tunap 2>&1; elif lin_has lsof; then lsof -nP -i 2>&1; else netstat -tunap 2>&1; fi; }
lin_raw_handles() { lin_header 'Open-file raw evidence'; if lin_has lsof; then lsof -nP 2>&1; else printf 'lsof is not installed.\n'; fi; }
lin_raw_autoruns() { lin_check_autoruns; }
lin_raw_memorymaps() { lin_header 'Process memory raw evidence'; ps -eo pid,user,rss,vsz,pmem,comm --sort=-rss 2>&1; }

lin_sysinternals_menu() {
    while true; do
        lin_header 'Sysinternals-style tools'
        lin_menu_item '1' 'Tool availability overview'
        lin_menu_item '2' 'Process Explorer-style processes'
        lin_menu_item '3' 'TCPView-style connections'
        lin_menu_item '4' 'Handle-style open files'
        lin_menu_item '5' 'Process Monitor-style tracing readiness'
        lin_menu_item '6' 'Autoruns-style startup entries'
        lin_menu_item '7' 'VMMap / RAMMap-style memory'
        lin_menu_item '8' 'ProcDump-style dump readiness'
        lin_menu_item 'P' 'Selected PID details'
        lin_menu_item 'B' 'Back' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_show_check sysinternals ;;
            2) lin_show_check processes ;;
            3) lin_show_check connections ;;
            4) lin_show_check handles ;;
            5) lin_show_check tracing ;;
            6) lin_show_check autoruns ;;
            7) lin_show_check memorymaps ;;
            8) lin_show_check dumps ;;
            P) lin_pid_details; lin_pause ;;
            B|Q|0) return 0 ;;
            *) lin_warn 'Choose 1-8, P, or B.' ;;
        esac
    done
}
# END SYSINTERNALS

# BEGIN HEALTH
lin_check_health() {
    lin_header 'Health summary'
    local attention=0 load1 cores load_status memory_percent memory_status root_percent root_status failed updates firewall_status firewall_detail listeners container_summary container_status container_detail

    read -r load1 _ </proc/loadavg 2>/dev/null || load1='Unavailable'
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
    load_status='INFO'
    if [[ $load1 =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v current_load="$load1" -v cores="$cores" 'BEGIN {exit !(current_load > cores)}'; then load_status='REVIEW'; ((attention+=1)); fi

    memory_percent=$(awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {available=$2} END {if(total) printf "%.0f", (total-available)*100/total}' /proc/meminfo 2>/dev/null)
    memory_percent=${memory_percent:-0}
    memory_status=$(lin_usage_status "$memory_percent")
    [[ $memory_status != OK ]] && ((attention+=1))

    root_percent=$(lin_storage_root_percent); root_percent=${root_percent:-0}
    root_status=$(lin_usage_status "$root_percent")
    [[ $root_status != OK ]] && ((attention+=1))

    failed=$(lin_failed_service_count)
    (( failed > 0 )) && ((attention+=1))
    updates=$(lin_update_count)
    (( updates > 0 )) && ((attention+=1))
    listeners=$(lin_public_listener_count); listeners=${listeners:-0}
    (( listeners > 0 )) && ((attention+=1))

    firewall_status='UNAVAILABLE'; firewall_detail='No supported frontend found'
    if lin_has ufw; then
        if ufw status 2>/dev/null | grep -qi '^Status: active'; then firewall_status='OK'; firewall_detail='UFW active'; else firewall_status='REVIEW'; firewall_detail='UFW inactive or unavailable'; ((attention+=1)); fi
    elif lin_has firewall-cmd; then
        if firewall-cmd --state 2>/dev/null | grep -q running; then firewall_status='OK'; firewall_detail='firewalld running'; else firewall_status='REVIEW'; firewall_detail='firewalld not running'; ((attention+=1)); fi
    elif lin_has nft; then firewall_status='INFO'; firewall_detail='nftables installed; inspect rules for policy'; fi

    container_summary=$(lin_container_summary); IFS=$'\t' read -r container_status container_detail <<<"$container_summary"
    [[ $container_status == REVIEW || $container_status == WARNING ]] && ((attention+=1))

    lin_status_row "$load_status" 'CPU load' "$load1 across $cores logical CPU(s)"
    lin_status_row "$memory_status" 'Memory' "$memory_percent% used"
    lin_status_row "$root_status" 'Root filesystem' "$root_percent% used"
    if (( failed )); then lin_status_row 'WARNING' 'Failed services' "$failed"; else lin_status_row 'OK' 'Failed services' '0'; fi
    if (( updates )); then lin_status_row 'REVIEW' 'Available updates' "$updates"; else lin_status_row 'OK' 'Available updates' '0 in existing metadata'; fi
    lin_status_row "$firewall_status" 'Firewall' "$firewall_detail"
    if (( listeners )); then lin_status_row 'REVIEW' 'Non-local listeners' "$listeners"; else lin_status_row 'OK' 'Non-local listeners' '0'; fi
    lin_status_row "$container_status" 'Containers' "$container_detail"

    printf '\n'
    if (( attention )); then
        printf '%s%d item(s) need review. A review status is context, not proof of a fault.%s\n' "$LIN_YELLOW" "$attention" "$LIN_RESET"
    else
        printf '%sNo measured item crossed its review threshold.%s\n' "$LIN_GREEN" "$LIN_RESET"
    fi
    printf '%sThresholds: memory/root storage review at 80%%, warning at 90%%; load review above logical CPU count.%s\n' "$LIN_DIM" "$LIN_RESET"
}
# END HEALTH

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

# BEGIN SYNOLOGYCORE
# DSM-specific helpers. Bash 4+, no PATH changes and no dependency installation.
SYN_COMMAND_DIRS=(/usr/syno/bin /usr/syno/sbin /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /bin /sbin)
declare -A SYN_HELP_CACHE=()
SYN_REPORT=''
SYN_OUT=''
SYN_STATE='UNAVAILABLE'
SYN_LAST_GUIDED=''

syn_resolve() {
    local name=$1 found dir
    [[ $name =~ ^[a-zA-Z0-9_.+-]+$ ]] || return 1
    found=$(type -P "$name" 2>/dev/null) || found=''
    if [[ $found == /* && -x $found && ! -d $found ]]; then printf '%s' "$found"; return; fi
    for dir in "${SYN_COMMAND_DIRS[@]}"; do
        if [[ -x $dir/$name && ! -d $dir/$name ]]; then printf '%s' "$dir/$name"; return; fi
    done
    return 1
}
syn_stat() {
    local exe
    exe=$(syn_resolve stat) || return 127
    "$exe" "$@"
}
syn_is_dsm() { [[ -r /etc.defaults/VERSION && ( -r /etc/synoinfo.conf || -r /etc.defaults/synoinfo.conf ) ]]; }
syn_is_root() { (( EUID == 0 )); }
syn_clean() {
    # Keep Unicode, tab and newline; remove terminal control sequences/characters.
    tr -d '\000-\010\013-\037\177' | sed -E '/[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]|[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]/c\[REDACTED: sensitive field]'
}
syn_emit() {
    local text
    text=$(printf '%s\n' "$*" | syn_clean)
    printf '%s\n' "$text"
    # Bounded in-session report. No command is re-executed during export.
    if (( ${#SYN_REPORT} < 262144 )); then SYN_REPORT+="$text"$'\n'; fi
}
syn_capture() {
    local name=$1 exe timer timer_help rc; local -a timer_args=(); shift
    SYN_OUT=''; SYN_STATE='UNAVAILABLE'
    exe=$(syn_resolve "$name") || { SYN_OUT="Missing utility: $name"; return 127; }
    timer=$(syn_resolve timeout) || timer=''
    if [[ -n $timer ]]; then
        timer_help=$(LC_ALL=C "$timer" --help 2>&1) || true
        if grep -Eq '(^|[[:space:][])\-t([[:space:]=]|$)' <<<"$timer_help"; then timer_args=(-t 20)
        elif grep -Eq 'DURATION|SECS|SECONDS' <<<"$timer_help"; then timer_args=(20)
        else timer=''; fi
    fi
    if [[ -n $timer ]]; then
        if SYN_OUT=$(LC_ALL=C "$timer" "${timer_args[@]}" "$exe" "$@" 2>&1); then rc=0; else rc=$?; fi
    else
        if SYN_OUT=$(LC_ALL=C "$exe" "$@" 2>&1); then rc=0; else rc=$?; fi
    fi
    SYN_STATE=OK
    if (( rc != 0 )); then
        case $SYN_OUT in
            *'Permission denied'*|*'permission denied'*|*'Operation not permitted'*|*'must be root'*) SYN_STATE=PRIVILEGE ;;
            *'invalid option'*|*'unknown option'*|*'unrecognized option'*|*'Invalid option'*|*'Usage:'*) SYN_STATE=UNSUPPORTED ;;
            *) SYN_STATE=FAILED ;;
        esac
        (( rc == 124 )) && SYN_STATE=TIMEOUT
    fi
    return "$rc"
}
syn_run() {
    local name=$1 rc=0; shift
    syn_capture "$name" "$@" || rc=$?
    syn_emit "[$SYN_STATE] $name (exit $rc)"
    [[ -z $SYN_OUT ]] || syn_emit "$SYN_OUT"
    return "$rc"
}
syn_help() {
    local name=$1
    if [[ ! ${SYN_HELP_CACHE[$name]+present} ]]; then
        syn_capture "$name" --help || true
        SYN_HELP_CACHE[$name]=$SYN_OUT
    fi
    printf '%s' "${SYN_HELP_CACHE[$name]}"
}
syn_supports() {
    local help
    help=$(syn_help "$1")
    # Flags used here are fixed internal strings, not user-supplied expressions.
    grep -Eq -- "(^|[^[:alnum:]_-])${2}([^[:alnum:]_-]|$)" <<<"$help"
}
syn_flag() {
    local name=$1 flag; shift
    for flag in "$@"; do if syn_supports "$name" "$flag"; then printf '%s' "$flag"; return; fi; done
    return 1
}
syn_gated() {
    local name=$1 flag=$2; shift 2
    if ! syn_supports "$name" "$flag"; then syn_emit "[UNAVAILABLE] $name $flag is not advertised by the installed utility."; return 2; fi
    syn_run "$name" "$flag" "$@"
}
syn_input() {
    local value
    value=$(lin_read "$1 (B = back): ") || return 1
    [[ ${value^^} != B && -n $value && $value != *$'\n'* && $value != *$'\r'* ]] || return 1
    printf '%s' "$value"
}
syn_path() {
    [[ $1 == /* && $1 != *$'\n'* && $1 != *$'\r'* ]]
}
syn_identity_arg() { [[ -n $1 && $1 != -* && $1 != *$'\n'* && $1 != *$'\r'* ]]; }
syn_version_value() {
    local key=$1 file=${2:-/etc.defaults/VERSION}
    [[ -r $file ]] || return 1
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, "");gsub(/^"|"$/, "");print;exit}' "$file"
}
syn_info() {
    local cmd path model='Unknown' f dsm='Not detected'
    syn_is_dsm && dsm='Synology DSM detected'
    syn_emit "[INFO] $dsm"
    for f in /proc/sys/kernel/syno_hw_version /etc.defaults/synoinfo.conf; do
        if [[ -r $f ]]; then
            if [[ $f == /proc/* ]]; then IFS= read -r model < "$f" || true
            else model=$(syn_version_value unique "$f"); fi
            [[ -n $model ]] && break
        fi
    done
    syn_emit "Model: $model"
    syn_emit "DSM: $(syn_version_value productversion) build $(syn_version_value buildnumber) update $(syn_version_value smallfixnumber)"
    syn_emit "Host: $(uname -n) | Kernel: $(uname -r) | Architecture: $(uname -m)"
    syn_run uptime || true
    syn_emit "Privilege: $(if syn_is_root; then printf root; else printf 'unprivileged (some diagnostics may be incomplete)'; fi)"
    for cmd in id wbinfo synouser synogroup synoacltool synoshare smbstatus testparm synosystemctl synopkg synodisk synostgpool smartctl mdadm getent synoservice python3 timeout stat strings find; do
        path=$(syn_resolve "$cmd") || path='UNAVAILABLE (optional)'
        syn_emit "$cmd: $path"
    done
    syn_emit 'Bash 4+ is required. No packages are installed; no root escalation is attempted.'
}
syn_export() {
    local dir file
    [[ -n $SYN_LAST_GUIDED ]] || { lin_error 'Run guided troubleshooting first; exports contain its curated findings, not raw logs/configuration or owner-file strings.'; return 1; }
    dir=$(syn_input 'Existing private report directory (absolute path)') || return
    syn_path "$dir" && [[ -d $dir && ! -L $dir && -O $dir ]] || { lin_error 'Choose an existing directory owned by the current user.'; return 1; }
    # Export only into private directories; mktemp creates a non-overwriting 0600 file.
    local mode
    mode=$(syn_stat -c '%a' -- "$dir" 2>/dev/null) || { lin_error 'Cannot verify directory permissions.'; return 1; }
    [[ $mode == 700 ]] || { lin_error 'Report directory must have mode 700.'; return 1; }
    file=$(umask 077; mktemp "$dir/synology-$(date +%Y%m%dT%H%M%S)-XXXXXX.txt") || return
    if ! printf 'Synology diagnostic report (snapshot; not a root-cause guarantee)\n%s\n' "$SYN_LAST_GUIDED" | syn_clean > "$file"; then lin_error "Export failed: $file"; return 1; fi
    printf 'Report saved: %s\n' "$file"
}
# END SYNOLOGYCORE

# BEGIN SYNOLOGYSMB
# Safe Samba status/configuration views; text results are evidence, not parsed tables.
SYN_SMB_JSON=''
SYN_SMB_MATCHES=''
syn_smb_snapshot() {
    local option rc=0
    SYN_SMB_JSON=''
    option=$(syn_flag smbstatus --json -j) || return 2
    syn_capture smbstatus "$option" || return $?
    SYN_SMB_JSON=$SYN_OUT
    return "$rc"
}
syn_smb_json_match() {
    # Samba's documented JSON schema. Python is optional and only needed for
    # structured correlation and the fail-closed quarantine gate.
    local needle=$1 exact=${2:-0} py
    py=$(syn_resolve python3) || return 2
    SYN_SMB_MATCHES=$(SYN_JSON="$SYN_SMB_JSON" "$py" - "$needle" "$exact" <<'PY'
import json,sys,os,posixpath
try:
 d=json.loads(os.environ['SYN_JSON'])
 if not isinstance(d,dict) or not all(isinstance(d.get(k),dict) for k in ('sessions','tcons','open_files')):raise ValueError('unsupported/incomplete schema')
 if d.get('error') or d.get('errors'):raise ValueError('Samba reported errors')
 sessions=d['sessions'];needle=sys.argv[1];exact=sys.argv[2]=='1'
 for item in d['open_files'].values():
  if not isinstance(item,dict) or not isinstance(item.get('service_path'),str) or not isinstance(item.get('filename'),str) or not isinstance(item.get('opens'),dict):raise ValueError('unrecognized open file record')
  path=posixpath.normpath(posixpath.join(item['service_path'],item['filename']))
  if not path.startswith('/'):raise ValueError('non-absolute open path')
  if (path!=needle if exact else needle.casefold() not in path.casefold()):continue
  if not item['opens']:
   print(json.dumps({'path':path,'pid':'unknown','status':'open-file record without detailed opens; treat conservatively as active'},ensure_ascii=False))
  for op in item['opens'].values():
   if not isinstance(op,dict) or not isinstance(op.get('server_id'),dict) or 'pid' not in op['server_id']:raise ValueError('missing handle server PID')
   pid=str(op['server_id']['pid'])
   matches=[s for s in sessions.values() if isinstance(s,dict) and str(s.get('server_id',{}).get('pid'))==pid]
   if not matches:matches=[{}]
   for session in matches:
    print(json.dumps({'path':path,'pid':pid,'SMB_user':session.get('username','unknown'),'client':session.get('remote_machine','unknown'),'host':session.get('hostname','unknown'),'correlation':'PID candidate; not proof of per-handle user'},ensure_ascii=False))
except (ValueError,TypeError,KeyError,AttributeError) as e:
 print('Cannot interpret Samba JSON: '+str(e),file=sys.stderr);sys.exit(2)
PY
) || return 2
}
syn_smb_search() {
    local needle=$1 mode=${2:-path} flag rc=0
    syn_emit "SMB filter ($mode): $needle"
    if syn_smb_snapshot && syn_smb_json_match "$needle"; then
        if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "$SYN_SMB_MATCHES"
        else syn_emit '[INFO] No matching open paths in this structured snapshot. This does not establish that nobody is editing.'; fi
        syn_emit 'Session/PID correlation is advisory; separate session/share tables can have multiple users per server process.'
        return 0
    fi
    flag=$(syn_flag smbstatus --locks -L) || { syn_emit '[UNAVAILABLE] Installed smbstatus does not advertise a locks view.'; return 2; }
    syn_capture smbstatus "$flag" || { syn_emit "[$SYN_STATE] SMB locks failed: $SYN_OUT"; return 1; }
    # Literal filtering retains complete lines, including filenames with spaces.
    if SYN_SMB_MATCHES=$(grep -iF -- "$needle" <<<"$SYN_OUT"); then syn_emit "$SYN_SMB_MATCHES"
    else syn_emit '[INFO] No matching text lines. Unparsed output is not a verified empty handle set.'; fi
    syn_emit 'Text fallback: filenames are not split on spaces. Correlate PIDs with the process/session and share views below.'
    syn_run smbstatus || rc=$?
    return "$rc"
}
syn_smb_proof_clear() {
    # Used only before quarantine/restore. Any uncertainty blocks mutation.
    local path
    syn_is_root || { lin_error 'Handle verification requires root.'; return 1; }
    syn_smb_snapshot || { lin_error 'Cannot obtain structured SMB handles. Operation refused.'; return 1; }
    for path in "$@"; do
        syn_smb_json_match "$path" 1 || { lin_error 'Cannot interpret all SMB handle records. Operation refused.'; return 1; }
        [[ -z $SYN_SMB_MATCHES ]] || { syn_emit "$SYN_SMB_MATCHES"; lin_error 'Matching active handles exist. Operation refused.'; return 1; }
    done
    return 0
}
syn_smb_view() {
    local view=$1 flag
    case $view in
        sessions) syn_run smbstatus ;;
        processes) flag=$(syn_flag smbstatus --processes -p) || return 2; syn_run smbstatus "$flag" ;;
        shares) flag=$(syn_flag smbstatus --shares -S) || return 2; syn_run smbstatus "$flag" ;;
        locks) flag=$(syn_flag smbstatus --locks -L) || return 2; syn_run smbstatus "$flag" ;;
        range) flag=$(syn_flag smbstatus --byterange -B) || return 2; syn_run smbstatus "$flag" ;;
    esac
}
syn_smb_config() {
    local flag
    flag=$(syn_flag testparm --suppress-prompt -s) || { syn_emit '[UNAVAILABLE] Noninteractive testparm syntax not advertised.'; return 2; }
    syn_capture testparm "$flag" || { syn_emit "[$SYN_STATE] testparm failed: $SYN_OUT"; return 1; }
    # Deliberate allowlist: never export arbitrary Samba configuration/secrets.
    SYN_SHARE_CONFIG=$(awk '
      /^[ \t]*\[/ {print;next}
      /^[ \t]*(path|read only|valid users|write list|read list|force user|force group|guest ok|browseable|workgroup|realm|security|server role)[ \t]*=/ {print}
    ' <<<"$SYN_OUT")
    syn_emit 'Effective Samba configuration: safe directive subset (not the full configuration)'
    syn_emit "$SYN_SHARE_CONFIG"
}
syn_share_root() {
    local target=$1 root='' name path best=''
    syn_smb_config >/dev/null || return 1
    while IFS=$'\t' read -r name path; do
        [[ $path == /* && $path != *'%'* && $path != *'$'* ]] || continue
        if [[ $target == "$path" || $target == "$path/"* || $path == / ]]; then
            if (( ${#path} > ${#best} )); then best=$path; root=$name; fi
        fi
    done < <(awk '
      /^[ \t]*\[/ {s=$0;sub(/^[ \t]*\[/,"",s);sub(/\].*$/,"",s)}
      /^[ \t]*path[ \t]*=/ {p=$0;sub(/^[^=]*=[ \t]*/,"",p);sub(/[ \t]+$/,"",p);print s "\t" p}
    ' <<<"$SYN_SHARE_CONFIG")
    [[ -n $best ]] || return 1
    SYN_SHARE_NAME=$root; SYN_SHARE_ROOT=$best
}
syn_logs() {
    local f
    for f in /var/log/samba/log.smbd /var/log/samba/smb.log /var/log/messages; do
        [[ -r $f ]] || continue
        syn_emit "Recent error context: $f (bounded and redacted)"
        syn_emit "$(tail -n 200 -- "$f" | grep -iE 'error|fail|denied|degrad|corrupt|I/O' | tail -n 40)"
    done
    syn_emit 'Logs may be unavailable, rotated or incomplete. No absence-of-errors conclusion is made.'
}
syn_smb_menu() {
    local choice needle
    while true; do
        lin_header 'Synology > SMB sessions and file locks'
        lin_menu_item 1 'Active sessions / connected users / clients'
        lin_menu_item 2 'Process IDs and session table'
        lin_menu_item 3 'Accessed shares'
        lin_menu_item 4 'Open files / locks'
        lin_menu_item 5 'Search open file/path (literal)'
        lin_menu_item 6 'Filter sessions by user/client/share (literal text)'
        lin_menu_item 7 'Effective Samba configuration (safe subset)'
        lin_menu_item 8 'SMB service status'
        lin_menu_item 9 'Relevant recent logs'
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            1) syn_smb_view sessions || true ;; 2) syn_smb_view processes || syn_emit '[UNAVAILABLE] Process view failed/unsupported.' ;;
            3) syn_smb_view shares || syn_emit '[UNAVAILABLE] Share view failed/unsupported.' ;;
            4) syn_smb_view locks || syn_emit '[UNAVAILABLE] Locks view failed/unsupported.' ;;
            5) needle=$(syn_input 'Filename or partial path') && syn_smb_search "$needle" || true ;;
            6) needle=$(syn_input 'Username, client IP/hostname, or share name') || continue
               if syn_capture smbstatus; then
                   if SYN_SMB_MATCHES=$(grep -iF -- "$needle" <<<"$SYN_OUT"); then syn_emit "$SYN_SMB_MATCHES"; else syn_emit '[INFO] No matching session text lines.'; fi
                   syn_emit 'Literal text filter only; use complete session/share views for correlation.'
               else syn_emit "[$SYN_STATE] $SYN_OUT"; fi ;;
            7) syn_smb_config || true ;; 8) syn_service_status smb ;; 9) syn_logs ;;
            0|B|b) return ;; *) continue ;;
        esac
        lin_pause
    done
}
# END SYNOLOGYSMB

# BEGIN SYNOLOGYACL
# The DSM ACL evaluator is authoritative; no attempt is made to rebuild it.
SYN_EFFECTIVE=''
SYN_EFFECTIVE_STATE='UNAVAILABLE'
syn_permission_flags() {
    local flags=$1 kind=${2:-file} flag label i
    for ((i=0;i<${#flags};i++)); do
        flag=${flags:i:1}
        case $flag in
            r) label='Read data / list directory' ;; w) label='Write data / create files' ;;
            x) label='Execute / traverse directory' ;; p) label='Append data / create directories' ;;
            d) label='Delete' ;; D) [[ $kind == directory ]] && label='Delete child objects' || label='Delete child: directory-only flag' ;;
            a) label='Read attributes' ;; A) label='Write attributes' ;; R) label='Read extended attributes' ;;
            W) label='Write extended attributes' ;; c) label='Read permissions' ;; C) label='Change permissions' ;;
            o) label='Take ownership' ;; -) continue ;; *) label='Unknown flag' ;;
        esac
        printf '%s = %s\n' "$flag" "$label"
    done
    [[ $kind == file ]] && printf 'Delete-child (D) is not required on an individual file.\n'
    return 0
}
syn_acl_interpret() {
    local line type identity access flags inheritance level kind=$1
    while IFS= read -r line; do
        # Greedy identity permits domain names, spaces and colons; no word splitting.
        if [[ $line =~ (user|group):(.*):(allow|deny):([rwxpdDaARWcCo-]+):([fdin-]+) ]]; then
            type=${BASH_REMATCH[1]}; identity=${BASH_REMATCH[2]}; access=${BASH_REMATCH[3]}; flags=${BASH_REMATCH[4]}; inheritance=${BASH_REMATCH[5]}
            level='unknown'
            if [[ $line =~ level:([0-9]+) ]]; then
                level=${BASH_REMATCH[1]}; if [[ $level == 0 ]]; then level='explicit (level 0)'; else level="inherited (ancestor level $level)"; fi
            fi
            if [[ -z $identity ]]; then
                syn_emit "[INFO] Unresolved $type identity; $access; $level. No numeric ID is present in this entry; identity cannot be inferred."
            else syn_emit "ACL $type [$identity]: $access; $level; inheritance flags=$inheritance"; fi
            syn_emit "$(syn_permission_flags "$flags" "$kind")"
            case $inheritance in *f*) syn_emit 'Inheritance: files inherit' ;; esac
            case $inheritance in *d*) syn_emit 'Inheritance: directories inherit' ;; esac
            case $inheritance in *i*) syn_emit 'Inheritance: inherit-only entry' ;; esac
            case $inheritance in *n*) syn_emit 'Inheritance: no-propagate flag' ;; esac
        fi
    done
}
syn_acl_get() {
    local path=$1 kind=file
    syn_path "$path" && [[ -e $path && ! -L $path ]] || { syn_emit '[UNAVAILABLE] Object absent, inaccessible or a symlink; select a real absolute path.'; return 1; }
    [[ -d $path ]] && kind=directory
    syn_emit "ACL object: $path ($kind)"
    syn_run stat -c 'Filesystem owner=%U uid=%u group=%G gid=%g mode=%A modified=%y' -- "$path" || true
    # These two forms are verified in the supplied production matrix, not inferred.
    if ! syn_capture synoacltool -get "$path"; then syn_emit "[$SYN_STATE] ACL query: $SYN_OUT"; return 1; fi
    syn_emit "$SYN_OUT"
    syn_acl_interpret "$kind" <<<"$SYN_OUT"
}
syn_acl_effective() {
    local path=$1 user=$2 candidate line
    SYN_EFFECTIVE='';SYN_EFFECTIVE_STATE=UNAVAILABLE
    syn_path "$path" && syn_identity_arg "$user" || return 1
    if ! syn_capture synoacltool -get-perm "$path" "$user"; then SYN_EFFECTIVE_STATE=$SYN_STATE; syn_emit "[$SYN_STATE] Effective ACL query failed: $SYN_OUT"; return 1; fi
    syn_emit "Effective filesystem ACL for [$user] on [$path]: $SYN_OUT"
    # Accept only an unambiguous 13-position permission token, not a prose claim.
    candidate=''
    while IFS= read -r line; do
        if [[ $line =~ (^|[^[:alnum:]_-])([r-][w-][x-][p-][d-][D-][a-][A-][R-][W-][c-][C-][o-])([^[:alnum:]_-]|$) ]]; then
            [[ -z $candidate || $candidate == "${BASH_REMATCH[2]}" ]] || { SYN_EFFECTIVE_STATE=UNSUPPORTED; return 2; }
            candidate=${BASH_REMATCH[2]}
        fi
    done <<<"$SYN_OUT"
    [[ -n $candidate ]] || { SYN_EFFECTIVE_STATE=UNSUPPORTED; syn_emit '[UNAVAILABLE] Unrecognized permission output; raw evaluator output shown above.'; return 2; }
    SYN_EFFECTIVE=$candidate; SYN_EFFECTIVE_STATE=OK
    syn_emit "$(syn_permission_flags "$candidate" "$(if [[ -d $path ]]; then printf directory; else printf file; fi)")"
}
syn_identity() {
    local user=$1
    syn_identity_arg "$user" || { syn_emit '[UNAVAILABLE] Invalid identity; no command run.'; return 2; }
    if syn_capture id "$user"; then syn_emit "[OK] User resolved and memberships retrieved: $SYN_OUT"; return 0; fi
    syn_emit "[$SYN_STATE] id lookup failed: $SYN_OUT"
    if syn_supports wbinfo --user-info; then syn_run wbinfo "--user-info=$user" || true
    else syn_emit '[UNAVAILABLE] wbinfo user-info syntax not advertised.'; fi
    syn_emit 'An unsuccessful lookup does not prove the account was deleted.'
    return 1
}
syn_numeric_identity() {
    local kind=$1 number=$2 file option
    [[ $number =~ ^[0-9]+$ ]] || { syn_emit '[UNAVAILABLE] Numeric ID required.'; return 2; }
    if [[ $kind == user ]]; then file=/etc/passwd;option=--uid-info;else file=/etc/group;option=--gid-info;fi
    if [[ -r $file ]]; then
        # Do not expose password/hash fields from local account databases.
        syn_emit "$(awk -F: -v n="$number" '$3==n {printf "Local name=%s ID=%s",$1,$3;if(NF>=7)printf " primary-GID=%s home=%s shell=%s",$4,$6,$7;print ""}' "$file")"
    fi
    syn_gated wbinfo "$option" "$number" || true
    syn_emit 'Missing local/AD results are inconclusive; directory service connectivity may be unavailable.'
}
syn_membership_acl() {
    local path=$1 user=$2 acl memberships type name match
    syn_identity "$user" || true
    if ! syn_capture id -Gn "$user"; then syn_emit '[UNAVAILABLE] Group names unavailable; comparison skipped.'; return 1; fi
    memberships=$SYN_OUT
    if ! syn_capture synoacltool -get "$path"; then syn_emit "[$SYN_STATE] ACL unavailable: $SYN_OUT"; return 1; fi
    acl=$SYN_OUT
    while IFS= read -r match; do
        if [[ $match =~ (user|group):(.*):(allow|deny): ]]; then
            type=${BASH_REMATCH[1]};name=${BASH_REMATCH[2]}
            if [[ $type == user && $name == "$user" ]]; then syn_emit "[INFO] Exact user ACL entry: $match"
            elif [[ $type == group && -n $name ]]; then
                # id -Gn is space-delimited: spaces in group names prevent a reliable split.
                if grep -Fq -- "$name" <<<"$memberships"; then syn_emit "[REVIEW] Group-name text overlap (not proven membership): $match"; fi
            fi
        fi
    done <<<"$acl"
    syn_emit 'Group names with spaces/aliases and nested AD membership require verification. Use DSM get-perm as the authoritative filesystem result.'
    syn_acl_effective "$path" "$user" || true
}
syn_acl_walk() {
    local root=$1 depth=$2 path count=0 findbin
    syn_path "$root" && [[ -d $root && ! -L $root && $depth =~ ^[0-5]$ ]] || { syn_emit '[UNAVAILABLE] Use a real directory and depth 0-5.'; return 2; }
    findbin=$(syn_resolve find) || return 127
    syn_supports find -maxdepth && syn_supports find -print0 || { syn_emit '[UNAVAILABLE] find lacks bounded NUL-delimited traversal.'; return 2; }
    # Refuse symlinks; do not cross filesystem boundaries. Hard cap on inspected objects.
    while IFS= read -r -d '' path; do
        ((count+=1)); (( count <= 200 )) || { syn_emit '[INFO] Inspection capped at 200 objects.'; break; }
        syn_acl_get "$path" || true
    done < <("$findbin" "$root" -xdev -maxdepth "$depth" ! -type l -print0)
    syn_emit 'Traversal is bounded; an interrupted or inaccessible traversal is not a complete ACL audit.'
}
syn_acl_menu() {
    local choice path user depth
    while true; do
        lin_header 'Synology > ACL and effective permissions'
        lin_menu_item 1 'Object ACL, ownership, inheritance and unresolved identities'
        lin_menu_item 2 'Effective filesystem permissions for a user'
        lin_menu_item 3 'Compare parent and child ACLs'
        lin_menu_item 4 'Bounded recursive ACL inspection (depth 0-5; max 200 objects)'
        lin_menu_item 5 'Compare memberships with ACL entries'
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        [[ $choice != 0 && ${choice^^} != B ]] || return
        path=$(syn_input 'Absolute file/directory path') || continue
        syn_path "$path" || { syn_emit '[UNAVAILABLE] Absolute path required.'; continue; }
        case $choice in
            1) syn_acl_get "$path" || true ;;
            2) user=$(syn_input 'Local or DOMAIN\user') && syn_acl_effective "$path" "$user" || true ;;
            3) syn_acl_get "$(dirname -- "$path")" || true; syn_acl_get "$path" || true
               syn_emit 'Parent and child ACL evidence shown. Different inheritance levels do not alone establish an error.' ;;
            4) depth=$(syn_input 'Maximum depth 0-5') && syn_acl_walk "$path" "$depth" || true ;;
            5) user=$(syn_input 'Local or DOMAIN\user') && syn_membership_acl "$path" "$user" || true ;;
        esac
        lin_pause
    done
}
syn_identity_menu() {
    local choice value name
    while true; do
        lin_header 'Synology > Users and groups'
        lin_menu_item 1 'Resolve user and memberships';lin_menu_item 2 'Resolve numeric UID';lin_menu_item 3 'Resolve numeric GID'
        lin_menu_item 4 'Enumerate local users';lin_menu_item 5 'Enumerate local groups';lin_menu_item 6 'Inspect native user';lin_menu_item 7 'Inspect native group'
        lin_menu_item 8 'Domain connectivity / online status';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) value=$(syn_input 'User') && syn_identity "$value" || true ;;
            2|3) value=$(syn_input 'Numeric ID') || continue; name=user;[[ $choice == 3 ]] && name=group;syn_numeric_identity "$name" "$value" || true ;;
            4|5) name=synouser;[[ $choice == 5 ]] && name=synogroup
                 if syn_supports "$name" --enum && syn_supports "$name" local;then syn_run "$name" --enum local || true
                 else syn_emit '[UNAVAILABLE] Native local enumeration syntax not advertised.';fi ;;
            6|7) value=$(syn_input 'Name') || continue;syn_identity_arg "$value" || continue;name=synouser;[[ $choice == 7 ]] && name=synogroup
                 syn_gated "$name" --get "$value" || true ;;
            8) syn_gated wbinfo --ping-dc || true;syn_gated wbinfo --online-status || true ;;
            *) continue ;;
        esac
        lin_pause
    done
}
# END SYNOLOGYACL

# BEGIN SYNOLOGYOFFICE
# Office owner files are evidence, never proof that a document is being edited.
SYN_OWNER_ORIGINAL=''
syn_owner_original() {
    local path=$1 base parent candidate
    base=${path##*/};parent=${path%/*}
    [[ $base == '~$'* && ${#base} -gt 2 ]] || return 1
    candidate=$parent/${base:2}
    SYN_OWNER_ORIGINAL=$candidate
    printf '%s' "$candidate"
}
syn_owner_inspect() {
    local path=$1 original stringsbin text size epoch now birth
    syn_path "$path" && [[ -f $path && ! -L $path && ${path##*/} == '~$'* ]] || { syn_emit '[UNAVAILABLE] Select a real Office owner file beginning with ~$.'; return 1; }
    original=$(syn_owner_original "$path") || return 1
    syn_emit "Office owner file: $path"
    syn_run stat -c 'Filesystem owner=%U uid=%u group=%G size=%s modified=%y epoch=%Y' -- "$path" || true
    epoch=$(syn_stat -c '%Y' -- "$path" 2>/dev/null) || epoch=''
    now=$(date +%s)
    if [[ $epoch =~ ^[0-9]+$ && $now =~ ^[0-9]+$ ]]; then syn_emit "Owner file age (seconds): $((now-epoch)) (age alone is not evidence of staleness)"; fi
    birth=$(syn_stat -c '%w' -- "$path" 2>/dev/null) || birth=''
    if [[ $birth =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then syn_emit "Creation time: $birth";else syn_emit 'Creation time: unavailable on this utility/filesystem';fi
    size=$(syn_stat -c '%s' -- "$path" 2>/dev/null) || size=''
    stringsbin=$(syn_resolve strings) || stringsbin=''
    if [[ -n $stringsbin && $size =~ ^[0-9]+$ ]] && ((size<=65536)); then
        text=$("$stringsbin" "$path" 2>/dev/null | head -n 8) || true
        syn_emit "Office username candidates (heuristic strings; NOT filesystem owner or authenticated SMB identity): $text"
        if syn_supports strings -e; then syn_emit "UTF-16LE string candidates: $("$stringsbin" -e l "$path" 2>/dev/null | head -n 8)"; fi
    else syn_emit 'Office username extraction unavailable or file exceeds 64 KiB inspection bound.'; fi
    if [[ -f $original ]]; then syn_emit "Apparent original document: $original"
    else syn_emit "[REVIEW] No original at literal stripped-name path: $original. Office can truncate or alter owner filenames; original identification is unconfirmed.";fi
    if syn_smb_snapshot && syn_smb_json_match "$path" 1; then
        if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "[REVIEW] Active owner-file handles: $SYN_SMB_MATCHES"
        elif syn_smb_json_match "$original" 1; then
            if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "[REVIEW] Active original-document handles: $SYN_SMB_MATCHES"
            else syn_emit '[REVIEW] Potentially stale owner file: no exact-path matches in this SMB snapshot. Editing status and root cause remain unconfirmed.';fi
        fi
    else syn_emit '[UNAVAILABLE] Reliable SMB correlation unavailable. Cannot assess whether this owner file is stale.';fi
}
syn_owner_find() {
    local root=$1 depth=$2 findbin path count=0
    syn_path "$root" && [[ -d $root && ! -L $root && $depth =~ ^[0-5]$ ]] || { syn_emit '[UNAVAILABLE] Use a real directory and depth 0-5 (0 = this directory only).'; return 2; }
    findbin=$(syn_resolve find) || return 127
    syn_supports find -maxdepth && syn_supports find -print0 || { syn_emit '[UNAVAILABLE] find lacks supported bounded traversal.'; return 2; }
    while IFS= read -r -d '' path; do
        ((count+=1)); ((count<=200)) || { syn_emit '[INFO] Owner-file inspection capped at 200 matches.'; break; }
        syn_owner_inspect "$path" || true
    done < <("$findbin" "$root" -xdev -maxdepth "$((depth+1))" -type f -name '~$*' -print0)
    syn_emit "Owner files inspected: $((count>200?200:count)). This bounded traversal can omit inaccessible objects or stop early."
}

syn_owner_transaction() {
    # Python is optional. This helper validates each transaction and uses Linux
    # renameat2(RENAME_NOREPLACE); it never falls back to an overwrite-prone mv.
    local mode=$1 source=$2 destination=${3:-} py
    py=$(syn_resolve python3) || { lin_error 'Python 3 is required for guarded quarantine/restore.'; return 2; }
    "$py" - "$mode" "$source" "$destination" <<'PY'
import os,sys,json,stat,ctypes,errno,time,uuid,re
mode,source,destination=sys.argv[1:]
libc=ctypes.CDLL(None,use_errno=True)
rename=getattr(libc,'renameat2',None)
if rename is None:sys.exit('UNAVAILABLE: renameat2 no-overwrite support is required.')
rename.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint]
def canonical(p):
 if not os.path.isabs(p) or any(ord(c)<32 for c in p) or os.path.realpath(p)!=os.path.normpath(p):raise ValueError('Absolute paths without symlink components/control characters required')
 return os.path.normpath(p)
def regular(p):
 s=os.lstat(p)
 if not stat.S_ISREG(s.st_mode) or s.st_nlink!=1:raise ValueError('Regular, single-link owner file required')
 if s.st_size>1048576:raise ValueError('Owner file exceeds 1 MiB safety bound')
 return s
def ownerpath(p):
 p=canonical(p)
 if not os.path.basename(p).startswith('~$') or len(os.path.basename(p))<=2:raise ValueError('Not an Office owner filename')
 return p
def signature(s):return [s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns]
def parent_fd(path):
 # Walk every component without following symlinks, not just the last one.
 fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY)
 try:
  for component in os.path.dirname(path).split('/'):
   if not component:continue
   next_fd=os.open(component,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
   os.close(fd);fd=next_fd
  return fd
 except BaseException:
  os.close(fd);raise
def guarded_move(src,dst):
 # Retain both parent descriptors through the atomic no-overwrite move.
 sp=parent_fd(src)
 try:dp=parent_fd(dst)
 except BaseException:os.close(sp);raise
 try:
  if rename(sp,os.fsencode(os.path.basename(src)),dp,os.fsencode(os.path.basename(dst)),1)!=0:
   e=ctypes.get_errno();raise OSError(e,os.strerror(e))
 finally:os.close(sp);os.close(dp)
def private(p):
 s=os.lstat(p)
 if not stat.S_ISDIR(s.st_mode) or s.st_uid!=0 or stat.S_IMODE(s.st_mode)!=0o700:raise ValueError('Quarantine directory must be root-owned mode 700')
try:
 if os.geteuid()!=0:raise ValueError('Existing root session required')
 if mode in ('quarantine','prepare'):
  source=ownerpath(source);s=regular(source)
  original=os.path.join(os.path.dirname(source),os.path.basename(source)[2:])
  if os.path.lexists(original):
   orig=os.lstat(original)
   if not stat.S_ISREG(orig.st_mode) or orig.st_nlink!=1:raise ValueError('Original must not be a symlink or hard-link alias')
  # Fixed root-level @ directory, outside the normal DSM share directories.
  volume=re.match(r'^(/volume[0-9]+)/',source)
  if not volume:raise ValueError('Quarantine only supports /volumeN paths')
  base=volume.group(1)+'/@d0xd-owner-quarantine'
  if mode=='prepare':print(base);sys.exit(0)
  canonical(base)
  if not os.path.exists(base):os.mkdir(base,0o700)
  private(base)
  if os.stat(base).st_dev!=s.st_dev:raise ValueError('Quarantine must be on the same filesystem')
  tx=base+'/'+time.strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex
  os.mkdir(tx,0o700);payload=tx+'/owner-file';manifest=tx+'/manifest.json'
  record={'version':1,'original':source,'payload':payload,'signature':signature(s),'state':'prepared'}
  with open(manifest,'x',encoding='utf-8') as f:os.chmod(manifest,0o600);json.dump(record,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
  if signature(regular(source))!=record['signature']:raise ValueError('Owner file changed during preparation')
  guarded_move(source,payload)
  if signature(regular(payload))!=record['signature'] or os.path.lexists(source):raise ValueError('Move verification failed; inspect manifest and both locations')
  # Keep the pre-move manifest intact: a crash never destroys recovery data.
  print('Quarantined. Manifest: '+manifest)
 elif mode in ('restore','inspect'):
  manifest=canonical(source);tx=os.path.dirname(manifest);base=os.path.dirname(tx)
  if not re.match(r'^/volume[0-9]+/@d0xd-owner-quarantine/[^/]+/manifest\.json$',manifest):raise ValueError('Unrecognized quarantine manifest location')
  private(base);private(tx)
  ms=os.lstat(manifest)
  if not stat.S_ISREG(ms.st_mode) or ms.st_uid!=0 or ms.st_nlink!=1 or stat.S_IMODE(ms.st_mode)!=0o600 or ms.st_size>16384:raise ValueError('Unsafe manifest')
  with open(manifest,encoding='utf-8') as f:r=json.load(f)
  original=ownerpath(r['original']);payload=canonical(r['payload'])
  if r.get('version')!=1 or payload!=tx+'/owner-file' or os.path.dirname(original).split('/')[1]!=base.split('/')[1]:raise ValueError('Invalid manifest paths')
  if signature(regular(payload))!=r['signature']:raise ValueError('Quarantine payload changed')
  if os.path.lexists(original):raise ValueError('Original owner path exists; refusing overwrite')
  if mode=='inspect':print(original);sys.exit(0)
  guarded_move(payload,original)
  if signature(regular(original))!=r['signature'] or os.path.lexists(payload):raise ValueError('Restore verification failed')
  print('Restored: '+original+'; retained manifest: '+manifest)
 else:raise ValueError('Unsupported operation')
except (ValueError,OSError,KeyError,TypeError) as e:sys.exit('REFUSED/FAILED: '+str(e))
PY
}
syn_owner_change() {
    local mode=$1 path=$2 original document base answer
    syn_is_root || { lin_error 'Quarantine/restore requires an existing root session.'; return 1; }
    if [[ $mode == quarantine ]]; then
        original=$path
        base=$(syn_owner_transaction prepare "$path") || return
        # Verify a complete-enough effective share path inventory. Missing or
        # variable share paths make the destination's isolation unprovable.
        syn_smb_config >/dev/null || { lin_error 'Cannot verify share roots; quarantine refused.'; return 1; }
        local share share_count=0
        while IFS= read -r share; do
            [[ $share == /* && $share != *'%'* && $share != *'$'* ]] || { lin_error 'Unresolved share path; quarantine refused.'; return 1; }
            share=$(cd -- "$share" 2>/dev/null && pwd -P) || { lin_error 'Cannot resolve a share root; quarantine refused.'; return 1; }
            ((share_count+=1))
            [[ $base != "$share" && $base != "$share/"* && $share != / ]] || { lin_error 'Quarantine directory is inside a configured share.'; return 1; }
        done < <(awk '/^[ \t]*path[ \t]*=/ {sub(/^[^=]*=[ \t]*/, "");sub(/[ \t]+$/, "");print}' <<<"$SYN_SHARE_CONFIG")
        (( share_count > 0 )) || { lin_error 'No share roots available; quarantine refused.'; return 1; }
        syn_emit "CHANGES SYSTEM: source [$path]; destination [$base/<unique transaction>/owner-file]"
    else
        original=$(syn_owner_transaction inspect "$path") || return
        syn_emit "CHANGES SYSTEM: manifest [$path]; restore destination [$original]"
    fi
    document=$(syn_owner_original "$original") || return
    syn_smb_proof_clear "$original" "$document" || return
    answer=$(lin_read 'Type NOBODY IS EDITING to confirm you checked with users (SMB snapshots cannot prove this): ') || return
    [[ $answer == 'NOBODY IS EDITING' ]] || { syn_emit 'Cancelled; no file moved.'; return 1; }
    syn_smb_proof_clear "$original" "$document" || return
    if syn_owner_transaction "$mode" "$path"; then syn_emit "[OK] $mode completed and filesystem identity verified."
    else syn_emit "[FAILED] $mode; inspect manifest and file locations before retrying.";return 1;fi
}
syn_office_menu() {
    local choice path depth
    while true; do
        lin_header 'Synology > Office file locks'
        lin_menu_item 1 'Find and inspect owner files (~$; bounded search)'
        lin_menu_item 2 'Inspect one owner file and SMB correlations'
        lin_menu_item 3 'Quarantine owner file [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 4 'Restore quarantined owner file [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        [[ $choice != 0 && ${choice^^} != B ]] || return
        case $choice in
            1) path=$(syn_input 'Absolute directory') || continue;depth=$(syn_input 'Recursion depth 0-5') || continue;syn_owner_find "$path" "$depth" || true ;;
            2) path=$(syn_input 'Exact owner-file path') && syn_owner_inspect "$path" || true ;;
            3) path=$(syn_input 'Exact owner-file path') && syn_owner_change quarantine "$path" || true ;;
            4) path=$(syn_input 'Exact private manifest.json path') && syn_owner_change restore "$path" || true ;;
        esac
        lin_pause
    done
}
# END SYNOLOGYOFFICE

# BEGIN SYNOLOGYDIAGNOSTICS
# Extended diagnostics: only fixed read-only operations with detected syntax.
syn_service_status() {
    local service=$1
    syn_identity_arg "$service" || return 2
    if syn_supports synosystemctl get-active-status; then syn_run synosystemctl get-active-status "$service" || true
    elif syn_supports synosystemctl status; then syn_run synosystemctl status "$service" || true
    else syn_emit '[UNAVAILABLE] Installed synosystemctl does not advertise a validated status operation.';fi
}
syn_services_menu() {
    local choice value
    while true; do
        lin_header 'Synology > Services and packages'
        lin_menu_item 1 'List services (if advertised)';lin_menu_item 2 'Selected service status';lin_menu_item 3 'SMB service status'
        lin_menu_item 4 'List packages';lin_menu_item 5 'Selected package status';lin_menu_item 6 'Listening ports';lin_menu_item 7 'Recent error logs';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) syn_gated synosystemctl list-units || true ;;
            2) value=$(syn_input 'Service name') && syn_service_status "$value" || true ;;
            3) syn_service_status smb ;;
            4) syn_gated synopkg list || true ;;
            5) value=$(syn_input 'Package name') || continue;syn_identity_arg "$value" && syn_gated synopkg status "$value" || true ;;
            6) syn_connections ;;
            7) syn_logs ;;
            *) continue ;;
        esac
        lin_pause
    done
}
syn_connections() {
    if syn_resolve ss >/dev/null; then syn_run ss -lntup || true
    elif syn_resolve netstat >/dev/null; then syn_run netstat -lntp || true
    else syn_emit '[UNAVAILABLE] Neither ss nor netstat is installed.';fi
}
syn_storage_menu() {
    local choice path device
    while true; do
        lin_header 'Synology > Storage and disks (read-only)'
        lin_menu_item 1 'Volume/filesystem utilisation';lin_menu_item 2 'Mounts / disk identification'
        lin_menu_item 3 'RAID status';lin_menu_item 4 'SMART attributes/health (no tests)';lin_menu_item 5 'Storage pool info (if advertised)'
        lin_menu_item 6 'Synology disk info (if advertised)';lin_menu_item 7 'Shared folder size (on demand)';lin_menu_item 8 'Recent filesystem/storage errors';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) syn_run df -h || true;syn_run df -i || true ;;
            2) syn_run mount || true;syn_run lsblk || true ;;
            3) if [[ -r /proc/mdstat ]]; then syn_emit "$(cat /proc/mdstat)";else syn_emit '[UNAVAILABLE] /proc/mdstat not readable.';fi
               device=$(syn_input 'Optional RAID device /dev/mdN (B skips details)') || continue
               [[ $device =~ ^/dev/md[0-9]+$ ]] && syn_gated mdadm --detail "$device" || syn_emit '[UNAVAILABLE] Use a /dev/mdN device.' ;;
            4) device=$(syn_input 'Disk device under /dev (no options)') || continue
               [[ $device =~ ^/dev/[a-zA-Z0-9_/.-]+$ && $device != *'..'* ]] || { syn_emit '[UNAVAILABLE] Invalid device path.';continue; }
               syn_gated smartctl --all "$device" || true ;;
            5) syn_gated synostgpool --get || true ;;
            6) device=$(syn_input 'Disk device under /dev') || continue
               [[ $device =~ ^/dev/[a-zA-Z0-9_/.-]+$ && $device != *'..'* ]] && syn_gated synodisk --info "$device" || true ;;
            7) path=$(syn_input 'Exact absolute shared-folder path') || continue
               if syn_path "$path" && [[ -d $path ]] && lin_confirm 'Run potentially expensive folder-size scan now (20s timeout if available)?'; then syn_run du -sk "$path" || true;fi ;;
            8) syn_capture dmesg || true
               if [[ $SYN_STATE == OK ]]; then syn_emit "$(grep -iE 'error|fail|I/O|btrfs|ext4|raid|degrad' <<<"$SYN_OUT" | tail -n 60)";else syn_emit "[$SYN_STATE] Kernel log access failed.";fi ;;
            *) continue ;;
        esac
        lin_pause
    done
}
syn_shares_menu() {
    local choice path
    while true; do
        lin_header 'Synology > Shared folders'
        lin_menu_item 1 'Effective share paths and safe Samba settings';lin_menu_item 2 'Native share enumeration (if advertised)'
        lin_menu_item 3 'Find containing share, root ownership and ACL';lin_menu_item 4 'Selected share configuration (if advertised)';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;; 1) syn_smb_config || true ;; 2) if syn_supports synoshare --enum && syn_supports synoshare ALL;then syn_run synoshare --enum ALL || true;else syn_emit '[UNAVAILABLE] Native ALL-share enumeration syntax not advertised.';fi ;;
            3) path=$(syn_input 'Absolute file path') || continue
               if syn_share_root "$path"; then syn_emit "Containing share: $SYN_SHARE_NAME | $SYN_SHARE_ROOT";syn_acl_get "$SYN_SHARE_ROOT" || true
               else syn_emit '[UNAVAILABLE] Containing share could not be resolved from literal effective paths.';fi ;;
            4) path=$(syn_input 'Share name') || continue;syn_identity_arg "$path" && syn_gated synoshare --get "$path" || true ;;
            *) continue ;;
        esac
        syn_emit '[TODO] Verify Advanced Share Permissions in DSM: Control Panel > Shared Folder > Edit > Advanced Permissions. Filesystem ACL alone does not establish SMB access.'
        lin_pause
    done
}
syn_network_menu() {
    local choice host
    while true; do
        lin_header 'Synology > System and network'
        lin_menu_item 1 'CPU / memory / load / processes';lin_menu_item 2 'Interfaces / IPs / routes / neighbours'
        lin_menu_item 3 'Listening ports';lin_menu_item 4 'DNS lookup';lin_menu_item 5 'Active connections';lin_menu_item 6 'Recent errors';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) lin_check_resources; syn_run uptime || true ;;
            2) if syn_resolve ip >/dev/null;then syn_run ip address show || true;syn_run ip route show || true;syn_run ip neigh show || true
               else syn_run ifconfig || true;syn_run route -n || true;syn_run arp -n || true;fi ;;
            3) syn_connections ;;
            4) host=$(syn_input 'DNS name or IP') || continue
               [[ $host =~ ^[a-zA-Z0-9][a-zA-Z0-9:._-]*$ ]] && syn_run nslookup "$host" || syn_emit '[UNAVAILABLE] Lookup failed or unsupported name.' ;;
            5) if syn_resolve ss >/dev/null;then syn_run ss -ntup || true;else syn_run netstat -ntp || true;fi ;;
            6) syn_logs ;; *) continue ;;
        esac
        lin_pause
    done
}
syn_guided() {
    local path=$1 user=$2 parent root='' object acl_out checks='' owner
    syn_path "$path" && [[ -f $path && ! -L $path ]] && syn_identity_arg "$user" || { syn_emit '[UNAVAILABLE] Existing real file and valid user required.';return 1; }
    parent=$(dirname -- "$path")
    syn_emit '=================================================='
    syn_emit 'FILE READ-ONLY DIAGNOSTIC REPORT'
    syn_emit "Target: $path | User: $user"
    if syn_identity "$user";then checks+='[OK] User and memberships resolved'$'\n';else checks+='[FAILED] Identity lookup incomplete; not evidence of a deleted account'$'\n';fi
    if syn_share_root "$path";then root=$SYN_SHARE_ROOT;checks+="[INFO] Containing share: $SYN_SHARE_NAME ($root)"$'\n';else checks+='[UNAVAILABLE] Containing share not resolved'$'\n';fi
    for object in "$root" "$parent" "$path"; do
        [[ -n $object ]] || continue
        if syn_acl_get "$object";then
            if [[ $SYN_OUT == *'user::'* || $SYN_OUT == *'group::'* ]];then checks+="[INFO] Unresolved ACL identity at $object (not automatically a problem)"$'\n';fi
        else checks+="[FAILED] ACL/ownership unavailable: $object"$'\n';fi
        if syn_acl_effective "$object" "$user";then
            if [[ ${SYN_EFFECTIVE:1:1} == w ]];then checks+="[OK] Effective filesystem ACL grants write: $object"$'\n'
            else checks+="[REVIEW] Effective filesystem ACL does not grant write: $object"$'\n';fi
        else checks+="[UNAVAILABLE] Effective ACL: $object ($SYN_EFFECTIVE_STATE)"$'\n';fi
    done
    syn_smb_search "$path" || checks+='[FAILED] SMB handle lookup incomplete'$'\n'
    owner=$parent/'~$'${path##*/}
    if [[ -f $owner && ! -L $owner ]];then checks+="[REVIEW] Apparent Office owner file: $owner"$'\n';syn_owner_inspect "$owner" || true
    else checks+='[INFO] No owner file at the literal ~$ name; truncated/renamed Office owner files may still exist'$'\n';fi
    checks+='[TODO] Verify Advanced Share Permissions in DSM; not verified by filesystem ACL'$'\n'
    checks+='[TODO] Review parent/child inheritance evidence; differences alone are not an error'$'\n'
    checks+='[TODO] Verify Windows read-only attributes and actual create/modify/rename/delete as the affected user'$'\n'
    checks+='Assessment: findings are snapshots. Suspected causes remain unconfirmed; ACL checks do not establish end-to-end SMB access.'$'\n'
    SYN_LAST_GUIDED="Target: $path"$'\n'"User: $user"$'\n'"$checks"
    syn_emit "$checks"
    printf '%s\n' 'Windows: Get-SmbConnection | Format-Table ServerName,ShareName,UserName,Credential'
    syn_emit 'Windows: Get-Item "\\NAS\Share\document.xlsx" | Select-Object Name,Attributes,IsReadOnly'
    syn_emit 'Do not export authentication tokens, passwords or private configuration. No original document has been modified.'
}
synology_menu() {
    local choice path user
    if ! syn_is_dsm;then syn_emit '[UNAVAILABLE] Synology DSM was not detected. Generic Linux checks remain available from the main menu.';lin_pause;return 0;fi
    while true;do
        lin_header 'Synology NAS Troubleshooting'
        lin_menu_item 1 'System information and compatibility';lin_menu_item 2 'SMB sessions and file locks';lin_menu_item 3 'ACL and effective permissions'
        lin_menu_item 4 'Office file lock troubleshooting';lin_menu_item 5 'Users and groups';lin_menu_item 6 'Shared folders'
        lin_menu_item 7 'Storage and disk diagnostics';lin_menu_item 8 'Services and packages';lin_menu_item 9 'System and network diagnostics'
        lin_menu_item 10 'Troubleshoot file opening in read-only mode';lin_menu_item 11 'Export diagnostic snapshot';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;1) syn_info;lin_pause;;2) syn_smb_menu;;3) syn_acl_menu;;4) syn_office_menu;;5) syn_identity_menu;;6) syn_shares_menu;;7) syn_storage_menu;;8) syn_services_menu;;9) syn_network_menu;;
            10) path=$(syn_input 'Affected absolute file path') || continue;user=$(syn_input 'Affected local or DOMAIN\user') || continue;syn_guided "$path" "$user";lin_pause;;
            11) syn_export;lin_pause;;*) lin_warn 'Choose 0-11.';;
        esac
    done
}
# END SYNOLOGYDIAGNOSTICS

# BEGIN MENU
lin_list_checks() {
    cat <<'EOF'
synology     Synology DSM system/command compatibility (read-only)
health       Combined health summary with measured thresholds
system       System and user summary
resources    CPU, memory, and resource-heavy processes
storage      Friendly filesystem, capacity, and inode summary
network      Friendly connection and listening-service summary
services     Friendly failed-service and recent-log summary
security     Firewall, SSH, and mandatory-access-control status
updates      Friendly available-update summary using existing metadata
applications Apache, Nginx, PostgreSQL, TLS, and container overview
apache       Apache settings and virtual-host summary
nginx        Nginx settings and safe directive summary
postgres     PostgreSQL readiness and selected effective settings
tls          Referenced TLS certificate expiry
containers   Docker and Podman health, inventory, and disk use
sysinternals Sysinternals ports and native Linux equivalent overview
processes    Process Explorer-style process summary
connections TCPView-style socket and connection summary
handles      Handle-style open-file summary
tracing      ProcMon-style tracing-tool readiness
autoruns     Autoruns-style services, timers, and cron summary
memorymaps   VMMap-style process memory summary
dumps        ProcDump-style dump-tool readiness
EOF
}

lin_run_raw_check() {
    case ${1:-} in
        storage) lin_raw_storage ;;
        network) lin_raw_network ;;
        services) lin_raw_services ;;
        updates) lin_raw_updates ;;
        apache) lin_raw_apache ;;
        nginx) lin_raw_nginx ;;
        postgres) lin_raw_postgres ;;
        containers) lin_raw_containers ;;
        sysinternals) lin_raw_sysinternals ;;
        processes) lin_raw_processes ;;
        connections) lin_raw_connections ;;
        handles) lin_raw_handles ;;
        autoruns) lin_raw_autoruns ;;
        memorymaps) lin_raw_memorymaps ;;
        *) lin_error "Raw evidence is not defined for check: ${1:-<blank>}"; return 2 ;;
    esac
}

lin_run_check() {
    if [[ ${LIN_RAW:-0} == 1 ]]; then lin_run_raw_check "$1"; return; fi
    case ${1:-} in
        synology) syn_info ;;
        health) lin_check_health ;;
        system) lin_check_system ;;
        resources) lin_check_resources ;;
        storage) lin_check_storage ;;
        network) lin_check_network ;;
        services) lin_check_services ;;
        security) lin_check_security ;;
        updates) lin_check_updates ;;
        applications) lin_check_applications ;;
        apache) lin_check_apache ;;
        nginx) lin_check_nginx ;;
        postgres) lin_check_postgres ;;
        tls) lin_check_tls ;;
        containers) lin_check_containers ;;
        sysinternals) lin_check_sysinternals ;;
        processes) lin_check_processes ;;
        connections) lin_check_connections ;;
        handles) lin_check_handles ;;
        tracing) lin_check_tracing ;;
        autoruns) lin_check_autoruns ;;
        memorymaps) lin_check_memorymaps ;;
        dumps) lin_check_dumps ;;
        *) lin_error "Unknown check: ${1:-<blank>}"; printf 'Available checks:\n'; lin_list_checks; return 2 ;;
    esac
}

lin_show_check() {
    local id=$1 choice
    lin_run_check "$id"
    case $id in
        storage|network|services|updates|apache|nginx|postgres|sysinternals|processes|connections|handles|autoruns|memorymaps)
            choice=$(lin_read 'R: raw evidence | Enter/B: back: ') || return 0
            if [[ ${choice^^} == R ]]; then LIN_RAW=1 lin_run_check "$id"; lin_pause; fi
            ;;
        containers)
            choice=$(lin_read 'D: container details | R: raw evidence | Enter/B: back: ') || return 0
            case ${choice^^} in
                D) lin_container_details; lin_pause ;;
                R) LIN_RAW=1 lin_run_check "$id"; lin_pause ;;
            esac
            ;;
        *) lin_pause ;;
    esac
}

lin_main_menu() {
    while true; do
        lin_header 'Main menu'
        lin_menu_item '1' 'Health summary'
        lin_menu_item '2' 'System and user summary'
        lin_menu_item '3' 'CPU, memory, and heavy processes'
        lin_menu_item '4' 'Storage summary'
        lin_menu_item '5' 'Network summary'
        lin_menu_item '6' 'Services and logs summary'
        lin_menu_item '7' 'Firewall and SSH inspection'
        lin_menu_item '8' 'Available updates summary'
        lin_menu_item '9' 'Application services (Apache, Nginx, PostgreSQL, TLS)'
        lin_menu_item '10' 'Docker and Podman inventory'
        lin_menu_item '11' 'Sysinternals-style Linux tools'
        lin_menu_item '12' 'Maintenance actions [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item '13' 'Synology NAS Troubleshooting'
        lin_menu_item 'Q' 'Quit' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_show_check health ;;
            2) lin_show_check system ;;
            3) lin_show_check resources ;;
            4) lin_show_check storage ;;
            5) lin_show_check network ;;
            6) lin_show_check services ;;
            7) lin_show_check security ;;
            8) lin_show_check updates ;;
            9) lin_application_menu ;;
            10) lin_show_check containers ;;
            11) lin_sysinternals_menu ;;
            12) lin_maintenance_menu ;;
            13) synology_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-13 or Q.' ;;
        esac
    done
}

lin_usage() {
    cat <<EOF
Linux Toolkit $LIN_TOOLKIT_VERSION

Usage:
  Linux-Toolkit.sh                 Open the interactive menu
  Linux-Toolkit.sh --list          List command-line checks
  Linux-Toolkit.sh --check ID      Run one friendly read-only check
  Linux-Toolkit.sh --check ID --raw
                                   Show underlying command output when supported
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
        --check)
            [[ -n ${2:-} ]] || { lin_error '--check requires an ID.'; return 2; }
            if [[ -n ${3:-} && ${3:-} != --raw ]]; then lin_error "Unknown --check option: $3"; return 2; fi
            [[ ${3:-} == --raw ]] && LIN_RAW=1
            lin_run_check "$2"
            ;;
        --no-color) NO_COLOR=1; lin_setup_colors; lin_main_menu ;;
        '') lin_main_menu ;;
        *) lin_error "Unknown argument: $1"; lin_usage; return 2 ;;
    esac
}
# END MENU

if [[ -z ${BASH_SOURCE[0]:-} || ${BASH_SOURCE[0]} == "$0" ]]; then lin_main "$@"; fi
