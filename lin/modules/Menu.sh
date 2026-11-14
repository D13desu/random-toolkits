lin_list_checks() {
    cat <<'EOF'
health       Combined health summary with measured thresholds
system       System and user summary
resources    CPU, memory, and resource-heavy processes
storage      Friendly filesystem, capacity, and inode summary
network      Friendly connection and listening-service summary
services     Friendly failed-service and recent-log summary
security     Firewall, SSH, and mandatory-access-control status
updates      Friendly available-update summary using existing metadata
containers   Docker and Podman inventory
EOF
}

lin_run_raw_check() {
    case ${1:-} in
        storage) lin_raw_storage ;;
        network) lin_raw_network ;;
        services) lin_raw_services ;;
        updates) lin_raw_updates ;;
        *) lin_error "Raw evidence is not defined for check: ${1:-<blank>}"; return 2 ;;
    esac
}

lin_run_check() {
    if [[ ${LIN_RAW:-0} == 1 ]]; then lin_run_raw_check "$1"; return; fi
    case ${1:-} in
        health) lin_check_health ;;
        system) lin_check_system ;;
        resources) lin_check_resources ;;
        storage) lin_check_storage ;;
        network) lin_check_network ;;
        services) lin_check_services ;;
        security) lin_check_security ;;
        updates) lin_check_updates ;;
        containers) lin_check_containers ;;
        *) lin_error "Unknown check: ${1:-<blank>}"; printf 'Available checks:\n'; lin_list_checks; return 2 ;;
    esac
}

lin_show_check() {
    local id=$1 choice
    lin_run_check "$id"
    case $id in
        storage|network|services|updates)
            choice=$(lin_read 'R: raw evidence | Enter/B: back: ') || return 0
            if [[ ${choice^^} == R ]]; then LIN_RAW=1 lin_run_check "$id"; lin_pause; fi
            ;;
        *) lin_pause ;;
    esac
}

lin_main_menu() {
    while true; do
        lin_header 'Main menu'
        lin_menu_item '1' 'Health summary'
        lin_menu_item '2' 'System and user summary'
        lin_menu_item '3' 'CPU, memory, and heavy processes'
        lin_menu_item '4' 'Storage summary'
        lin_menu_item '5' 'Network summary'
        lin_menu_item '6' 'Services and logs summary'
        lin_menu_item '7' 'Firewall and SSH inspection'
        lin_menu_item '8' 'Available updates summary'
        lin_menu_item '9' 'Docker and Podman inventory'
        lin_menu_item '10' 'Maintenance actions [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 'Q' 'Quit' "$LIN_DIM"
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_show_check health ;;
            2) lin_show_check system ;;
            3) lin_show_check resources ;;
            4) lin_show_check storage ;;
            5) lin_show_check network ;;
            6) lin_show_check services ;;
            7) lin_show_check security ;;
            8) lin_show_check updates ;;
            9) lin_show_check containers ;;
            10) lin_maintenance_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-10 or Q.' ;;
        esac
    done
}

lin_usage() {
    cat <<EOF
Linux Toolkit $LIN_TOOLKIT_VERSION

Usage:
  Linux-Toolkit.sh                 Open the interactive menu
  Linux-Toolkit.sh --list          List command-line checks
  Linux-Toolkit.sh --check ID      Run one friendly read-only check
  Linux-Toolkit.sh --check ID --raw
                                   Show underlying command output when supported
  Linux-Toolkit.sh --no-color      Disable ANSI colours
  Linux-Toolkit.sh --help          Show this help

Maintenance actions are interactive only, require root, and never invoke sudo.
EOF
}

lin_main() {
    lin_setup_colors
    case ${1:-} in
        --help|-h) lin_usage ;;
        --list) lin_list_checks ;;
        --check)
            [[ -n ${2:-} ]] || { lin_error '--check requires an ID.'; return 2; }
            if [[ -n ${3:-} && ${3:-} != --raw ]]; then lin_error "Unknown --check option: $3"; return 2; fi
            [[ ${3:-} == --raw ]] && LIN_RAW=1
            lin_run_check "$2"
            ;;
        --no-color) NO_COLOR=1; lin_setup_colors; lin_main_menu ;;
        '') lin_main_menu ;;
        *) lin_error "Unknown argument: $1"; lin_usage; return 2 ;;
    esac
}
