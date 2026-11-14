#!/usr/bin/env bash
# Random Toolkits | Linux Toolkit 0.3.0
# Generated from lin/modules/*.sh by tests/Sync-LinuxToolkit.ps1.
set -o pipefail
LIN_TOOLKIT_VERSION='0.3.0'

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

# BEGIN MENU
lin_list_checks() {
    cat <<'EOF'
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
        *) lin_error "Raw evidence is not defined for check: ${1:-<blank>}"; return 2 ;;
    esac
}

lin_run_check() {
    if [[ ${LIN_RAW:-0} == 1 ]]; then lin_run_raw_check "$1"; return; fi
    case ${1:-} in
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
        *) lin_error "Unknown check: ${1:-<blank>}"; printf 'Available checks:\n'; lin_list_checks; return 2 ;;
    esac
}

lin_show_check() {
    local id=$1 choice
    lin_run_check "$id"
    case $id in
        storage|network|services|updates|apache|nginx|postgres)
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
        lin_menu_item '11' 'Maintenance actions [CHANGES SYSTEM]' "$LIN_YELLOW"
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
            11) lin_maintenance_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-11 or Q.' ;;
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
