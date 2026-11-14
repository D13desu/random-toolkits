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
