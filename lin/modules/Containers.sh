lin_container_engine() {
    if lin_has docker; then printf 'docker'; return 0; fi
    if lin_has podman; then printf 'podman'; return 0; fi
    return 1
}

lin_container_summary() {
    local engine rows running=0 stopped=0 unhealthy=0 restarting=0 name image state ports status
    engine=$(lin_container_engine) || { printf 'UNAVAILABLE\tDocker/Podman not installed'; return 0; }
    $engine info >/dev/null 2>&1 || { printf 'UNAVAILABLE\t%s installed; service unavailable or access denied' "$engine"; return 0; }
    rows=$(lin_container_rows "$engine") || { printf 'UNAVAILABLE\t%s inventory unavailable' "$engine"; return 0; }
    while IFS=$'\t' read -r name image state ports; do
        [[ -n $name ]] || continue
        if [[ $state == Up* ]]; then ((running+=1)); else ((stopped+=1)); fi
        [[ $state == *unhealthy* ]] && ((unhealthy+=1))
        [[ $state == Restarting* ]] && ((restarting+=1))
    done <<<"$rows"
    if (( unhealthy || restarting )); then status='WARNING'; elif (( stopped )); then status='REVIEW'; else status='OK'; fi
    printf '%s\t%s | %s running, %s stopped, %s unhealthy, %s restarting' "$status" "$engine" "$running" "$stopped" "$unhealthy" "$restarting"
}

lin_container_rows() {
    local engine=$1
    $engine ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
}

lin_check_containers() {
    lin_header 'Container summary'
    local engine rows running=0 stopped=0 unhealthy=0 restarting=0 total=0 name image state ports status
    local summary detail
    summary=$(lin_container_summary); IFS=$'\t' read -r status detail <<<"$summary"
    if [[ $status == UNAVAILABLE ]]; then lin_status_row "$status" 'Container engine' "$detail"; return 0; fi
    engine=$(lin_container_engine)
    lin_field 'Engine' "$engine"
    rows=$(lin_container_rows "$engine") || { lin_status_row 'UNAVAILABLE' 'Engine service' 'Installed but unavailable or access denied'; return 0; }
    while IFS=$'\t' read -r name image state ports; do
        [[ -n $name ]] || continue; ((total+=1))
        if [[ $state == Up* ]]; then ((running+=1)); else ((stopped+=1)); fi
        [[ $state == *unhealthy* ]] && ((unhealthy+=1))
        [[ $state == Restarting* ]] && ((restarting+=1))
    done <<<"$rows"
    lin_status_row "$status" 'Containers' "$running running | $stopped stopped | $unhealthy unhealthy | $restarting restarting"
    lin_field 'Networks' "$($engine network ls -q 2>/dev/null | awk 'NF {count++} END {print count+0}')"
    lin_field 'Volumes' "$($engine volume ls -q 2>/dev/null | awk 'NF {count++} END {print count+0}')"

    if [[ -n $rows ]]; then
        printf '\n%-24s %-28s %-26s %s\n' 'Name' 'Image' 'State / health' 'Published ports'
        while IFS=$'\t' read -r name image state ports; do
            printf '%-24s %-28s %-26s %s\n' "$(lin_truncate "$name" 24)" "$(lin_truncate "$image" 28)" "$(lin_truncate "$state" 26)" "$(lin_truncate "$ports" 45)"
        done <<<"$rows"
    fi

    lin_section 'Disk use'
    $engine system df 2>/dev/null | head -n 12 || lin_warn 'Container disk-use data is unavailable.'
    if [[ $engine == docker ]] && docker compose version >/dev/null 2>&1; then lin_section 'Compose projects'; docker compose ls 2>/dev/null || true; fi
    lin_raw_hint containers
}

lin_container_details() {
    local engine target exists env_lines
    engine=$(lin_container_engine) || { lin_warn 'Docker and Podman are not installed.'; return 0; }
    target=$(lin_read 'Container name or ID (B to cancel): ') || return 0
    [[ ${target^^} == B ]] && return 0
    [[ $target =~ ^[A-Za-z0-9_.-]+$ ]] || { lin_error 'Invalid container name or ID.'; return 1; }
    exists=$($engine ps -a --format '{{.ID}} {{.Names}}' 2>/dev/null | awk -v target="$target" '$1 == target || $2 == target || index($1,target) == 1 {print $1; exit}')
    [[ -n $exists ]] || { lin_error 'Container was not found.'; return 1; }
    lin_header "Container details: $target"
    $engine inspect --format $'Name:\t{{.Name}}\nImage:\t{{.Config.Image}}\nState:\t{{.State.Status}}\nHealth:\t{{if .State.Health}}{{.State.Health.Status}}{{else}}Not configured{{end}}\nRestart policy:\t{{.HostConfig.RestartPolicy.Name}}\nStarted:\t{{.State.StartedAt}}' "$exists" 2>/dev/null || true
    lin_section 'Published ports'; $engine port "$exists" 2>/dev/null || printf '  None.\n'
    lin_section 'Mounts'; $engine inspect --format '{{range .Mounts}}{{println .Type .Source "->" .Destination}}{{end}}' "$exists" 2>/dev/null || true
    lin_section 'Environment variables'
    env_lines=$($engine inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$exists" 2>/dev/null)
    if [[ -n $env_lines ]]; then printf '%s\n' "$env_lines" | sed 's/^/  /'; else printf '  None visible.\n'; fi
}

lin_raw_containers() {
    lin_header 'Container bounded raw evidence'
    local engine
    engine=$(lin_container_engine) || { lin_warn 'Docker and Podman are not installed.'; return 0; }
    lin_section "$engine ps -a"; $engine ps -a --no-trunc 2>&1 || true
    lin_section "$engine system df"; $engine system df 2>&1 || true
    lin_section 'Networks'; $engine network ls 2>&1 || true
    lin_section 'Volumes'; $engine volume ls 2>&1 || true
    printf '\nComplete inspect output is intentionally excluded; use selected-container details to view environment values.\n'
}
