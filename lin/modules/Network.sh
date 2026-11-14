lin_listener_rows() {
    lin_has ss || return 1
    local proto state recv send local_endpoint peer process address exposure status
    while read -r proto state recv send local_endpoint peer process; do
        [[ -n $local_endpoint ]] || continue
        address=${local_endpoint%:*}
        case $address in
            127.*|'[::1]'|::1|localhost) exposure='Local only'; status='OK' ;;
            0.0.0.0|'[::]'|::|'*') exposure='All interfaces'; status='REVIEW' ;;
            *) exposure='Specific address'; status='REVIEW' ;;
        esac
        process=${process:-Unavailable}
        process=${process#users:((}
        process=${process%%,*}
        process=${process//\"/}
        printf '%s\t%s\t%s\t%s\t%s\n' "$proto" "$local_endpoint" "$process" "$exposure" "$status"
    done < <(ss -H -lntup 2>/dev/null || ss -H -lntu 2>/dev/null)
}

lin_public_listener_count() {
    lin_listener_rows 2>/dev/null | awk -F'\t' '$4 != "Local only" {count++} END {print count+0}'
}

lin_check_network() {
    lin_header 'Network summary'
    local interface='Unavailable' gateway='Unavailable' address='Unavailable' state='Unavailable' speed='Unavailable'
    if lin_has ip; then
        local default_route
        default_route=$(ip route show default 2>/dev/null | head -n 1)
        interface=$(awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}' <<<"$default_route")
        gateway=$(awk '{for(i=1;i<=NF;i++) if($i=="via"){print $(i+1);exit}}' <<<"$default_route")
        [[ -n $interface ]] || interface='Unavailable'
        [[ -n $gateway ]] || gateway='Direct / unavailable'
        if [[ $interface != Unavailable ]]; then
            address=$(ip -o -4 address show dev "$interface" scope global 2>/dev/null | awk 'NR == 1 {print $4}')
            [[ -n $address ]] || address='No global IPv4 address'
            [[ -r /sys/class/net/$interface/operstate ]] && state=$(<"/sys/class/net/$interface/operstate")
            if [[ -r /sys/class/net/$interface/speed ]]; then speed="$(<"/sys/class/net/$interface/speed") Mbps"; fi
        fi
    fi

    lin_section 'Primary connection'
    lin_field 'Interface' "$interface"
    lin_field 'IPv4 address' "$address"
    lin_field 'Gateway' "$gateway"
    lin_field 'Link state' "$state"
    lin_field 'Link speed' "$speed"
    local dns
    dns=$(awk '/^nameserver[ \t]+/ {printf "%s%s", separator, $2; separator=", "}' /etc/resolv.conf 2>/dev/null)
    lin_field 'DNS servers' "${dns:-Unavailable}"

    lin_section 'Listening services'
    local rows local_count public_count
    rows=$(lin_listener_rows 2>/dev/null) || rows=''
    local_count=$(awk -F'\t' '$4 == "Local only" {count++} END {print count+0}' <<<"$rows")
    public_count=$(awk -F'\t' '$4 != "Local only" && NF {count++} END {print count+0}' <<<"$rows")
    lin_status_row 'OK' 'Local-only listeners' "$local_count"
    if (( public_count )); then lin_status_row 'REVIEW' 'Non-local listeners' "$public_count"; else lin_status_row 'OK' 'Non-local listeners' '0'; fi

    if [[ -n $rows ]]; then
        printf '\n%-6s %-28s %-18s %-18s %s\n' 'Proto' 'Endpoint' 'Process' 'Exposure' 'Status'
        while IFS=$'\t' read -r proto local_endpoint process exposure status; do
            printf '%-6s %-28s %-18s %-18s %s%s%s\n' "$proto" "$(lin_truncate "$local_endpoint" 28)" "$(lin_truncate "$process" 18)" "$exposure" "$(lin_status_color "$status")" "$status" "$LIN_RESET"
        done <<<"$rows"
    else
        lin_warn 'Listening socket details are unavailable; install iproute2/ss for this view.'
    fi
    printf '\nREVIEW means the socket is bound beyond localhost; it does not prove firewall reachability.\n'
    lin_raw_hint network
}

lin_raw_network() {
    lin_header 'Network raw evidence'
    if lin_has ip; then lin_section 'ip -brief address'; ip -brief address; lin_section 'ip route'; ip route show; fi
    lin_section '/etc/resolv.conf'; cat /etc/resolv.conf 2>&1 || true
    if lin_has resolvectl; then lin_section 'resolvectl status'; resolvectl status 2>&1 || true; fi
    if lin_has ss; then lin_section 'ss -lntup'; ss -lntup 2>&1 || ss -lntu; fi
}
