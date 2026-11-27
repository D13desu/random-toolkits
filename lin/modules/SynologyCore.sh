# DSM-specific helpers. Bash 4+, no PATH changes and no dependency installation.
SYN_COMMAND_DIRS=(/usr/syno/bin /usr/syno/sbin /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /bin /sbin)
declare -A SYN_HELP_CACHE=()
SYN_REPORT=''
SYN_OUT=''
SYN_STATE='UNAVAILABLE'
SYN_LAST_GUIDED=''

syn_resolve() {
    local name=$1 found dir
    [[ $name =~ ^[a-zA-Z0-9_.+-]+$ ]] || return 1
    found=$(type -P "$name" 2>/dev/null) || found=''
    if [[ $found == /* && -x $found && ! -d $found ]]; then printf '%s' "$found"; return; fi
    for dir in "${SYN_COMMAND_DIRS[@]}"; do
        if [[ -x $dir/$name && ! -d $dir/$name ]]; then printf '%s' "$dir/$name"; return; fi
    done
    return 1
}
syn_stat() {
    local exe
    exe=$(syn_resolve stat) || return 127
    "$exe" "$@"
}
syn_is_dsm() { [[ -r /etc.defaults/VERSION && ( -r /etc/synoinfo.conf || -r /etc.defaults/synoinfo.conf ) ]]; }
syn_is_root() { (( EUID == 0 )); }
syn_clean() {
    # Keep Unicode, tab and newline; remove terminal control sequences/characters.
    tr -d '\000-\010\013-\037\177' | sed -E '/[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]|[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]/c\[REDACTED: sensitive field]'
}
syn_emit() {
    local text
    text=$(printf '%s\n' "$*" | syn_clean)
    printf '%s\n' "$text"
    # Bounded in-session report. No command is re-executed during export.
    if (( ${#SYN_REPORT} < 262144 )); then SYN_REPORT+="$text"$'\n'; fi
}
syn_capture() {
    local name=$1 exe timer rc; shift
    SYN_OUT=''; SYN_STATE='UNAVAILABLE'
    exe=$(syn_resolve "$name") || { SYN_OUT="Missing utility: $name"; return 127; }
    timer=$(syn_resolve timeout) || timer=''
    if [[ -n $timer ]]; then
        if SYN_OUT=$(LC_ALL=C "$timer" 20 "$exe" "$@" 2>&1); then rc=0; else rc=$?; fi
    else
        if SYN_OUT=$(LC_ALL=C "$exe" "$@" 2>&1); then rc=0; else rc=$?; fi
    fi
    SYN_STATE=OK
    if (( rc != 0 )); then
        case $SYN_OUT in
            *'Permission denied'*|*'permission denied'*|*'Operation not permitted'*|*'must be root'*) SYN_STATE=PRIVILEGE ;;
            *'invalid option'*|*'unknown option'*|*'unrecognized option'*|*'Invalid option'*|*'Usage:'*) SYN_STATE=UNSUPPORTED ;;
            *) SYN_STATE=FAILED ;;
        esac
        (( rc == 124 )) && SYN_STATE=TIMEOUT
    fi
    return "$rc"
}
syn_run() {
    local name=$1 rc=0; shift
    syn_capture "$name" "$@" || rc=$?
    syn_emit "[$SYN_STATE] $name (exit $rc)"
    [[ -z $SYN_OUT ]] || syn_emit "$SYN_OUT"
    return "$rc"
}
syn_help() {
    local name=$1
    if [[ ! ${SYN_HELP_CACHE[$name]+present} ]]; then
        syn_capture "$name" --help || true
        SYN_HELP_CACHE[$name]=$SYN_OUT
    fi
    printf '%s' "${SYN_HELP_CACHE[$name]}"
}
syn_supports() {
    local help
    help=$(syn_help "$1")
    # Flags used here are fixed internal strings, not user-supplied expressions.
    grep -Eq -- "(^|[^[:alnum:]_-])${2}([^[:alnum:]_-]|$)" <<<"$help"
}
syn_flag() {
    local name=$1 flag; shift
    for flag in "$@"; do if syn_supports "$name" "$flag"; then printf '%s' "$flag"; return; fi; done
    return 1
}
syn_gated() {
    local name=$1 flag=$2; shift 2
    if ! syn_supports "$name" "$flag"; then syn_emit "[UNAVAILABLE] $name $flag is not advertised by the installed utility."; return 2; fi
    syn_run "$name" "$flag" "$@"
}
syn_input() {
    local value
    value=$(lin_read "$1 (B = back): ") || return 1
    [[ ${value^^} != B && -n $value && $value != *$'\n'* && $value != *$'\r'* ]] || return 1
    printf '%s' "$value"
}
syn_path() {
    [[ $1 == /* && $1 != *$'\n'* && $1 != *$'\r'* ]]
}
syn_identity_arg() { [[ -n $1 && $1 != -* && $1 != *$'\n'* && $1 != *$'\r'* ]]; }
syn_version_value() {
    local key=$1 file=${2:-/etc.defaults/VERSION}
    [[ -r $file ]] || return 1
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, "");gsub(/^"|"$/, "");print;exit}' "$file"
}
syn_info() {
    local cmd path model='Unknown' f dsm='Not detected'
    syn_is_dsm && dsm='Synology DSM detected'
    syn_emit "[INFO] $dsm"
    for f in /proc/sys/kernel/syno_hw_version /etc.defaults/synoinfo.conf; do
        if [[ -r $f ]]; then
            if [[ $f == /proc/* ]]; then IFS= read -r model < "$f" || true
            else model=$(syn_version_value unique "$f"); fi
            [[ -n $model ]] && break
        fi
    done
    syn_emit "Model: $model"
    syn_emit "DSM: $(syn_version_value productversion) build $(syn_version_value buildnumber) update $(syn_version_value smallfixnumber)"
    syn_emit "Host: $(uname -n) | Kernel: $(uname -r) | Architecture: $(uname -m)"
    syn_run uptime || true
    syn_emit "Privilege: $(if syn_is_root; then printf root; else printf 'unprivileged (some diagnostics may be incomplete)'; fi)"
    for cmd in id wbinfo synouser synogroup synoacltool synoshare smbstatus testparm synosystemctl synopkg synodisk synostgpool smartctl mdadm getent synoservice python3 timeout stat strings find; do
        path=$(syn_resolve "$cmd") || path='UNAVAILABLE (optional)'
        syn_emit "$cmd: $path"
    done
    syn_emit 'Bash 4+ is required. No packages are installed; no root escalation is attempted.'
}
syn_export() {
    local dir file
    [[ -n $SYN_LAST_GUIDED ]] || { lin_error 'Run guided troubleshooting first; exports contain its curated findings, not raw logs/configuration or owner-file strings.'; return 1; }
    dir=$(syn_input 'Existing private report directory (absolute path)') || return
    syn_path "$dir" && [[ -d $dir && ! -L $dir && -O $dir ]] || { lin_error 'Choose an existing directory owned by the current user.'; return 1; }
    # Export only into private directories; mktemp creates a non-overwriting 0600 file.
    local mode
    mode=$(syn_stat -c '%a' -- "$dir" 2>/dev/null) || { lin_error 'Cannot verify directory permissions.'; return 1; }
    [[ $mode == 700 ]] || { lin_error 'Report directory must have mode 700.'; return 1; }
    file=$(umask 077; mktemp "$dir/synology-$(date +%Y%m%dT%H%M%S)-XXXXXX.txt") || return
    if ! printf 'Synology diagnostic report (snapshot; not a root-cause guarantee)\n%s\n' "$SYN_LAST_GUIDED" | syn_clean > "$file"; then lin_error "Export failed: $file"; return 1; fi
    printf 'Report saved: %s\n' "$file"
}
