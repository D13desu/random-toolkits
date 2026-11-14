# Shared output, capability, and input helpers.

LIN_RESET=''
LIN_CYAN=''
LIN_GREEN=''
LIN_YELLOW=''
LIN_RED=''
LIN_DIM=''
LIN_BOLD=''

lin_setup_colors() {
    LIN_RESET=''
    LIN_CYAN=''
    LIN_GREEN=''
    LIN_YELLOW=''
    LIN_RED=''
    LIN_DIM=''
    LIN_BOLD=''
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        LIN_RESET=$'\033[0m'
        LIN_CYAN=$'\033[36m'
        LIN_GREEN=$'\033[32m'
        LIN_YELLOW=$'\033[33m'
        LIN_RED=$'\033[31m'
        LIN_DIM=$'\033[2m'
        LIN_BOLD=$'\033[1m'
    fi
}

lin_header() {
    local title=${1:-Main menu}
    printf '\n%s%sLINUX TOOLKIT %s%s%s | %s%s\n' "$LIN_BOLD" "$LIN_CYAN" "$LIN_TOOLKIT_VERSION" "$LIN_RESET" "$LIN_CYAN" "$title" "$LIN_RESET"
    printf '%sRead-only unless an action is explicitly labelled %sCHANGES SYSTEM%s%s.%s\n\n' "$LIN_DIM" "$LIN_YELLOW" "$LIN_RESET" "$LIN_DIM" "$LIN_RESET"
}

lin_has() { command -v "$1" >/dev/null 2>&1; }

lin_warn() { printf '%sWARNING: %s%s\n' "$LIN_YELLOW" "$*" "$LIN_RESET" >&2; }
lin_error() { printf '%sERROR: %s%s\n' "$LIN_RED" "$*" "$LIN_RESET" >&2; }
lin_section() { printf '\n%s%s%s%s\n' "$LIN_BOLD" "$LIN_CYAN" "$1" "$LIN_RESET"; }
lin_field() { printf '%s%s:%s %s\n' "$LIN_CYAN" "$1" "$LIN_RESET" "$2"; }
lin_menu_item() { printf '  %s[%s]%s %s\n' "${3:-$LIN_GREEN}" "$1" "$LIN_RESET" "$2"; }

lin_read() {
    local prompt=$1
    local value=''
    if [[ -r /dev/tty ]]; then
        IFS= read -r -p "$prompt" value </dev/tty || return 1
    else
        IFS= read -r -p "$prompt" value || return 1
    fi
    printf '%s' "$value"
}

lin_pause() {
    if [[ -r /dev/tty ]]; then
        IFS= read -r -p 'Press Enter to return' _ </dev/tty || true
    fi
}

lin_confirm() {
    local prompt=$1
    local answer
    answer=$(lin_read "$prompt [y/N] ") || return 1
    [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

lin_require_root() {
    if (( EUID != 0 )); then
        lin_error 'This action requires root. Re-run the downloaded local script as root after reviewing it.'
        return 1
    fi
}

lin_os_release_value() {
    local key=$1
    local value=''
    if [[ -r /etc/os-release ]]; then
        value=$(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); gsub(/^"|"$/, ""); print; exit}' /etc/os-release)
    fi
    printf '%s' "$value"
}

lin_package_manager() {
    local candidate
    for candidate in apt-get dnf yum zypper pacman apk; do
        if lin_has "$candidate"; then printf '%s' "$candidate"; return 0; fi
    done
    return 1
}
