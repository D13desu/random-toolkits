lin_check_containers() {
    lin_header 'Container inventory'
    local found=0
    if lin_has docker; then
        found=1; lin_section 'Docker'; docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}' 2>&1 || true; docker ps -a --no-trunc 2>&1 || true
    fi
    if lin_has podman; then
        found=1; lin_section 'Podman'; podman version 2>&1 || true; podman ps -a --no-trunc 2>&1 || true
    fi
    if (( ! found )); then lin_warn 'Docker and Podman are not installed.'; fi
}
