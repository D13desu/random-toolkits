#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/lin/Linux-Toolkit.sh"
fail(){ printf 'FAIL: %s\n' "$*" >&2;exit 1; }
pass(){ printf 'PASS: %s\n' "$*"; }
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
for f in "$repo_root"/lin/modules/Synology*.sh; do bash -n "$f";done
pass 'All Synology modules parse on Bash'
# Fixture uses the exact production availability matrix, without requiring DSM.
mkdir -p "$work/outside-path"
for name in id wbinfo synouser synogroup synoacltool synoshare smbstatus testparm synosystemctl synopkg synodisk synostgpool smartctl mdadm;do
 printf '#!/bin/sh\nprintf "fixture\\n"\n' > "$work/outside-path/$name";chmod +x "$work/outside-path/$name"
done
ln -s "$work/outside-path/synoacltool" "$work/outside-path/acl-link"
saved_dirs=("${SYN_COMMAND_DIRS[@]}")
SYN_COMMAND_DIRS=("$work/outside-path")
for name in wbinfo synouser synogroup synoacltool synoshare smbstatus testparm synosystemctl synopkg synodisk synostgpool;do
 [[ $(syn_resolve "$name") == "$work/outside-path/$name" ]] || fail "Outside-PATH resolution: $name"
done
[[ $(syn_resolve acl-link) == "$work/outside-path/acl-link" ]] || fail 'Symlink executable resolution'
! syn_resolve absent-synology-command >/dev/null || fail 'Missing utility not detected'
! syn_resolve '../bin/id' >/dev/null || fail 'Resolver accepted path injection'
SYN_COMMAND_DIRS=("${saved_dirs[@]}")
while IFS=$'\t' read -r name location;do
 if [[ $location == MISSING ]];then [[ $name == getent || $name == synoservice ]] || fail 'Unexpected missing production command';continue;fi
 matched=0
 for directory in "${saved_dirs[@]}";do [[ ${location%/*} != "$directory" ]] || matched=1;done
 [[ $matched == 1 ]] || fail "Production directory not searched: $location"
done < "$repo_root/tests/fixtures/synology-commands.tsv"
pass 'Production matrix outside PATH, executable symlinks and missing optional tools'
# Linux host is not DSM; no legacy command or getent is needed to load or return.
if ! syn_is_dsm;then
 lin_pause(){ :; }
 output=$(synology_menu)
 [[ $output == *'DSM was not detected'* ]] || fail 'Non-DSM guard'
fi
pass 'Non-Synology environments retain generic Linux behavior'
# Execution failure classes are distinct, not confused with empty output.
cat > "$work/outside-path/diagfixture" <<'EOF'
#!/bin/sh
case "$1" in
 denied) echo 'Permission denied' >&2;exit 1;;
 badarg) echo 'unknown option' >&2;exit 2;;
 fail) echo 'unexpected failure' >&2;exit 5;;
 empty) exit 0;;
esac
EOF
chmod +x "$work/outside-path/diagfixture"
SYN_COMMAND_DIRS=("$work/outside-path" "${saved_dirs[@]}")
if syn_capture diagfixture denied;then fail 'Denied command succeeded';fi
[[ $SYN_STATE == PRIVILEGE ]] || fail 'Privilege error classification'
if syn_capture diagfixture badarg;then fail 'Invalid arguments succeeded';fi
[[ $SYN_STATE == UNSUPPORTED ]] || fail 'Unsupported argument classification'
if syn_capture diagfixture fail;then fail 'Failure succeeded';fi
[[ $SYN_STATE == FAILED ]] || fail 'Failure classification'
syn_capture diagfixture empty
[[ $SYN_STATE == OK && -z $SYN_OUT ]] || fail 'Successful empty result'
if syn_capture no-such-synology-utility;then fail 'Missing command succeeded';fi
[[ $SYN_STATE == UNAVAILABLE ]] || fail 'Missing command classification'
pass 'Missing, unsupported, privilege, failed and successful-empty command states'
syn_help(){ printf '%s\n' 'Usage: --locks -L --json -j --processes -p --shares -S --get --get-perm --uid-info --gid-info --ping-dc'; }
syn_supports smbstatus --locks || fail 'Long-option capability detection'
! syn_supports smbstatus --lock || fail 'Partial option incorrectly accepted'
syn_supports smbstatus -L || fail 'Short-option capability detection'
pass 'Only advertised complete options are enabled'
mkdir -p "$work/folder with spaces ñ"
touch "$work/folder with spaces ñ/report & [2026].xlsx"
target="$work/folder with spaces ñ/report & [2026].xlsx"
syn_capture(){
 local cmd=$1;shift
 SYN_STATE=OK
 case $cmd in
  synoacltool)
   if [[ $1 == -get-perm ]];then
    [[ $2 == "$target" && $3 == 'DOMAIN\Some User' ]] || fail 'ACL path/identity argument boundaries'
    SYN_OUT='Perm: [rwxpd-aARWc--]'
   else SYN_OUT=$'user:admin:deny:rwxpdDaARWcCo:fd-- (level:0)\ngroup:DOMAIN\\Some Group:allow:rwxpdDaARWc--:fd-- (level:2)\nuser::allow:rwxpdDaARWc--:fd-- (level:3)';fi;;
  stat) SYN_OUT='Filesystem owner=fixture';;
  id) [[ $1 == 'DOMAIN\Some User' ]] || fail 'Identity backslash changed'; SYN_OUT='uid=1000 user gid=100 users groups=100 users';;
  *) SYN_OUT='';;
 esac
}
output=$(syn_acl_get "$target")
[[ $output == *'explicit (level 0)'* && $output == *'inherited (ancestor level 2)'* && $output == *'Unresolved user identity'* ]] || fail 'ACL inheritance/unresolved parsing'
syn_acl_effective "$target" 'DOMAIN\Some User' >/dev/null
[[ $SYN_EFFECTIVE == 'rwxpd-aARWc--' && $SYN_EFFECTIVE_STATE == OK ]] || fail 'Authoritative effective permissions'
output=$(syn_permission_flags 'rwxpd-aARWc--' file)
[[ $output == *'not required on an individual file'* ]] || fail 'File delete-child semantics'
output=$(syn_permission_flags 'rwxpdDaARWc--' directory)
[[ $output == *'Delete child objects'* ]] || fail 'Directory delete-child interpretation'
syn_identity 'DOMAIN\Some User' >/dev/null
! syn_identity_arg '-bad' || fail 'Option injection identity accepted'
pass 'Domain identities, Unicode/metacharacter paths, ACL flags and inheritance'
# JSON parser accepts only the documented schema. Capture is mocked, parser real.
syn_smb_snapshot(){ SYN_SMB_JSON=${fixture_json:-}; [[ ${fixture_state:-OK} == OK ]]; }
fixture_json='{"sessions":{},"tcons":{},"open_files":{}}'
SYN_SMB_JSON=$fixture_json
syn_smb_json_match "$target" 1 || fail 'Empty JSON rejected'
[[ -z $SYN_SMB_MATCHES ]] || fail 'Empty handles produced matches'
fixture_json='{"sessions":{"1":{"server_id":{"pid":"42"},"username":"DOMAIN\\user","remote_machine":"192.0.2.1"}},"tcons":{},"open_files":{"x":{"service_path":"/volume1/Share with spaces","filename":"report ñ.xlsx","opens":{"1":{"server_id":{"pid":"42"}}}}}}'
SYN_SMB_JSON=$fixture_json
syn_smb_json_match '/volume1/Share with spaces/report ñ.xlsx' 1
[[ $SYN_SMB_MATCHES == *'DOMAIN'* && $SYN_SMB_MATCHES == *'192.0.2.1'* && $SYN_SMB_MATCHES == *'42'* ]] || fail 'Structured PID/session correlation'
syn_smb_json_match 'ñ.xlsx'
[[ -n $SYN_SMB_MATCHES ]] || fail 'Partial Unicode search'
fixture_json='{"sessions":{},"tcons":{},"open_files":{"x":{"unexpected":true}}}'
SYN_SMB_JSON=$fixture_json
SYN_SMB_JSON=$fixture_json
if syn_smb_json_match "$target" 1 2>/dev/null;then fail 'Unknown schema accepted';fi
fixture_json='not JSON';SYN_SMB_JSON=$fixture_json
SYN_SMB_JSON=$fixture_json
if syn_smb_json_match "$target" 1 2>/dev/null;then fail 'Malformed JSON accepted';fi
syn_is_root(){ return 0; }
fixture_state=FAILED
! syn_smb_proof_clear "$target" 2>/dev/null || fail 'Failed snapshot authorized mutation'
fixture_state=OK;fixture_json='{"sessions":{},"tcons":{},"open_files":{}}'
syn_smb_proof_clear "$target" || fail 'Valid empty structured snapshot rejected'
fixture_json='{"sessions":{},"tcons":{},"open_files":{"x":{"service_path":"/volume1/share","filename":"~$report.xlsx","opens":{"1":{"server_id":{"pid":"42"}}}}}}'
SYN_SMB_JSON=$fixture_json
! syn_smb_proof_clear '/volume1/share/~$report.xlsx' >/dev/null 2>&1 || fail 'Active handles authorized mutation'
pass 'SMB empty/failed/malformed snapshots, exact paths, active handles and PID candidates'
# Office heuristics never convert absence of handles into a confirmed root cause.
owner="$work/folder with spaces ñ/~\$report & [2026].xlsx"
printf 'Office User\n' > "$owner"
[[ $(syn_owner_original "$owner") == "$target" ]] || fail 'Owner to original name mapping'
fixture_json='{"sessions":{},"tcons":{},"open_files":{}}'
SYN_SMB_JSON=$fixture_json
output=$(syn_owner_inspect "$owner")
[[ $output == *'Potentially stale'* && $output == *'unconfirmed'* && $output == *'Filesystem owner'* ]] || fail 'Stale-owner advisory'
missing="$work/folder with spaces ñ/~\$missing.xlsx";touch "$missing"
output=$(syn_owner_inspect "$missing")
[[ $output == *'No original at literal stripped-name path'* ]] || fail 'Orphan owner diagnostic'
fixture_state=FAILED
output=$(syn_owner_inspect "$owner")
[[ $output == *'Cannot assess'* && $output != *'Potentially stale'* ]] || fail 'Failed SMB lookup marked stale'
fixture_state=OK
pass 'Owner metadata, missing originals and cautious stale-file assessments'
# Orchestration fixtures: destination collision / replaced owner must block.
SYN_MOVED=0;SYN_PROOFS=0
syn_owner_transaction(){
 case $1 in
  prepare) printf '%s' "$work/private";;
  inspect) [[ ${restore_collision:-0} == 0 ]] || return 1;printf '%s' "$owner";;
  quarantine|restore) printf '%s\n' "$1" >> "$work/moves";return "${move_fail:-0}";;
 esac
}
syn_smb_config(){ SYN_SHARE_CONFIG=$'[share]\npath = /tmp'; }
# Quarantine location must be outside shares; use an unrelated, real directory.
mkdir -p "$work/share"
syn_smb_config(){ SYN_SHARE_CONFIG="[share]"$'\n'"path = $work/share"; }
syn_smb_proof_clear(){ SYN_PROOFS=$((SYN_PROOFS+1)); [[ ${active_handle:-0} == 0 ]]; }
lin_read(){ printf '%s' "${CONFIRM_REPLY:-NOBODY IS EDITING}"; }
active_handle=1
! syn_owner_change quarantine "$owner" >/dev/null || fail 'Active handles permitted move'
[[ ! -e $work/moves ]] || fail 'Moved with active handles'
active_handle=0;CONFIRM_REPLY=no
! syn_owner_change quarantine "$owner" >/dev/null || fail 'Unconfirmed move succeeded'
[[ ! -e $work/moves ]] || fail 'Moved without confirmation'
CONFIRM_REPLY='NOBODY IS EDITING'
syn_owner_change quarantine "$owner" >/dev/null
[[ $(cat "$work/moves") == quarantine && $SYN_PROOFS -ge 2 ]] || fail 'Quarantine did not recheck or invoke transaction'
restore_collision=1
! syn_owner_change restore /private/manifest.json >/dev/null || fail 'Restored over recreated owner'
restore_collision=0
syn_owner_change restore /private/manifest.json >/dev/null
[[ $(tail -n 1 "$work/moves") == restore ]] || fail 'Restore not routed through guarded transaction'
syn_is_root(){ return 1; }
! syn_owner_change quarantine "$owner" >/dev/null 2>&1 || fail 'Non-root quarantine allowed'
pass 'Root gate, explicit confirmation, repeated handle checks and restore collision refusal'
# Reports contain curated findings only; never raw sessions/logs/config/owner bytes.
SYN_REPORT='password=do-not-export token=secret';SYN_LAST_GUIDED=$'[OK] Fixture result\n[TODO] Manual share verification'
mkdir -m 700 "$work/reports"
syn_input(){ printf '%s' "$work/reports"; }
syn_export >/dev/null
report=$(find "$work/reports" -type f -name '*.txt' -print -quit)
[[ -n $report && $(stat -c '%a' "$report") == 600 ]] || fail 'Report is not private'
! grep -q 'do-not-export\|token=secret' "$report" || fail 'Raw secrets entered report'
grep -q 'Fixture result' "$report" || fail 'Curated findings missing'
pass 'Private timestamped reports omit raw evidence and secrets'
printf 'Synology tests passed (fixtures/mocks; no production DSM validation).\n'

python3 "$repo_root/tests/Test-SynologyTransactions.py"
