# Office owner files are evidence, never proof that a document is being edited.
SYN_OWNER_ORIGINAL=''
syn_owner_original() {
    local path=$1 base parent candidate
    base=${path##*/};parent=${path%/*}
    [[ $base == '~$'* && ${#base} -gt 2 ]] || return 1
    candidate=$parent/${base:2}
    SYN_OWNER_ORIGINAL=$candidate
    printf '%s' "$candidate"
}
syn_owner_inspect() {
    local path=$1 original stringsbin text size epoch now birth
    syn_path "$path" && [[ -f $path && ! -L $path && ${path##*/} == '~$'* ]] || { syn_emit '[UNAVAILABLE] Select a real Office owner file beginning with ~$.'; return 1; }
    original=$(syn_owner_original "$path") || return 1
    syn_emit "Office owner file: $path"
    syn_run stat -c 'Filesystem owner=%U uid=%u group=%G size=%s modified=%y epoch=%Y' -- "$path" || true
    epoch=$(syn_stat -c '%Y' -- "$path" 2>/dev/null) || epoch=''
    now=$(date +%s)
    if [[ $epoch =~ ^[0-9]+$ && $now =~ ^[0-9]+$ ]]; then syn_emit "Owner file age (seconds): $((now-epoch)) (age alone is not evidence of staleness)"; fi
    birth=$(syn_stat -c '%w' -- "$path" 2>/dev/null) || birth=''
    if [[ $birth =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then syn_emit "Creation time: $birth";else syn_emit 'Creation time: unavailable on this utility/filesystem';fi
    size=$(syn_stat -c '%s' -- "$path" 2>/dev/null) || size=''
    stringsbin=$(syn_resolve strings) || stringsbin=''
    if [[ -n $stringsbin && $size =~ ^[0-9]+$ ]] && ((size<=65536)); then
        text=$("$stringsbin" "$path" 2>/dev/null | head -n 8) || true
        syn_emit "Office username candidates (heuristic strings; NOT filesystem owner or authenticated SMB identity): $text"
        if syn_supports strings -e; then syn_emit "UTF-16LE string candidates: $("$stringsbin" -e l "$path" 2>/dev/null | head -n 8)"; fi
    else syn_emit 'Office username extraction unavailable or file exceeds 64 KiB inspection bound.'; fi
    if [[ -f $original ]]; then syn_emit "Apparent original document: $original"
    else syn_emit "[REVIEW] No original at literal stripped-name path: $original. Office can truncate or alter owner filenames; original identification is unconfirmed.";fi
    if syn_smb_snapshot && syn_smb_json_match "$path" 1; then
        if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "[REVIEW] Active owner-file handles: $SYN_SMB_MATCHES"
        elif syn_smb_json_match "$original" 1; then
            if [[ -n $SYN_SMB_MATCHES ]]; then syn_emit "[REVIEW] Active original-document handles: $SYN_SMB_MATCHES"
            else syn_emit '[REVIEW] Potentially stale owner file: no exact-path matches in this SMB snapshot. Editing status and root cause remain unconfirmed.';fi
        fi
    else syn_emit '[UNAVAILABLE] Reliable SMB correlation unavailable. Cannot assess whether this owner file is stale.';fi
}
syn_owner_find() {
    local root=$1 depth=$2 findbin path count=0
    syn_path "$root" && [[ -d $root && ! -L $root && $depth =~ ^[0-5]$ ]] || { syn_emit '[UNAVAILABLE] Use a real directory and depth 0-5 (0 = this directory only).'; return 2; }
    findbin=$(syn_resolve find) || return 127
    syn_supports find -maxdepth && syn_supports find -print0 || { syn_emit '[UNAVAILABLE] find lacks supported bounded traversal.'; return 2; }
    while IFS= read -r -d '' path; do
        ((count+=1)); ((count<=200)) || { syn_emit '[INFO] Owner-file inspection capped at 200 matches.'; break; }
        syn_owner_inspect "$path" || true
    done < <("$findbin" "$root" -xdev -maxdepth "$((depth+1))" -type f -name '~$*' -print0)
    syn_emit "Owner files inspected: $((count>200?200:count)). This bounded traversal can omit inaccessible objects or stop early."
}

syn_owner_transaction() {
    # Python is optional. This helper validates each transaction and uses Linux
    # renameat2(RENAME_NOREPLACE); it never falls back to an overwrite-prone mv.
    local mode=$1 source=$2 destination=${3:-} py
    py=$(syn_resolve python3) || { lin_error 'Python 3 is required for guarded quarantine/restore.'; return 2; }
    "$py" - "$mode" "$source" "$destination" <<'PY'
import os,sys,json,stat,ctypes,errno,time,uuid,re
mode,source,destination=sys.argv[1:]
libc=ctypes.CDLL(None,use_errno=True)
rename=getattr(libc,'renameat2',None)
if rename is None:sys.exit('UNAVAILABLE: renameat2 no-overwrite support is required.')
rename.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint]
def canonical(p):
 if not os.path.isabs(p) or any(ord(c)<32 for c in p) or os.path.realpath(p)!=os.path.normpath(p):raise ValueError('Absolute paths without symlink components/control characters required')
 return os.path.normpath(p)
def regular(p):
 s=os.lstat(p)
 if not stat.S_ISREG(s.st_mode) or s.st_nlink!=1:raise ValueError('Regular, single-link owner file required')
 if s.st_size>1048576:raise ValueError('Owner file exceeds 1 MiB safety bound')
 return s
def ownerpath(p):
 p=canonical(p)
 if not os.path.basename(p).startswith('~$') or len(os.path.basename(p))<=2:raise ValueError('Not an Office owner filename')
 return p
def signature(s):return [s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns]
def parent_fd(path):
 # Walk every component without following symlinks, not just the last one.
 fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY)
 try:
  for component in os.path.dirname(path).split('/'):
   if not component:continue
   next_fd=os.open(component,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
   os.close(fd);fd=next_fd
  return fd
 except BaseException:
  os.close(fd);raise
def guarded_move(src,dst):
 # Retain both parent descriptors through the atomic no-overwrite move.
 sp=parent_fd(src)
 try:dp=parent_fd(dst)
 except BaseException:os.close(sp);raise
 try:
  if rename(sp,os.fsencode(os.path.basename(src)),dp,os.fsencode(os.path.basename(dst)),1)!=0:
   e=ctypes.get_errno();raise OSError(e,os.strerror(e))
 finally:os.close(sp);os.close(dp)
def private(p):
 s=os.lstat(p)
 if not stat.S_ISDIR(s.st_mode) or s.st_uid!=0 or stat.S_IMODE(s.st_mode)!=0o700:raise ValueError('Quarantine directory must be root-owned mode 700')
try:
 if os.geteuid()!=0:raise ValueError('Existing root session required')
 if mode in ('quarantine','prepare'):
  source=ownerpath(source);s=regular(source)
  original=os.path.join(os.path.dirname(source),os.path.basename(source)[2:])
  if os.path.lexists(original):
   orig=os.lstat(original)
   if not stat.S_ISREG(orig.st_mode) or orig.st_nlink!=1:raise ValueError('Original must not be a symlink or hard-link alias')
  # Fixed root-level @ directory, outside the normal DSM share directories.
  volume=re.match(r'^(/volume[0-9]+)/',source)
  if not volume:raise ValueError('Quarantine only supports /volumeN paths')
  base=volume.group(1)+'/@d0xd-owner-quarantine'
  if mode=='prepare':print(base);sys.exit(0)
  canonical(base)
  if not os.path.exists(base):os.mkdir(base,0o700)
  private(base)
  if os.stat(base).st_dev!=s.st_dev:raise ValueError('Quarantine must be on the same filesystem')
  tx=base+'/'+time.strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex
  os.mkdir(tx,0o700);payload=tx+'/owner-file';manifest=tx+'/manifest.json'
  record={'version':1,'original':source,'payload':payload,'signature':signature(s),'state':'prepared'}
  with open(manifest,'x',encoding='utf-8') as f:os.chmod(manifest,0o600);json.dump(record,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
  if signature(regular(source))!=record['signature']:raise ValueError('Owner file changed during preparation')
  guarded_move(source,payload)
  if signature(regular(payload))!=record['signature'] or os.path.lexists(source):raise ValueError('Move verification failed; inspect manifest and both locations')
  # Keep the pre-move manifest intact: a crash never destroys recovery data.
  print('Quarantined. Manifest: '+manifest)
 elif mode in ('restore','inspect'):
  manifest=canonical(source);tx=os.path.dirname(manifest);base=os.path.dirname(tx)
  if not re.match(r'^/volume[0-9]+/@d0xd-owner-quarantine/[^/]+/manifest\.json$',manifest):raise ValueError('Unrecognized quarantine manifest location')
  private(base);private(tx)
  ms=os.lstat(manifest)
  if not stat.S_ISREG(ms.st_mode) or ms.st_uid!=0 or ms.st_nlink!=1 or stat.S_IMODE(ms.st_mode)!=0o600 or ms.st_size>16384:raise ValueError('Unsafe manifest')
  with open(manifest,encoding='utf-8') as f:r=json.load(f)
  original=ownerpath(r['original']);payload=canonical(r['payload'])
  if r.get('version')!=1 or payload!=tx+'/owner-file' or os.path.dirname(original).split('/')[1]!=base.split('/')[1]:raise ValueError('Invalid manifest paths')
  if signature(regular(payload))!=r['signature']:raise ValueError('Quarantine payload changed')
  if os.path.lexists(original):raise ValueError('Original owner path exists; refusing overwrite')
  if mode=='inspect':print(original);sys.exit(0)
  guarded_move(payload,original)
  if signature(regular(original))!=r['signature'] or os.path.lexists(payload):raise ValueError('Restore verification failed')
  print('Restored: '+original+'; retained manifest: '+manifest)
 else:raise ValueError('Unsupported operation')
except (ValueError,OSError,KeyError,TypeError) as e:sys.exit('REFUSED/FAILED: '+str(e))
PY
}
syn_owner_change() {
    local mode=$1 path=$2 original document base answer
    syn_is_root || { lin_error 'Quarantine/restore requires an existing root session.'; return 1; }
    if [[ $mode == quarantine ]]; then
        original=$path
        base=$(syn_owner_transaction prepare "$path") || return
        # Verify a complete-enough effective share path inventory. Missing or
        # variable share paths make the destination's isolation unprovable.
        syn_smb_config >/dev/null || { lin_error 'Cannot verify share roots; quarantine refused.'; return 1; }
        local share share_count=0
        while IFS= read -r share; do
            [[ $share == /* && $share != *'%'* && $share != *'$'* ]] || { lin_error 'Unresolved share path; quarantine refused.'; return 1; }
            share=$(cd -- "$share" 2>/dev/null && pwd -P) || { lin_error 'Cannot resolve a share root; quarantine refused.'; return 1; }
            ((share_count+=1))
            [[ $base != "$share" && $base != "$share/"* && $share != / ]] || { lin_error 'Quarantine directory is inside a configured share.'; return 1; }
        done < <(awk '/^[ \t]*path[ \t]*=/ {sub(/^[^=]*=[ \t]*/, "");sub(/[ \t]+$/, "");print}' <<<"$SYN_SHARE_CONFIG")
        (( share_count > 0 )) || { lin_error 'No share roots available; quarantine refused.'; return 1; }
        syn_emit "CHANGES SYSTEM: source [$path]; destination [$base/<unique transaction>/owner-file]"
    else
        original=$(syn_owner_transaction inspect "$path") || return
        syn_emit "CHANGES SYSTEM: manifest [$path]; restore destination [$original]"
    fi
    document=$(syn_owner_original "$original") || return
    syn_smb_proof_clear "$original" "$document" || return
    answer=$(lin_read 'Type NOBODY IS EDITING to confirm you checked with users (SMB snapshots cannot prove this): ') || return
    [[ $answer == 'NOBODY IS EDITING' ]] || { syn_emit 'Cancelled; no file moved.'; return 1; }
    syn_smb_proof_clear "$original" "$document" || return
    if syn_owner_transaction "$mode" "$path"; then syn_emit "[OK] $mode completed and filesystem identity verified."
    else syn_emit "[FAILED] $mode; inspect manifest and file locations before retrying.";return 1;fi
}
syn_office_menu() {
    local choice path depth
    while true; do
        lin_header 'Synology > Office file locks'
        lin_menu_item 1 'Find and inspect owner files (~$; bounded search)'
        lin_menu_item 2 'Inspect one owner file and SMB correlations'
        lin_menu_item 3 'Quarantine owner file [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 4 'Restore quarantined owner file [CHANGES SYSTEM]' "$LIN_YELLOW"
        lin_menu_item 0 'Back'
        choice=$(lin_read 'Select: ') || return
        [[ $choice != 0 && ${choice^^} != B ]] || return
        case $choice in
            1) path=$(syn_input 'Absolute directory') || continue;depth=$(syn_input 'Recursion depth 0-5') || continue;syn_owner_find "$path" "$depth" || true ;;
            2) path=$(syn_input 'Exact owner-file path') && syn_owner_inspect "$path" || true ;;
            3) path=$(syn_input 'Exact owner-file path') && syn_owner_change quarantine "$path" || true ;;
            4) path=$(syn_input 'Exact private manifest.json path') && syn_owner_change restore "$path" || true ;;
        esac
        lin_pause
    done
}
