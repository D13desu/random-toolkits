lin_check_system() {
    lin_header 'System and user summary'
    printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf 'Unavailable')"
    printf 'Operating system: %s\n' "$(lin_os_release_value PRETTY_NAME)"
    printf 'Kernel: %s\n' "$(uname -srmo 2>/dev/null || uname -a)"
    printf 'Architecture: %s\n' "$(uname -m)"
    printf 'User: %s (uid %s)\n' "$(id -un)" "$(id -u)"
    printf 'Groups: %s\n' "$(id -Gn 2>/dev/null || printf 'Unavailable')"
    printf 'Shell: %s\n' "${SHELL:-Unknown}"
    printf 'Uptime: %s\n' "$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'Unavailable')"
    if [[ -r /proc/uptime ]]; then printf 'Boot time: %s\n' "$(uptime -s 2>/dev/null || printf 'Unavailable')"; fi
    if lin_has systemd-detect-virt; then printf 'Virtualization: %s\n' "$(systemd-detect-virt 2>/dev/null || printf 'none detected')"; fi
}

lin_check_resources() {
    lin_header 'CPU, memory, and processes'
    if lin_has lscpu; then lscpu | awk -F: '/^(Architecture|CPU\(s\)|Model name|Thread|Core|Socket|Virtualization):/ {gsub(/^[ \t]+/, "", $2); printf "%-20s %s\n", $1 ":", $2}'; else uname -m; fi
    printf '\nMemory:\n'
    if lin_has free; then free -h; elif [[ -r /proc/meminfo ]]; then head -n 8 /proc/meminfo; else lin_warn 'Memory information unavailable.'; fi
    printf '\nHighest CPU processes:\n'
    ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 11 || ps aux | head -n 11
    printf '\nHighest memory processes:\n'
    ps -eo pid,user,comm,%cpu,%mem --sort=-%mem 2>/dev/null | head -n 11 || true
}
