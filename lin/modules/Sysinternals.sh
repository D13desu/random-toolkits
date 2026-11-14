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
