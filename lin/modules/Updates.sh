lin_collect_updates() {
    local manager=${1:-}
    case $manager in
        apt-get)
            apt list --upgradable 2>/dev/null | awk 'NR > 1 && $1 ~ /\// {split($1,n,"/"); old=$NF; gsub(/^\[upgradable from: |\]$/, "", old); print n[1] "\t" $2 "\tfrom " old}' ;;
        dnf)
            dnf --cacheonly check-update 2>/dev/null | awk '$1 ~ /\./ && NF >= 3 {print $1 "\t" $2 "\t" $3}' ;;
        yum)
            yum -C check-update 2>/dev/null | awk '$1 ~ /\./ && NF >= 3 {print $1 "\t" $2 "\t" $3}' ;;
        zypper)
            zypper --non-interactive list-updates 2>/dev/null | awk -F'|' 'NF >= 6 && $1 ~ /v/ {for(i=2;i<=6;i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $3 "\t" $5 "\t" $2}' ;;
        pacman)
            pacman -Qu 2>/dev/null | awk 'NF >= 4 {print $1 "\t" $4 "\tfrom " $2}' ;;
        apk)
            apk version -l '<' 2>/dev/null | awk 'NF {print $1 "\tavailable\tupgrade"}' ;;
    esac
    return 0
}

lin_update_count() {
    local manager rows
    manager=$(lin_package_manager) || { printf '0'; return 0; }
    rows=$(lin_collect_updates "$manager")
    awk 'NF {count++} END {print count+0}' <<<"$rows"
}

lin_check_updates() {
    lin_header 'Available updates summary'
    local manager rows count shown=0 name version source
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
    rows=$(lin_collect_updates "$manager")
    count=$(awk 'NF {count++} END {print count+0}' <<<"$rows")
    lin_field 'Package manager' "$manager"
    if (( count )); then lin_status_row 'REVIEW' 'Available updates' "$count package(s)"; else lin_status_row 'OK' 'Available updates' 'None in current metadata'; fi
    printf 'Package metadata is not refreshed and no packages are installed.\n'

    if [[ -n $rows ]]; then
        printf '\n%-36s %-24s %s\n' 'Package' 'Available version' 'Context'
        while IFS=$'\t' read -r name version source; do
            (( shown+=1 ))
            (( shown > 20 )) && break
            printf '%-36s %-24s %s\n' "$(lin_truncate "$name" 36)" "$(lin_truncate "$version" 24)" "$(lin_truncate "$source" 35)"
        done <<<"$rows"
        (( count > 20 )) && printf '... and %d more package(s).\n' "$((count-20))"
    fi
    lin_raw_hint updates
}

lin_raw_updates() {
    lin_header 'Available updates raw evidence'
    local manager
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
    case $manager in
        apt-get) apt list --upgradable 2>/dev/null || true ;;
        dnf) dnf --cacheonly check-update || [[ $? -eq 100 ]] ;;
        yum) yum -C check-update || [[ $? -eq 100 ]] ;;
        zypper) zypper --non-interactive list-updates ;;
        pacman) pacman -Qu || true ;;
        apk) apk version -l '<' ;;
    esac
}
