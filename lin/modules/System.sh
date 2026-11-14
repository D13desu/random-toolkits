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
