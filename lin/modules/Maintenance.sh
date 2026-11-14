lin_restart_service() {
    lin_header 'Restart a service [CHANGES SYSTEM]'
    lin_require_root || return 1
    if ! lin_has systemctl || [[ ! -d /run/systemd/system ]]; then lin_error 'An active systemd installation is required.'; return 1; fi
    local service
    service=$(lin_read 'Service unit name (for example, sshd.service; B to cancel): ') || return 1
    [[ ${service^^} == B ]] && return 0
    if [[ ! $service =~ ^[A-Za-z0-9_.@:-]+(\.service)?$ ]]; then lin_error 'Invalid service unit name.'; return 1; fi
    [[ $service == *.service ]] || service="${service}.service"
    if [[ $(systemctl show "$service" -p LoadState --value 2>/dev/null) != loaded ]]; then lin_error "Service is not loaded: $service"; return 1; fi
    systemctl status "$service" --no-pager --lines=8 || true
    printf '\nThis interrupts the selected service and may disconnect users or applications.\n'
    lin_confirm "Restart only $service?" || { printf 'Cancelled.\n'; return 0; }
    systemctl restart "$service"
    systemctl is-active "$service" --quiet || { lin_error 'The service is not active after restart.'; systemctl status "$service" --no-pager --lines=20 || true; return 1; }
    printf '%sService restarted and verified active: %s%s\n' "$LIN_GREEN" "$service" "$LIN_RESET"
}

lin_clean_package_cache() {
    lin_header 'Clear package cache [CHANGES SYSTEM]'
    lin_require_root || return 1
    local manager
    manager=$(lin_package_manager) || { lin_error 'No supported package manager was found.'; return 1; }
    lin_field 'Package manager' "$manager"
    printf 'This removes cached package downloads. Installed packages and repository configuration are not removed.\n'
    lin_confirm "Clear the $manager package cache?" || { printf 'Cancelled.\n'; return 0; }
    case $manager in
        apt-get) apt-get clean ;;
        dnf) dnf clean packages ;;
        yum) yum clean packages ;;
        zypper) zypper --non-interactive clean --all ;;
        pacman) pacman -Sc --noconfirm ;;
        apk) rm -f /var/cache/apk/*.apk ;;
    esac
    printf '%sPackage cache cleanup completed.%s\n' "$LIN_GREEN" "$LIN_RESET"
}

lin_maintenance_menu() {
    while true; do
        lin_header 'Maintenance [CHANGES SYSTEM]'
        lin_menu_item '1' 'Restart one loaded systemd service [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item '2' 'Clear the detected package-manager cache [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 'B' 'Back' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_restart_service; lin_pause ;;
            2) lin_clean_package_cache; lin_pause ;;
            B|0) return 0 ;;
            *) lin_warn 'Choose 1, 2, or B.' ;;
        esac
    done
}
