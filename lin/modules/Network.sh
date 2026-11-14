lin_check_network() {
    lin_header 'Network configuration'
    if lin_has ip; then
        printf 'Addresses:\n'; ip -brief address
        printf '\nRoutes:\n'; ip route show
    elif lin_has ifconfig; then
        ifconfig
    else
        lin_warn 'Neither ip nor ifconfig is available.'
    fi
    printf '\nDNS configuration:\n'
    if lin_has resolvectl; then resolvectl status 2>/dev/null || true; elif [[ -r /etc/resolv.conf ]]; then cat /etc/resolv.conf; else lin_warn 'DNS configuration unavailable.'; fi
    printf '\nListening sockets:\n'
    if lin_has ss; then ss -lntup 2>/dev/null || ss -lntu; elif lin_has netstat; then netstat -lntup 2>/dev/null || netstat -lntu; else lin_warn 'Neither ss nor netstat is available.'; fi
}
