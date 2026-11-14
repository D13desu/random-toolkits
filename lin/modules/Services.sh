lin_check_services() {
    lin_header 'Services and recent logs'
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        printf 'Failed services:\n'
        systemctl --failed --no-pager --plain || true
        printf '\nRecently failed service units:\n'
        systemctl list-units --type=service --state=failed --no-pager --plain || true
    else
        lin_warn 'systemd is not the active service manager.'
        if lin_has rc-status; then rc-status --crashed 2>/dev/null || rc-status; fi
    fi
    printf '\nRecent boot warnings/errors (latest 50):\n'
    if lin_has journalctl && [[ -d /run/systemd/system ]]; then
        journalctl -b -p warning -n 50 --no-pager 2>&1 || lin_warn 'Journal access was denied or unavailable.'
    elif [[ -r /var/log/syslog ]]; then tail -n 50 /var/log/syslog
    elif [[ -r /var/log/messages ]]; then tail -n 50 /var/log/messages
    else lin_warn 'No supported readable system log was found.'
    fi
}
