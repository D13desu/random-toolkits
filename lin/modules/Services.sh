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
