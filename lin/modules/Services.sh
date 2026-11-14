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
