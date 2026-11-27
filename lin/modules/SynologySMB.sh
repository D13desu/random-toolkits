# Safe Samba status/configuration views; text results are evidence, not parsed tables.
SYN_SMB_JSON=''
SYN_SMB_MATCHES=''
syn_smb_snapshot() {
    local option rc=0
    SYN_SMB_JSON=''
    option=$(syn_flag smbstatus --json -j) || return 2
    syn_capture smbstatus "$option" || return $?
    SYN_SMB_JSON=$SYN_OUT
    return "$rc"
}
syn_smb_json_match() {
    # Samba's documented JSON schema. Python is optional and only needed for
    # structured correlation and the fail-closed quarantine gate.
    local needle=$1 exact=${2:-0} py
    py=$(syn_resolve python3) || return 2
    SYN_SMB_MATCHES=$(SYN_JSON="$SYN_SMB_JSON" "$py" - "$needle" "$exact" <<'PY'
import json,sys,os,posixpath
try:
 d=json.loads(os.environ['SYN_JSON'])
 if not isinstance(d,dict) or not all(isinstance(d.get(k),dict) for k in ('sessions','tcons','open_files')):raise ValueError('unsupported/incomplete schema')
 if d.get('error') or d.get('errors'):raise ValueError('Samba reported errors')
 sessions=d['sessions'];needle=sys.argv[1];exact=sys.argv[2]=='1'
 for item in d['open_files'].values():
  if not isinstance(item,dict) or not isinstance(item.get('service_path'),str) or not isinstance(item.get('filename'),str) or not isinstance(item.get('opens'),dict):raise ValueError('unrecognized open file record')
  path=posixpath.normpath(posixpath.join(item['service_path'],item['filename']))
  if not path.startswith('/'):raise ValueError('non-absolute open path')
  if (path!=needle if exact else needle.casefold() not in path.casefold()):continue
  if not item['opens']:
   print(json.dumps({'path':path,'pid':'unknown','status':'open-file record without detailed opens; treat conservatively as active'},ensure_ascii=False))
  for op in item['opens'].values():
   if not isinstance(op,dict) or not isinstance(op.get('server_id'),dict) or 'pid' not in op['server_id']:raise ValueError('missing handle server PID')
   pid=str(op['server_id']['pid'])
   matches=[s for s in sessions.values() if isinstance(s,dict) and str(s.get('server_id',{}).get('pid'))==pid]
   if not matches:matches=[{}]
   for session in matches:
    print(json.dumps({'path':path,'pid':pid,'SMB_user':session.get('username','unknown'),'client':session.get('remote_machine','unknown'),'host':session.get('hostname','unknown'),'correlation':'PID candidate; not proof of per-handle user'},ensure_ascii=False))
except (ValueError,TypeError,KeyError,AttributeError) as e:
 print('Cannot interpret Samba JSON: '+str(e),file=sys.stderr);sys.exit(2)
PY
) || return 2
}
syn_smb_search() {
    local needle=$1 mode=${2:-path} flag rc=0
    syn_emit "SMB filter ($mode): $needle"
    if syn_smb_snapshot && syn_smb_json_match "$needle"; then
        if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "$SYN_SMB_MATCHES"
        else syn_emit '[INFO] No matching open paths in this structured snapshot. This does not establish that nobody is editing.'; fi
        syn_emit 'Session/PID correlation is advisory; separate session/share tables can have multiple users per server process.'
        return 0
    fi
    flag=$(syn_flag smbstatus --locks -L) || { syn_emit '[UNAVAILABLE] Installed smbstatus does not advertise a locks view.'; return 2; }
    syn_capture smbstatus "$flag" || { syn_emit "[$SYN_STATE] SMB locks failed: $SYN_OUT"; return 1; }
    # Literal filtering retains complete lines, including filenames with spaces.
    if SYN_SMB_MATCHES=$(grep -iF -- "$needle" <<<"$SYN_OUT"); then syn_emit "$SYN_SMB_MATCHES"
    else syn_emit '[INFO] No matching text lines. Unparsed output is not a verified empty handle set.'; fi
    syn_emit 'Text fallback: filenames are not split on spaces. Correlate PIDs with the process/session and share views below.'
    syn_run smbstatus || rc=$?
    return "$rc"
}
syn_smb_proof_clear() {
    # Used only before quarantine/restore. Any uncertainty blocks mutation.
    local path
    syn_is_root || { lin_error 'Handle verification requires root.'; return 1; }
    syn_smb_snapshot || { lin_error 'Cannot obtain structured SMB handles. Operation refused.'; return 1; }
    for path in "$@"; do
        syn_smb_json_match "$path" 1 || { lin_error 'Cannot interpret all SMB handle records. Operation refused.'; return 1; }
        [[ -z $SYN_SMB_MATCHES ]] || { syn_emit "$SYN_SMB_MATCHES"; lin_error 'Matching active handles exist. Operation refused.'; return 1; }
    done
    return 0
}
syn_smb_view() {
    local view=$1 flag
    case $view in
        sessions) syn_run smbstatus ;;
        processes) flag=$(syn_flag smbstatus --processes -p) || return 2; syn_run smbstatus "$flag" ;;
        shares) flag=$(syn_flag smbstatus --shares -S) || return 2; syn_run smbstatus "$flag" ;;
        locks) flag=$(syn_flag smbstatus --locks -L) || return 2; syn_run smbstatus "$flag" ;;
        range) flag=$(syn_flag smbstatus --byterange -B) || return 2; syn_run smbstatus "$flag" ;;
    esac
}
syn_smb_config() {
    local flag
    flag=$(syn_flag testparm --suppress-prompt -s) || { syn_emit '[UNAVAILABLE] Noninteractive testparm syntax not advertised.'; return 2; }
    syn_capture testparm "$flag" || { syn_emit "[$SYN_STATE] testparm failed: $SYN_OUT"; return 1; }
    # Deliberate allowlist: never export arbitrary Samba configuration/secrets.
    SYN_SHARE_CONFIG=$(awk '
      /^[ \t]*\[/ {print;next}
      /^[ \t]*(path|read only|valid users|write list|read list|force user|force group|guest ok|browseable|workgroup|realm|security|server role)[ \t]*=/ {print}
    ' <<<"$SYN_OUT")
    syn_emit 'Effective Samba configuration: safe directive subset (not the full configuration)'
    syn_emit "$SYN_SHARE_CONFIG"
}
syn_share_root() {
    local target=$1 root='' name path best=''
    syn_smb_config >/dev/null || return 1
    while IFS=$'\t' read -r name path; do
        [[ $path == /* && $path != *'%'* && $path != *'$'* ]] || continue
        if [[ $target == "$path" || $target == "$path/"* || $path == / ]]; then
            if (( ${#path} > ${#best} )); then best=$path; root=$name; fi
        fi
    done < <(awk '
      /^[ \t]*\[/ {s=$0;sub(/^[ \t]*\[/,"",s);sub(/\].*$/,"",s)}
      /^[ \t]*path[ \t]*=/ {p=$0;sub(/^[^=]*=[ \t]*/,"",p);sub(/[ \t]+$/,"",p);print s "\t" p}
    ' <<<"$SYN_SHARE_CONFIG")
    [[ -n $best ]] || return 1
    SYN_SHARE_NAME=$root; SYN_SHARE_ROOT=$best
}
syn_logs() {
    local f
    for f in /var/log/samba/log.smbd /var/log/samba/smb.log /var/log/messages; do
        [[ -r $f ]] || continue
        syn_emit "Recent error context: $f (bounded and redacted)"
        syn_emit "$(tail -n 200 -- "$f" | grep -iE 'error|fail|denied|degrad|corrupt|I/O' | tail -n 40)"
    done
    syn_emit 'Logs may be unavailable, rotated or incomplete. No absence-of-errors conclusion is made.'
}
syn_smb_menu() {
    local choice needle
    while true; do
        lin_header 'Synology > SMB sessions and file locks'
        lin_menu_item 1 'Active sessions / connected users / clients'
        lin_menu_item 2 'Process IDs and session table'
        lin_menu_item 3 'Accessed shares'
        lin_menu_item 4 'Open files / locks'
        lin_menu_item 5 'Search open file/path (literal)'
        lin_menu_item 6 'Filter sessions by user/client/share (literal text)'
        lin_menu_item 7 'Effective Samba configuration (safe subset)'
        lin_menu_item 8 'SMB service status'
        lin_menu_item 9 'Relevant recent logs'
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        case $choice in
            1) syn_smb_view sessions || true ;; 2) syn_smb_view processes || syn_emit '[UNAVAILABLE] Process view failed/unsupported.' ;;
            3) syn_smb_view shares || syn_emit '[UNAVAILABLE] Share view failed/unsupported.' ;;
            4) syn_smb_view locks || syn_emit '[UNAVAILABLE] Locks view failed/unsupported.' ;;
            5) needle=$(syn_input 'Filename or partial path') && syn_smb_search "$needle" || true ;;
            6) needle=$(syn_input 'Username, client IP/hostname, or share name') || continue
               if syn_capture smbstatus; then
                   if SYN_SMB_MATCHES=$(grep -iF -- "$needle" <<<"$SYN_OUT"); then syn_emit "$SYN_SMB_MATCHES"; else syn_emit '[INFO] No matching session text lines.'; fi
                   syn_emit 'Literal text filter only; use complete session/share views for correlation.'
               else syn_emit "[$SYN_STATE] $SYN_OUT"; fi ;;
            7) syn_smb_config || true ;; 8) syn_service_status smb ;; 9) syn_logs ;;
            0|B|b) return ;; *) continue ;;
        esac
        lin_pause
    done
}
