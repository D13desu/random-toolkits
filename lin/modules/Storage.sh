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
