# The DSM ACL evaluator is authoritative; no attempt is made to rebuild it.
SYN_EFFECTIVE=''
SYN_EFFECTIVE_STATE='UNAVAILABLE'
syn_permission_flags() {
    local flags=$1 kind=${2:-file} flag label i
    for ((i=0;i<${#flags};i++)); do
        flag=${flags:i:1}
        case $flag in
            r) label='Read data / list directory' ;; w) label='Write data / create files' ;;
            x) label='Execute / traverse directory' ;; p) label='Append data / create directories' ;;
            d) label='Delete' ;; D) [[ $kind == directory ]] && label='Delete child objects' || label='Delete child: directory-only flag' ;;
            a) label='Read attributes' ;; A) label='Write attributes' ;; R) label='Read extended attributes' ;;
            W) label='Write extended attributes' ;; c) label='Read permissions' ;; C) label='Change permissions' ;;
            o) label='Take ownership' ;; -) continue ;; *) label='Unknown flag' ;;
        esac
        printf '%s = %s\n' "$flag" "$label"
    done
    [[ $kind == file ]] && printf 'Delete-child (D) is not required on an individual file.\n'
    return 0
}
syn_acl_interpret() {
    local line type identity access flags inheritance level kind=$1
    while IFS= read -r line; do
        # Greedy identity permits domain names, spaces and colons; no word splitting.
        if [[ $line =~ (user|group):(.*):(allow|deny):([rwxpdDaARWcCo-]+):([fdin-]+) ]]; then
            type=${BASH_REMATCH[1]}; identity=${BASH_REMATCH[2]}; access=${BASH_REMATCH[3]}; flags=${BASH_REMATCH[4]}; inheritance=${BASH_REMATCH[5]}
            level='unknown'
            if [[ $line =~ level:([0-9]+) ]]; then
                level=${BASH_REMATCH[1]}; if [[ $level == 0 ]]; then level='explicit (level 0)'; else level="inherited (ancestor level $level)"; fi
            fi
            if [[ -z $identity ]]; then
                syn_emit "[INFO] Unresolved $type identity; $access; $level. No numeric ID is present in this entry; identity cannot be inferred."
            else syn_emit "ACL $type [$identity]: $access; $level; inheritance flags=$inheritance"; fi
            syn_emit "$(syn_permission_flags "$flags" "$kind")"
            case $inheritance in *f*) syn_emit 'Inheritance: files inherit' ;; esac
            case $inheritance in *d*) syn_emit 'Inheritance: directories inherit' ;; esac
            case $inheritance in *i*) syn_emit 'Inheritance: inherit-only entry' ;; esac
            case $inheritance in *n*) syn_emit 'Inheritance: no-propagate flag' ;; esac
        fi
    done
}
syn_acl_get() {
    local path=$1 kind=file
    syn_path "$path" && [[ -e $path && ! -L $path ]] || { syn_emit '[UNAVAILABLE] Object absent, inaccessible or a symlink; select a real absolute path.'; return 1; }
    [[ -d $path ]] && kind=directory
    syn_emit "ACL object: $path ($kind)"
    syn_run stat -c 'Filesystem owner=%U uid=%u group=%G gid=%g mode=%A modified=%y' -- "$path" || true
    # These two forms are verified in the supplied production matrix, not inferred.
    if ! syn_capture synoacltool -get "$path"; then syn_emit "[$SYN_STATE] ACL query: $SYN_OUT"; return 1; fi
    syn_emit "$SYN_OUT"
    syn_acl_interpret "$kind" <<<"$SYN_OUT"
}
syn_acl_effective() {
    local path=$1 user=$2 candidate line
    SYN_EFFECTIVE='';SYN_EFFECTIVE_STATE=UNAVAILABLE
    syn_path "$path" && syn_identity_arg "$user" || return 1
    if ! syn_capture synoacltool -get-perm "$path" "$user"; then SYN_EFFECTIVE_STATE=$SYN_STATE; syn_emit "[$SYN_STATE] Effective ACL query failed: $SYN_OUT"; return 1; fi
    syn_emit "Effective filesystem ACL for [$user] on [$path]: $SYN_OUT"
    # Accept only an unambiguous 13-position permission token, not a prose claim.
    candidate=''
    while IFS= read -r line; do
        if [[ $line =~ (^|[^[:alnum:]_-])([r-][w-][x-][p-][d-][D-][a-][A-][R-][W-][c-][C-][o-])([^[:alnum:]_-]|$) ]]; then
            [[ -z $candidate || $candidate == "${BASH_REMATCH[2]}" ]] || { SYN_EFFECTIVE_STATE=UNSUPPORTED; return 2; }
            candidate=${BASH_REMATCH[2]}
        fi
    done <<<"$SYN_OUT"
    [[ -n $candidate ]] || { SYN_EFFECTIVE_STATE=UNSUPPORTED; syn_emit '[UNAVAILABLE] Unrecognized permission output; raw evaluator output shown above.'; return 2; }
    SYN_EFFECTIVE=$candidate; SYN_EFFECTIVE_STATE=OK
    syn_emit "$(syn_permission_flags "$candidate" "$(if [[ -d $path ]]; then printf directory; else printf file; fi)")"
}
syn_identity() {
    local user=$1
    syn_identity_arg "$user" || { syn_emit '[UNAVAILABLE] Invalid identity; no command run.'; return 2; }
    if syn_capture id "$user"; then syn_emit "[OK] User resolved and memberships retrieved: $SYN_OUT"; return 0; fi
    syn_emit "[$SYN_STATE] id lookup failed: $SYN_OUT"
    if syn_supports wbinfo --user-info; then syn_run wbinfo "--user-info=$user" || true
    else syn_emit '[UNAVAILABLE] wbinfo user-info syntax not advertised.'; fi
    syn_emit 'An unsuccessful lookup does not prove the account was deleted.'
    return 1
}
syn_numeric_identity() {
    local kind=$1 number=$2 file option
    [[ $number =~ ^[0-9]+$ ]] || { syn_emit '[UNAVAILABLE] Numeric ID required.'; return 2; }
    if [[ $kind == user ]]; then file=/etc/passwd;option=--uid-info;else file=/etc/group;option=--gid-info;fi
    if [[ -r $file ]]; then
        # Do not expose password/hash fields from local account databases.
        syn_emit "$(awk -F: -v n="$number" '$3==n {printf "Local name=%s ID=%s",$1,$3;if(NF>=7)printf " primary-GID=%s home=%s shell=%s",$4,$6,$7;print ""}' "$file")"
    fi
    syn_gated wbinfo "$option" "$number" || true
    syn_emit 'Missing local/AD results are inconclusive; directory service connectivity may be unavailable.'
}
syn_membership_acl() {
    local path=$1 user=$2 acl memberships type name match
    syn_identity "$user" || true
    if ! syn_capture id -Gn "$user"; then syn_emit '[UNAVAILABLE] Group names unavailable; comparison skipped.'; return 1; fi
    memberships=$SYN_OUT
    if ! syn_capture synoacltool -get "$path"; then syn_emit "[$SYN_STATE] ACL unavailable: $SYN_OUT"; return 1; fi
    acl=$SYN_OUT
    while IFS= read -r match; do
        if [[ $match =~ (user|group):(.*):(allow|deny): ]]; then
            type=${BASH_REMATCH[1]};name=${BASH_REMATCH[2]}
            if [[ $type == user && $name == "$user" ]]; then syn_emit "[INFO] Exact user ACL entry: $match"
            elif [[ $type == group && -n $name ]]; then
                # id -Gn is space-delimited: spaces in group names prevent a reliable split.
                if grep -Fq -- "$name" <<<"$memberships"; then syn_emit "[REVIEW] Group-name text overlap (not proven membership): $match"; fi
            fi
        fi
    done <<<"$acl"
    syn_emit 'Group names with spaces/aliases and nested AD membership require verification. Use DSM get-perm as the authoritative filesystem result.'
    syn_acl_effective "$path" "$user" || true
}
syn_acl_walk() {
    local root=$1 depth=$2 path count=0 findbin
    syn_path "$root" && [[ -d $root && ! -L $root && $depth =~ ^[0-5]$ ]] || { syn_emit '[UNAVAILABLE] Use a real directory and depth 0-5.'; return 2; }
    findbin=$(syn_resolve find) || return 127
    syn_supports find -maxdepth && syn_supports find -print0 || { syn_emit '[UNAVAILABLE] find lacks bounded NUL-delimited traversal.'; return 2; }
    # Refuse symlinks; do not cross filesystem boundaries. Hard cap on inspected objects.
    while IFS= read -r -d '' path; do
        ((count+=1)); (( count <= 200 )) || { syn_emit '[INFO] Inspection capped at 200 objects.'; break; }
        syn_acl_get "$path" || true
    done < <("$findbin" "$root" -xdev -maxdepth "$depth" ! -type l -print0)
    syn_emit 'Traversal is bounded; an interrupted or inaccessible traversal is not a complete ACL audit.'
}
syn_acl_menu() {
    local choice path user depth
    while true; do
        lin_header 'Synology > ACL and effective permissions'
        lin_menu_item 1 'Object ACL, ownership, inheritance and unresolved identities'
        lin_menu_item 2 'Effective filesystem permissions for a user'
        lin_menu_item 3 'Compare parent and child ACLs'
        lin_menu_item 4 'Bounded recursive ACL inspection (depth 0-5; max 200 objects)'
        lin_menu_item 5 'Compare memberships with ACL entries'
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        [[ $choice != 0 && ${choice^^} != B ]] || return
        path=$(syn_input 'Absolute file/directory path') || continue
        syn_path "$path" || { syn_emit '[UNAVAILABLE] Absolute path required.'; continue; }
        case $choice in
            1) syn_acl_get "$path" || true ;;
            2) user=$(syn_input 'Local or DOMAIN\user') && syn_acl_effective "$path" "$user" || true ;;
            3) syn_acl_get "$(dirname -- "$path")" || true; syn_acl_get "$path" || true
               syn_emit 'Parent and child ACL evidence shown. Different inheritance levels do not alone establish an error.' ;;
            4) depth=$(syn_input 'Maximum depth 0-5') && syn_acl_walk "$path" "$depth" || true ;;
            5) user=$(syn_input 'Local or DOMAIN\user') && syn_membership_acl "$path" "$user" || true ;;
        esac
        lin_pause
    done
}
syn_identity_menu() {
    local choice value name
    while true; do
        lin_header 'Synology > Users and groups'
        lin_menu_item 1 'Resolve user and memberships';lin_menu_item 2 'Resolve numeric UID';lin_menu_item 3 'Resolve numeric GID'
        lin_menu_item 4 'Enumerate local users';lin_menu_item 5 'Enumerate local groups';lin_menu_item 6 'Inspect native user';lin_menu_item 7 'Inspect native group'
        lin_menu_item 8 'Domain connectivity / online status';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) value=$(syn_input 'User') && syn_identity "$value" || true ;;
            2|3) value=$(syn_input 'Numeric ID') || continue; name=user;[[ $choice == 3 ]] && name=group;syn_numeric_identity "$name" "$value" || true ;;
            4|5) name=synouser;[[ $choice == 5 ]] && name=synogroup
                 if syn_supports "$name" --enum && syn_supports "$name" local;then syn_run "$name" --enum local || true
                 else syn_emit '[UNAVAILABLE] Native local enumeration syntax not advertised.';fi ;;
            6|7) value=$(syn_input 'Name') || continue;syn_identity_arg "$value" || continue;name=synouser;[[ $choice == 7 ]] && name=synogroup
                 syn_gated "$name" --get "$value" || true ;;
            8) syn_gated wbinfo --ping-dc || true;syn_gated wbinfo --online-status || true ;;
            *) continue ;;
        esac
        lin_pause
    done
}
