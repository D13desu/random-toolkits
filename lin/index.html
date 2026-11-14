#!/usr/bin/env bash
# Random Toolkits | Linux Toolkit 0.2.0
# Generated from lin/modules/*.sh by tests/Sync-LinuxToolkit.ps1.
set -o pipefail
LIN_TOOLKIT_VERSION='0.2.0'

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

# BEGIN HEALTH
lin_check_health() {
    lin_header 'Health summary'
    local attention=0 load1 cores load_status memory_percent memory_status root_percent root_status failed updates firewall_status firewall_detail listeners containers=0

    read -r load1 _ </proc/loadavg 2>/dev/null || load1='Unavailable'
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
    load_status='INFO'
    if [[ $load1 =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v load="$load1" -v cores="$cores" 'BEGIN {exit !(load > cores)}'; then load_status='REVIEW'; ((attention+=1)); fi

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

    if lin_has docker; then containers=$(docker ps -q 2>/dev/null | awk 'NF {count++} END {print count+0}');
    elif lin_has podman; then containers=$(podman ps -q 2>/dev/null | awk 'NF {count++} END {print count+0}'); fi

    lin_status_row "$load_status" 'CPU load' "$load1 across $cores logical CPU(s)"
    lin_status_row "$memory_status" 'Memory' "$memory_percent% used"
    lin_status_row "$root_status" 'Root filesystem' "$root_percent% used"
    if (( failed )); then lin_status_row 'WARNING' 'Failed services' "$failed"; else lin_status_row 'OK' 'Failed services' '0'; fi
    if (( updates )); then lin_status_row 'REVIEW' 'Available updates' "$updates"; else lin_status_row 'OK' 'Available updates' '0 in existing metadata'; fi
    lin_status_row "$firewall_status" 'Firewall' "$firewall_detail"
    if (( listeners )); then lin_status_row 'REVIEW' 'Non-local listeners' "$listeners"; else lin_status_row 'OK' 'Non-local listeners' '0'; fi
    lin_status_row 'INFO' 'Running containers' "$containers"

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
containers   Docker and Podman inventory
EOF
}

lin_run_raw_check() {
    case ${1:-} in
        storage) lin_raw_storage ;;
        network) lin_raw_network ;;
        services) lin_raw_services ;;
        updates) lin_raw_updates ;;
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
        containers) lin_check_containers ;;
        *) lin_error "Unknown check: ${1:-<blank>}"; printf 'Available checks:\n'; lin_list_checks; return 2 ;;
    esac
}

lin_show_check() {
    local id=$1 choice
    lin_run_check "$id"
    case $id in
        storage|network|services|updates)
            choice=$(lin_read 'R: raw evidence | Enter/B: back: ') || return 0
            if [[ ${choice^^} == R ]]; then LIN_RAW=1 lin_run_check "$id"; lin_pause; fi
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
        lin_menu_item '9' 'Docker and Podman inventory'
        lin_menu_item '10' 'Maintenance actions [CHANGES SYSTEM]' "$LIN_YELLOW"
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
            9) lin_show_check containers ;;
            10) lin_maintenance_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-10 or Q.' ;;
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
