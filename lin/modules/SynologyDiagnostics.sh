# Extended diagnostics: only fixed read-only operations with detected syntax.
syn_service_status() {
    local service=$1
    syn_identity_arg "$service" || return 2
    if syn_supports synosystemctl get-active-status; then syn_run synosystemctl get-active-status "$service" || true
    elif syn_supports synosystemctl status; then syn_run synosystemctl status "$service" || true
    else syn_emit '[UNAVAILABLE] Installed synosystemctl does not advertise a validated status operation.';fi
}
syn_services_menu() {
    local choice value
    while true; do
        lin_header 'Synology > Services and packages'
        lin_menu_item 1 'List services (if advertised)';lin_menu_item 2 'Selected service status';lin_menu_item 3 'SMB service status'
        lin_menu_item 4 'List packages';lin_menu_item 5 'Selected package status';lin_menu_item 6 'Listening ports';lin_menu_item 7 'Recent error logs';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) syn_gated synosystemctl list-units || true ;;
            2) value=$(syn_input 'Service name') && syn_service_status "$value" || true ;;
            3) syn_service_status smb ;;
            4) syn_gated synopkg list || true ;;
            5) value=$(syn_input 'Package name') || continue;syn_identity_arg "$value" && syn_gated synopkg status "$value" || true ;;
            6) syn_connections ;;
            7) syn_logs ;;
            *) continue ;;
        esac
        lin_pause
    done
}
syn_connections() {
    if syn_resolve ss >/dev/null; then syn_run ss -lntup || true
    elif syn_resolve netstat >/dev/null; then syn_run netstat -lntp || true
    else syn_emit '[UNAVAILABLE] Neither ss nor netstat is installed.';fi
}
syn_storage_menu() {
    local choice path device
    while true; do
        lin_header 'Synology > Storage and disks (read-only)'
        lin_menu_item 1 'Volume/filesystem utilisation';lin_menu_item 2 'Mounts / disk identification'
        lin_menu_item 3 'RAID status';lin_menu_item 4 'SMART attributes/health (no tests)';lin_menu_item 5 'Storage pool info (if advertised)'
        lin_menu_item 6 'Synology disk info (if advertised)';lin_menu_item 7 'Shared folder size (on demand)';lin_menu_item 8 'Recent filesystem/storage errors';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) syn_run df -h || true;syn_run df -i || true ;;
            2) syn_run mount || true;syn_run lsblk || true ;;
            3) if [[ -r /proc/mdstat ]]; then syn_emit "$(cat /proc/mdstat)";else syn_emit '[UNAVAILABLE] /proc/mdstat not readable.';fi
               device=$(syn_input 'Optional RAID device /dev/mdN (B skips details)') || continue
               [[ $device =~ ^/dev/md[0-9]+$ ]] && syn_gated mdadm --detail "$device" || syn_emit '[UNAVAILABLE] Use a /dev/mdN device.' ;;
            4) device=$(syn_input 'Disk device under /dev (no options)') || continue
               [[ $device =~ ^/dev/[a-zA-Z0-9_/.-]+$ && $device != *'..'* ]] || { syn_emit '[UNAVAILABLE] Invalid device path.';continue; }
               syn_gated smartctl --all "$device" || true ;;
            5) syn_gated synostgpool --get || true ;;
            6) device=$(syn_input 'Disk device under /dev') || continue
               [[ $device =~ ^/dev/[a-zA-Z0-9_/.-]+$ && $device != *'..'* ]] && syn_gated synodisk --info "$device" || true ;;
            7) path=$(syn_input 'Exact absolute shared-folder path') || continue
               if syn_path "$path" && [[ -d $path ]] && lin_confirm 'Run potentially expensive folder-size scan now (20s timeout if available)?'; then syn_run du -sk "$path" || true;fi ;;
            8) syn_capture dmesg || true
               if [[ $SYN_STATE == OK ]]; then syn_emit "$(grep -iE 'error|fail|I/O|btrfs|ext4|raid|degrad' <<<"$SYN_OUT" | tail -n 60)";else syn_emit "[$SYN_STATE] Kernel log access failed.";fi ;;
            *) continue ;;
        esac
        lin_pause
    done
}
syn_shares_menu() {
    local choice path
    while true; do
        lin_header 'Synology > Shared folders'
        lin_menu_item 1 'Effective share paths and safe Samba settings';lin_menu_item 2 'Native share enumeration (if advertised)'
        lin_menu_item 3 'Find containing share, root ownership and ACL';lin_menu_item 4 'Selected share configuration (if advertised)';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;; 1) syn_smb_config || true ;; 2) syn_gated synoshare --enum ALL || true ;;
            3) path=$(syn_input 'Absolute file path') || continue
               if syn_share_root "$path"; then syn_emit "Containing share: $SYN_SHARE_NAME | $SYN_SHARE_ROOT";syn_acl_get "$SYN_SHARE_ROOT" || true
               else syn_emit '[UNAVAILABLE] Containing share could not be resolved from literal effective paths.';fi ;;
            4) path=$(syn_input 'Share name') || continue;syn_identity_arg "$path" && syn_gated synoshare --get "$path" || true ;;
            *) continue ;;
        esac
        syn_emit '[TODO] Verify Advanced Share Permissions in DSM: Control Panel > Shared Folder > Edit > Advanced Permissions. Filesystem ACL alone does not establish SMB access.'
        lin_pause
    done
}
syn_network_menu() {
    local choice host
    while true; do
        lin_header 'Synology > System and network'
        lin_menu_item 1 'CPU / memory / load / processes';lin_menu_item 2 'Interfaces / IPs / routes / neighbours'
        lin_menu_item 3 'Listening ports';lin_menu_item 4 'DNS lookup';lin_menu_item 5 'Active connections';lin_menu_item 6 'Recent errors';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;
            1) lin_check_resources; syn_run uptime || true ;;
            2) if syn_resolve ip >/dev/null;then syn_run ip address show || true;syn_run ip route show || true;syn_run ip neigh show || true
               else syn_run ifconfig || true;syn_run route -n || true;syn_run arp -n || true;fi ;;
            3) syn_connections ;;
            4) host=$(syn_input 'DNS name or IP') || continue
               [[ $host =~ ^[a-zA-Z0-9][a-zA-Z0-9:._-]*$ ]] && syn_run nslookup "$host" || syn_emit '[UNAVAILABLE] Lookup failed or unsupported name.' ;;
            5) if syn_resolve ss >/dev/null;then syn_run ss -ntup || true;else syn_run netstat -ntp || true;fi ;;
            6) syn_logs ;; *) continue ;;
        esac
        lin_pause
    done
}
syn_guided() {
    local path=$1 user=$2 parent root='' object acl_out checks='' owner
    syn_path "$path" && [[ -f $path && ! -L $path ]] && syn_identity_arg "$user" || { syn_emit '[UNAVAILABLE] Existing real file and valid user required.';return 1; }
    parent=$(dirname -- "$path")
    syn_emit '=================================================='
    syn_emit 'FILE READ-ONLY DIAGNOSTIC REPORT'
    syn_emit "Target: $path | User: $user"
    if syn_identity "$user";then checks+='[OK] User and memberships resolved'$'\n';else checks+='[FAILED] Identity lookup incomplete; not evidence of a deleted account'$'\n';fi
    if syn_share_root "$path";then root=$SYN_SHARE_ROOT;checks+="[INFO] Containing share: $SYN_SHARE_NAME ($root)"$'\n';else checks+='[UNAVAILABLE] Containing share not resolved'$'\n';fi
    for object in "$root" "$parent" "$path"; do
        [[ -n $object ]] || continue
        if syn_acl_get "$object";then
            if [[ $SYN_OUT == *'user::'* || $SYN_OUT == *'group::'* ]];then checks+="[INFO] Unresolved ACL identity at $object (not automatically a problem)"$'\n';fi
        else checks+="[FAILED] ACL/ownership unavailable: $object"$'\n';fi
        if syn_acl_effective "$object" "$user";then
            if [[ ${SYN_EFFECTIVE:1:1} == w ]];then checks+="[OK] Effective filesystem ACL grants write: $object"$'\n'
            else checks+="[REVIEW] Effective filesystem ACL does not grant write: $object"$'\n';fi
        else checks+="[UNAVAILABLE] Effective ACL: $object ($SYN_EFFECTIVE_STATE)"$'\n';fi
    done
    syn_smb_search "$path" || checks+='[FAILED] SMB handle lookup incomplete'$'\n'
    owner=$parent/'~$'${path##*/}
    if [[ -f $owner && ! -L $owner ]];then checks+="[REVIEW] Apparent Office owner file: $owner"$'\n';syn_owner_inspect "$owner" || true
    else checks+='[INFO] No owner file at the literal ~$ name; truncated/renamed Office owner files may still exist'$'\n';fi
    checks+='[TODO] Verify Advanced Share Permissions in DSM; not verified by filesystem ACL'$'\n'
    checks+='[TODO] Review parent/child inheritance evidence; differences alone are not an error'$'\n'
    checks+='[TODO] Verify Windows read-only attributes and actual create/modify/rename/delete as the affected user'$'\n'
    checks+='Assessment: findings are snapshots. Suspected causes remain unconfirmed; ACL checks do not establish end-to-end SMB access.'$'\n'
    SYN_LAST_GUIDED="Target: $path"$'\n'"User: $user"$'\n'"$checks"
    syn_emit "$checks"
    syn_emit 'Windows: Get-SmbConnection | Format-Table ServerName,ShareName,UserName,Credential'
    syn_emit 'Windows: Get-Item "\\NAS\Share\document.xlsx" | Select-Object Name,Attributes,IsReadOnly'
    syn_emit 'Do not export authentication tokens, passwords or private configuration. No original document has been modified.'
}
synology_menu() {
    local choice path user
    if ! syn_is_dsm;then syn_emit '[UNAVAILABLE] Synology DSM was not detected. Generic Linux checks remain available from the main menu.';lin_pause;return 0;fi
    while true;do
        lin_header 'Synology NAS Troubleshooting'
        lin_menu_item 1 'System information and compatibility';lin_menu_item 2 'SMB sessions and file locks';lin_menu_item 3 'ACL and effective permissions'
        lin_menu_item 4 'Office file lock troubleshooting';lin_menu_item 5 'Users and groups';lin_menu_item 6 'Shared folders'
        lin_menu_item 7 'Storage and disk diagnostics';lin_menu_item 8 'Services and packages';lin_menu_item 9 'System and network diagnostics'
        lin_menu_item 10 'Troubleshoot file opening in read-only mode';lin_menu_item 11 'Export diagnostic snapshot';lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            0|B|b) return ;;1) syn_info;lin_pause;;2) syn_smb_menu;;3) syn_acl_menu;;4) syn_office_menu;;5) syn_identity_menu;;6) syn_shares_menu;;7) syn_storage_menu;;8) syn_services_menu;;9) syn_network_menu;;
            10) path=$(syn_input 'Affected absolute file path') || continue;user=$(syn_input 'Affected local or DOMAIN\user') || continue;syn_guided "$path" "$user";lin_pause;;
            11) syn_export;lin_pause;;*) lin_warn 'Choose 0-11.';;
        esac
    done
}
