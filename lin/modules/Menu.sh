lin_list_checks() {
    cat <<'EOF'
system       System and user summary
resources    CPU, memory, and resource-heavy processes
storage      Filesystems, mounts, block devices, and inodes
network      Addresses, routes, DNS, and listening sockets
services     Failed services and recent boot warnings
security     Firewall, SSH, and mandatory-access-control status
updates      Available package updates using existing metadata
containers   Docker and Podman inventory
EOF
}

lin_run_check() {
    case ${1:-} in
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

lin_main_menu() {
    while true; do
        lin_header 'Main menu'
        cat <<'EOF'
1. System and user summary
2. CPU, memory, and heavy processes
3. Storage, mounts, and inode usage
4. Network configuration and listening sockets
5. Failed services and recent logs
6. Firewall and SSH inspection
7. Available package updates
8. Docker and Podman inventory
9. Maintenance actions [CHANGES SYSTEM]
Q. Quit
EOF
        local choice
        choice=$(lin_read 'Select: ') || return 0
        case ${choice^^} in
            1) lin_check_system; lin_pause ;;
            2) lin_check_resources; lin_pause ;;
            3) lin_check_storage; lin_pause ;;
            4) lin_check_network; lin_pause ;;
            5) lin_check_services; lin_pause ;;
            6) lin_check_security; lin_pause ;;
            7) lin_check_updates; lin_pause ;;
            8) lin_check_containers; lin_pause ;;
            9) lin_maintenance_menu ;;
            Q|0) return 0 ;;
            *) lin_warn 'Choose 1-9 or Q.' ;;
        esac
    done
}

lin_usage() {
    cat <<EOF
Linux Toolkit $LIN_TOOLKIT_VERSION

Usage:
  Linux-Toolkit.sh                 Open the interactive menu
  Linux-Toolkit.sh --list          List command-line checks
  Linux-Toolkit.sh --check ID      Run one read-only check
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
        --check) [[ -n ${2:-} ]] || { lin_error '--check requires an ID.'; return 2; }; lin_run_check "$2" ;;
        --no-color) NO_COLOR=1; lin_setup_colors; lin_main_menu ;;
        '') lin_main_menu ;;
        *) lin_error "Unknown argument: $1"; lin_usage; return 2 ;;
    esac
}
