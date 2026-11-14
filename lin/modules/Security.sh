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
