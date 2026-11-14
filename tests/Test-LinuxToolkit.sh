#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
toolkit="$repo_root/lin/Linux-Toolkit.sh"
endpoint="$repo_root/lin/index.html"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

bash -n "$toolkit"
pass 'Assembled toolkit parses as Bash'

cmp -s "$toolkit" "$endpoint" || fail 'Published endpoint differs from assembled toolkit'
pass 'Published endpoint matches the toolkit byte-for-byte'

version=$(tr -d '\r\n' < "$repo_root/lin/VERSION")
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'VERSION is not semantic'
grep -Fq "Linux Toolkit $version" "$toolkit" || fail 'Toolkit header version does not match VERSION'
pass 'Version is synchronized'

checks=$(bash "$toolkit" --list)
for id in system resources storage network services security updates containers; do
    grep -Eq "^${id}[[:space:]]" <<<"$checks" || fail "Missing check: $id"
done
pass 'All read-only checks are registered'

help=$(bash "$toolkit" --help)
grep -Fq 'never invoke sudo' <<<"$help" || fail 'Help omits the sudo safety boundary'
pass 'Help documents the privilege boundary'

colour_sample=$(bash -c 'source "$1"; LIN_GREEN=$'"'"'\033[32m'"'"'; LIN_RESET=$'"'"'\033[0m'"'"'; lin_menu_item 1 "Read-only check"' _ "$toolkit")
[[ $colour_sample == *$'\033[32m[1]\033[0m'* ]] || fail 'Menu item omitted its semantic colour'
plain_sample=$(NO_COLOR=1 bash "$toolkit" --check system)
[[ $plain_sample != *$'\033['* ]] || fail 'NO_COLOR output contains ANSI escapes'
pass 'Semantic colours and the NO_COLOR opt-out work'

set +e
bash "$toolkit" --check unknown >/dev/null 2>&1
status=$?
set -e
[[ $status -eq 2 ]] || fail 'Unknown check did not return exit code 2'
pass 'Unknown checks are rejected'

system_output=$(bash "$toolkit" --check system)
grep -Fq 'Operating system:' <<<"$system_output" || fail 'System check omitted operating system'
grep -Fq 'Kernel:' <<<"$system_output" || fail 'System check omitted kernel'
pass 'System check returns structured output'

source "$toolkit"
[[ $(lin_package_manager || true) =~ ^(apt-get|dnf|yum|zypper|pacman|apk)?$ ]] || fail 'Package manager detection returned an unsupported value'
pass 'Package-manager detection is bounded'

grep -Fq 'lin_require_root' "$repo_root/lin/modules/Maintenance.sh" || fail 'Maintenance actions lack a root gate'
if grep -Eq '(^|[;&|[:space:]])sudo([[:space:]]|$)' "$repo_root/lin/modules/"*.sh; then fail 'A Linux module invokes sudo'; fi
pass 'Maintenance is root-gated and never invokes sudo'

printf 'All Linux Toolkit tests passed.\n'
