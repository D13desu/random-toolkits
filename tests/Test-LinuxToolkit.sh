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
for id in health system resources storage network services security updates applications apache nginx postgres tls containers; do
    grep -Eq "^${id}[[:space:]]" <<<"$checks" || fail "Missing check: $id"
done
pass 'All read-only checks are registered'

help=$(bash "$toolkit" --help)
grep -Fq 'never invoke sudo' <<<"$help" || fail 'Help omits the sudo safety boundary'
pass 'Help documents the privilege boundary'

source "$toolkit"

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

[[ $(lin_usage_status 79) == OK ]] || fail '79 percent should be OK'
[[ $(lin_usage_status 80) == REVIEW ]] || fail '80 percent should require review'
[[ $(lin_usage_status 90) == WARNING ]] || fail '90 percent should be a warning'
pass 'Friendly usage thresholds are explicit and stable'

storage_output=$(bash "$toolkit" --check storage)
grep -Fq 'Overall status:' <<<"$storage_output" || fail 'Storage summary omitted its overall status'
grep -Fq 'Raw evidence:' <<<"$storage_output" || fail 'Storage summary omitted its raw-evidence route'
raw_storage=$(bash "$toolkit" --check storage --raw)
grep -Fq 'Storage raw evidence' <<<"$raw_storage" || fail 'Storage raw mode did not run'
pass 'Friendly storage summary retains raw evidence'

network_output=$(bash "$toolkit" --check network)
grep -Fq 'Primary connection' <<<"$network_output" || fail 'Network summary omitted the primary connection'
grep -Fq 'Listening services' <<<"$network_output" || fail 'Network summary omitted listening services'
grep -Fq 'does not prove firewall reachability' <<<"$network_output" || fail 'Network exposure label omitted its limitation'
pass 'Friendly network summary explains listener exposure'

services_output=$(bash "$toolkit" --check services)
grep -Eq 'Failed services|Service manager' <<<"$services_output" || fail 'Services summary omitted service-manager status'
grep -Fq 'Raw evidence:' <<<"$services_output" || fail 'Services summary omitted its raw-evidence route'
pass 'Friendly services summary handles the active service manager'

updates_output=$(bash "$toolkit" --check updates)
grep -Fq 'Package manager:' <<<"$updates_output" || fail 'Updates summary omitted the package manager'
grep -Fq 'Package metadata is not refreshed' <<<"$updates_output" || fail 'Updates summary overstated metadata freshness'
grep -Fq 'Raw evidence:' <<<"$updates_output" || fail 'Updates summary omitted its raw-evidence route'
pass 'Friendly updates summary states its metadata boundary'

health_output=$(bash "$toolkit" --check health 2>&1)
[[ $health_output != *'awk:'* ]] || fail 'Health summary emitted an awk compatibility error'
if grep -Eq 'awk[^\n]*-v[[:space:]]+load=' "$repo_root/lin/modules/Health.sh"; then fail 'Health summary reuses the gawk built-in name load'; fi
grep -Fq 'Root filesystem' <<<"$health_output" || fail 'Health summary omitted root storage'
grep -Fq 'Available updates' <<<"$health_output" || fail 'Health summary omitted updates'
grep -Fq 'Non-local listeners' <<<"$health_output" || fail 'Health summary omitted listeners'
pass 'Combined health summary covers core review areas'

applications_output=$(bash "$toolkit" --check applications 2>&1)
for label in Apache Nginx PostgreSQL 'TLS certificates' Containers; do
    grep -Fq "$label" <<<"$applications_output" || fail "Application summary omitted $label"
done
pass 'Application summary covers web, database, TLS, and containers'

[[ $(lin_tls_days_status -1) == WARNING ]] || fail 'Expired TLS certificate should be a warning'
[[ $(lin_tls_days_status 30) == REVIEW ]] || fail 'TLS certificate at 30 days should require review'
[[ $(lin_tls_days_status 31) == OK ]] || fail 'TLS certificate beyond 30 days should be OK'
pass 'TLS expiry thresholds are explicit'

container_module=$(cat "$repo_root/lin/modules/Containers.sh")
[[ $container_module == *"lin_section 'Environment variables'"* ]] || fail 'Container details do not label environment values'
[[ $container_module != *'<redacted>'* && $container_module != *'lin_redact_env'* ]] || fail 'Container environment values are still redacted'
pass 'Container environment values remain visible'

apache2ctl() {
    case ${1:-} in
        -v) printf 'Server version: Apache/2.4.test\n' ;;
        configtest) printf 'Syntax OK\n' ;;
        -M) printf ' core_module (static)\n ssl_module (shared)\n' ;;
        -S) printf 'port 443 namevhost example.test (/etc/apache2/sites-enabled/example.conf:1)\n' ;;
    esac
}
apache_fixture=$(lin_apache_summary)
grep -Fq 'Apache/2.4.test' <<<"$apache_fixture" || fail 'Apache version was not normalized'
grep -Fq 'config syntax OK' <<<"$apache_fixture" || fail 'Apache config-test result was not normalized'
pass 'Apache settings collector normalizes command output'

nginx() {
    case ${1:-} in
        -v) printf 'nginx version: nginx/1.26.test\n' >&2 ;;
        -t) printf 'configuration file syntax is ok\n' >&2 ;;
    esac
}
nginx_fixture=$(lin_nginx_summary)
grep -Fq 'nginx 1.26.test' <<<"$nginx_fixture" || fail 'Nginx version was not normalized'
grep -Fq 'config syntax OK' <<<"$nginx_fixture" || fail 'Nginx config-test result was not normalized'
pass 'Nginx settings collector normalizes command output'

psql() {
    if [[ ${1:-} == --version ]]; then printf 'psql (PostgreSQL) 16.test\n'; else printf 'port\t5432\n'; fi
}
pg_isready() { printf '127.0.0.1:5432 - accepting connections\n'; }
postgres_fixture=$(lin_postgres_summary)
grep -Fq 'PostgreSQL 16.test' <<<"$postgres_fixture" || fail 'PostgreSQL version was not normalized'
grep -Fq 'accepting connections' <<<"$postgres_fixture" || fail 'PostgreSQL readiness was not normalized'
pass 'PostgreSQL readiness collector normalizes command output'

dnf() { printf 'curl.x86_64 8.1.2-1 updates\n'; }
dnf_rows=$(lin_collect_updates dnf)
grep -Fq $'curl.x86_64\t8.1.2-1\tupdates' <<<"$dnf_rows" || fail 'DNF updates were not normalized'
pacman() { printf 'curl 8.1.1-1 -> 8.1.2-1\n'; }
pacman_rows=$(lin_collect_updates pacman)
grep -Fq $'curl\t8.1.2-1\tfrom 8.1.1-1' <<<"$pacman_rows" || fail 'Pacman updates were not normalized'
pass 'Update collectors normalize multiple distribution formats'

ss() {
    printf 'tcp LISTEN 0 128 127.0.0.1:22 0.0.0.0:*\n'
    printf 'tcp LISTEN 0 128 0.0.0.0:443 0.0.0.0:*\n'
}
listener_rows=$(lin_listener_rows)
grep -Fq $'Local only\tOK' <<<"$listener_rows" || fail 'Loopback listener was not classified as local'
grep -Fq $'All interfaces\tREVIEW' <<<"$listener_rows" || fail 'Wildcard listener was not classified for review'
pass 'Listener exposure classification is deterministic'

[[ $(lin_package_manager || true) =~ ^(apt-get|dnf|yum|zypper|pacman|apk)?$ ]] || fail 'Package manager detection returned an unsupported value'
pass 'Package-manager detection is bounded'

grep -Fq 'lin_require_root' "$repo_root/lin/modules/Maintenance.sh" || fail 'Maintenance actions lack a root gate'
if grep -Eq '(^|[;&|[:space:]])sudo([[:space:]]|$)' "$repo_root/lin/modules/"*.sh; then fail 'A Linux module invokes sudo'; fi
pass 'Maintenance is root-gated and never invokes sudo'

printf 'All Linux Toolkit tests passed.\n'
