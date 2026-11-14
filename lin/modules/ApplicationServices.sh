lin_service_running() {
    local name
    if lin_has systemctl && [[ -d /run/systemd/system ]]; then
        for name in "$@"; do systemctl is-active "$name" --quiet 2>/dev/null && return 0; done
    fi
    for name in "$@"; do pgrep -x "$name" >/dev/null 2>&1 && return 0; done
    return 1
}

lin_apache_command() {
    local command
    for command in apache2ctl apachectl httpd; do lin_has "$command" && { printf '%s' "$command"; return 0; }; done
    return 1
}

lin_apache_summary() {
    local command version config status detail
    command=$(lin_apache_command) || { printf 'UNAVAILABLE\tNot installed'; return 0; }
    version=$($command -v 2>/dev/null | awk -F': ' '/Server version/ {print $2; exit}')
    config=$($command configtest 2>&1); status='OK'
    if [[ $? -ne 0 ]]; then status='WARNING'; detail="config test failed"
    elif ! lin_service_running apache2 httpd; then status='REVIEW'; detail='config syntax OK; service not detected running'
    else detail='running; config syntax OK'; fi
    printf '%s\t%s%s' "$status" "${version:-Apache}" " | $detail"
}

lin_check_apache() {
    lin_header 'Apache summary'
    local command summary status detail sites=0 modules=0 vhosts
    command=$(lin_apache_command) || { lin_status_row 'UNAVAILABLE' 'Apache' 'Not installed'; return 0; }
    summary=$(lin_apache_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'Apache' "$detail"
    [[ -d /etc/apache2/sites-enabled ]] && sites=$(find /etc/apache2/sites-enabled -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | awk 'NF {count++} END {print count+0}')
    modules=$($command -M 2>/dev/null | awk '/_module/ {count++} END {print count+0}')
    lin_field 'Enabled sites' "$sites"
    lin_field 'Loaded modules' "$modules"
    lin_section 'Virtual hosts (bounded)'
    vhosts=$($command -S 2>&1 || true)
    if [[ -n $vhosts ]]; then printf '%s\n' "$vhosts" | grep -E '(^VirtualHost|namevhost|default server|port [0-9]+)' | head -n 15 | while IFS= read -r line; do printf '  %s\n' "$(lin_truncate "$line" 110)"; done
    else lin_warn 'Virtual-host information is unavailable.'; fi
    lin_raw_hint apache
}

lin_raw_apache() {
    lin_header 'Apache raw evidence'
    local command
    command=$(lin_apache_command) || { lin_warn 'Apache is not installed.'; return 0; }
    lin_section 'Version'; $command -v 2>&1 || true
    lin_section 'Configuration test'; $command configtest 2>&1 || true
    lin_section 'Virtual hosts'; $command -S 2>&1 || true
    lin_section 'Loaded modules'; $command -M 2>&1 || true
}

lin_nginx_summary() {
    local version config status detail
    lin_has nginx || { printf 'UNAVAILABLE\tNot installed'; return 0; }
    version=$(nginx -v 2>&1 | sed 's|.*/||')
    config=$(nginx -t 2>&1); status='OK'
    if [[ $? -ne 0 ]]; then
        if grep -qiE 'permission denied|operation not permitted' <<<"$config"; then status='UNAVAILABLE'; detail='config test needs additional access'
        else status='WARNING'; detail='config test failed'; fi
    elif ! lin_service_running nginx; then status='REVIEW'; detail='config syntax OK; service not detected running'
    else detail='running; config syntax OK'; fi
    printf '%s\tnginx %s | %s' "$status" "${version:-unknown}" "$detail"
}

lin_nginx_config_files() {
    [[ -d /etc/nginx ]] || return 0
    find /etc/nginx \( -type f -o -type l \) \( -name '*.conf' -o -path '*/sites-enabled/*' \) 2>/dev/null | sort -u
}

lin_check_nginx() {
    lin_header 'Nginx summary'
    local summary status detail files highlights count
    summary=$(lin_nginx_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'Nginx' "$detail"
    [[ $detail == 'Not installed' ]] && return 0
    files=$(lin_nginx_config_files); count=$(awk 'NF {count++} END {print count+0}' <<<"$files")
    lin_field 'Configuration files' "$count readable file(s)"
    lin_section 'Operational directives (values only; secrets excluded)'
    highlights=''
    while IFS= read -r file; do
        [[ -r $file ]] || continue
        while IFS= read -r line; do highlights+="$(lin_truncate "$line" 105)"$'\n'; done < <(grep -Eh '^[[:space:]]*(listen|server_name|root|proxy_pass|upstream|ssl_certificate)[[:space:]]' "$file" 2>/dev/null | grep -Ev 'ssl_certificate_key|password|secret|token')
    done <<<"$files"
    if [[ -n $highlights ]]; then printf '%s' "$highlights" | sed '/^[[:space:]]*$/d' | sort -u | head -n 25 | sed 's/^/  /'; else lin_warn 'No readable operational directives were found.'; fi
    lin_raw_hint nginx
}

lin_raw_nginx() {
    lin_header 'Nginx bounded raw evidence'
    lin_has nginx || { lin_warn 'Nginx is not installed.'; return 0; }
    lin_section 'Version and build'; nginx -V 2>&1 || true
    lin_section 'Configuration test'; nginx -t 2>&1 || true
    lin_section 'Configuration files'; lin_nginx_config_files
    printf '\nThe complete nginx -T dump is intentionally excluded because configuration may contain credentials.\n'
}

lin_postgres_summary() {
    local version ready status detail
    lin_has psql || { printf 'UNAVAILABLE\tClient not installed'; return 0; }
    version=$(psql --version 2>/dev/null | sed 's/^psql (PostgreSQL) //')
    if lin_has pg_isready; then
        ready=$(pg_isready -t 3 2>&1)
        if [[ $? -eq 0 ]]; then status='OK'; detail="$ready"
        else status='REVIEW'; detail="$ready"; fi
    elif lin_service_running postgresql postgres; then status='INFO'; detail='service detected; pg_isready unavailable'
    else status='REVIEW'; detail='client installed; server readiness unavailable'; fi
    printf '%s\tPostgreSQL %s | %s' "$status" "${version:-unknown}" "$detail"
}

lin_postgres_settings() {
    PGCONNECT_TIMEOUT=3 psql -X -w -A -t -F $'\t' -c "SELECT name, setting || COALESCE(unit, '') FROM pg_settings WHERE name IN ('config_file','hba_file','port','listen_addresses','ssl','max_connections','shared_buffers','work_mem','log_destination','logging_collector') ORDER BY name" 2>/dev/null
}

lin_check_postgres() {
    lin_header 'PostgreSQL summary'
    local summary status detail settings clusters databases
    summary=$(lin_postgres_summary); IFS=$'\t' read -r status detail <<<"$summary"
    lin_status_row "$status" 'PostgreSQL' "$detail"
    [[ $detail == 'Client not installed' ]] && return 0
    if lin_has pg_lsclusters; then
        clusters=$(pg_lsclusters --no-header 2>/dev/null || true)
        lin_section 'Detected clusters'
        if [[ -n $clusters ]]; then printf '%s\n' "$clusters" | head -n 10 | sed 's/^/  /'; else printf '  None detected.\n'; fi
    fi
    settings=$(lin_postgres_settings || true)
    lin_section 'Effective settings'
    if [[ -n $settings ]]; then
        while IFS=$'\t' read -r name value; do lin_field "$name" "$value"; done <<<"$settings"
        databases=$(PGCONNECT_TIMEOUT=3 psql -X -w -A -t -F $'\t' -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datallowconn ORDER BY pg_database_size(datname) DESC LIMIT 10" 2>/dev/null || true)
        if [[ -n $databases ]]; then lin_section 'Largest databases'; while IFS=$'\t' read -r name size; do printf '  %-36s %s\n' "$(lin_truncate "$name" 36)" "$size"; done <<<"$databases"; fi
    else
        lin_status_row 'UNAVAILABLE' 'Authenticated settings' 'Local connection unavailable; no password was requested'
    fi
    lin_raw_hint postgres
}

lin_raw_postgres() {
    lin_header 'PostgreSQL bounded raw evidence'
    lin_has psql || { lin_warn 'PostgreSQL client is not installed.'; return 0; }
    lin_section 'Client version'; psql --version
    if lin_has pg_isready; then lin_section 'Readiness'; pg_isready -t 3 2>&1 || true; fi
    if lin_has pg_lsclusters; then lin_section 'Clusters'; pg_lsclusters 2>&1 || true; fi
    lin_section 'Safe pg_settings selection'; lin_postgres_settings || lin_warn 'Authentication is required; no password was requested.'
}

lin_referenced_certificates() {
    local directory
    for directory in /etc/nginx /etc/apache2 /etc/httpd; do
        [[ -d $directory ]] || continue
        grep -RhsE '^[[:space:]]*(ssl_certificate|SSLCertificateFile)[[:space:]]+' "$directory" 2>/dev/null |
            grep -Ev 'ssl_certificate_key' |
            sed -E 's/^[[:space:]]*(ssl_certificate|SSLCertificateFile)[[:space:]]+//; s/[;[:space:]]+$//; s/^"|"$//'
    done
    if [[ -d /etc/letsencrypt/live ]]; then find /etc/letsencrypt/live -maxdepth 2 -name fullchain.pem 2>/dev/null; fi
}

lin_tls_days_status() {
    local days=${1:-99999}
    if (( days < 0 )); then printf 'WARNING'
    elif (( days <= 30 )); then printf 'REVIEW'
    else printf 'OK'; fi
}

lin_check_tls() {
    lin_header 'Referenced TLS certificates'
    lin_has openssl || { lin_status_row 'UNAVAILABLE' 'OpenSSL' 'Not installed'; return 0; }
    local paths path end_text end_epoch now days status subject count=0
    paths=$(lin_referenced_certificates | sed '/^[[:space:]]*$/d' | sort -u)
    [[ -n $paths ]] || { lin_status_row 'UNAVAILABLE' 'Certificates' 'No referenced certificate files were found'; return 0; }
    printf '%-8s %8s %-42s %s\n' 'Status' 'Days' 'Certificate' 'Subject'
    while IFS= read -r path; do
        [[ $path == /* && -r $path ]] || { lin_status_row 'UNAVAILABLE' "$(lin_truncate "$path" 24)" 'Unreadable or variable-based path'; continue; }
        end_text=$(openssl x509 -in "$path" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
        subject=$(openssl x509 -in "$path" -noout -subject 2>/dev/null | sed 's/^subject=//')
        end_epoch=$(date -d "$end_text" +%s 2>/dev/null || printf '')
        if [[ -n $end_epoch ]]; then now=$(date +%s); days=$(( (end_epoch-now)/86400 )); status=$(lin_tls_days_status "$days")
        else days='?'; status='UNAVAILABLE'; fi
        printf '%s%-8s%s %8s %-42s %s\n' "$(lin_status_color "$status")" "$status" "$LIN_RESET" "$days" "$(lin_truncate "$path" 42)" "$(lin_truncate "$subject" 45)"
        ((count+=1))
    done <<<"$paths"
    lin_field 'Certificates inspected' "$count"
}

lin_check_applications() {
    lin_header 'Application services summary'
    local summary status detail certificates
    summary=$(lin_apache_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Apache' "$detail"
    summary=$(lin_nginx_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Nginx' "$detail"
    summary=$(lin_postgres_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'PostgreSQL' "$detail"
    certificates=$(lin_referenced_certificates | sed '/^[[:space:]]*$/d' | sort -u | awk 'NF {count++} END {print count+0}')
    if (( certificates )); then lin_status_row 'INFO' 'TLS certificates' "$certificates referenced file(s)"; else lin_status_row 'UNAVAILABLE' 'TLS certificates' 'No references found'; fi
    summary=$(lin_container_summary); IFS=$'\t' read -r status detail <<<"$summary"; lin_status_row "$status" 'Containers' "$detail"
}

lin_application_menu() {
    while true; do
        lin_header 'Application services'
        lin_menu_item '1' 'Combined application summary'
        lin_menu_item '2' 'Apache settings and virtual hosts'
        lin_menu_item '3' 'Nginx settings and server directives'
        lin_menu_item '4' 'PostgreSQL readiness and settings'
        lin_menu_item '5' 'Referenced TLS certificate expiry'
        lin_menu_item 'B' 'Back' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_show_check applications ;;
            2) lin_show_check apache ;;
            3) lin_show_check nginx ;;
            4) lin_show_check postgres ;;
            5) lin_show_check tls ;;
            B|0) return 0 ;;
            *) lin_warn 'Choose 1-5 or B.' ;;
        esac
    done
}
