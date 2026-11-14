lin_check_updates() {
    lin_header 'Available package updates'
    local manager
    manager=$(lin_package_manager) || { lin_warn 'No supported package manager was found.'; return 0; }
    lin_field 'Package manager' "$manager"
    printf 'This reads currently available update metadata; it does not refresh caches or install packages.\n\n'
    case $manager in
        apt-get) apt list --upgradable 2>/dev/null || true ;;
        dnf) dnf --cacheonly check-update || [[ $? -eq 100 ]] ;;
        yum) yum -C check-update || [[ $? -eq 100 ]] ;;
        zypper) zypper --non-interactive list-updates ;;
        pacman) pacman -Qu || true ;;
        apk) apk version -l '<' ;;
    esac
}
