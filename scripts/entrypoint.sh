#!/usr/bin/env bash
set -euo pipefail

storage_dirs=(
    storage/app
    storage/framework/cache
    storage/framework/sessions
    storage/framework/views
    storage/logs
    bootstrap/cache
    database
)

should_chown_storage() {
    local value
    value="$(printf '%s' "${OCTOBER_CHOWN_STORAGE:-false}" | tr '[:upper:]' '[:lower:]')"
    case "${value}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

dir_writable_by_www_data() {
    local path="$1"
    # Avoid recursive walks; probe writability as www-data when possible.
    if command -v setpriv >/dev/null 2>&1; then
        setpriv --reuid=www-data --regid=www-data --clear-groups -- test -w "${path}"
        return $?
    fi
    # Fallback when setpriv is unavailable: reject root-owned paths.
    local owner
    owner="$(stat -c '%u' "${path}" 2>/dev/null || echo 0)"
    [[ "${owner}" != "0" ]]
}

for dir in "${storage_dirs[@]}"; do
    path="/var/www/html/${dir}"
    mkdir -p "${path}"

    if ! id www-data >/dev/null 2>&1; then
        continue
    fi

    if should_chown_storage; then
        # Opt-in: full recursive chown for unusual volume ownership layouts.
        chown -R www-data:www-data "${path}"
    elif ! dir_writable_by_www_data "${path}"; then
        # Fix the directory itself only — app images should chown trees at build time.
        chown www-data:www-data "${path}"
    fi
done

scheduler_enabled() {
    local value
    value="$(printf '%s' "${OCTOBER_SCHEDULER_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
    case "${value}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# Supervisor expands %(ENV_OCTOBER_SCHEDULER_AUTOSTART)s at start; keep it in sync
# with OCTOBER_SCHEDULER_ENABLED so a disabled scheduler adds no idle process.
if scheduler_enabled; then
    export OCTOBER_SCHEDULER_AUTOSTART=true
else
    export OCTOBER_SCHEDULER_AUTOSTART=false
fi

if [[ "$(id -u)" -eq 0 && -n "${OCTOBER_RUNTIME_USER:-}" ]]; then
    if id "${OCTOBER_RUNTIME_USER}" >/dev/null 2>&1; then
        # Dropping uid without fixing HOME leaves HOME=/root; libpq then fails opening
        # /root/.postgresql/postgresql.crt with Permission denied on SSL connects.
        passwd_home="$(getent passwd "${OCTOBER_RUNTIME_USER}" | cut -d: -f6 || true)"
        export HOME="${passwd_home:-/var/www}"
        export PGSSLCERT="${PGSSLCERT:-/tmp/postgresql.crt}"
        exec setpriv --reuid="${OCTOBER_RUNTIME_USER}" --regid="${OCTOBER_RUNTIME_USER}" --init-groups -- "$@"
    fi
fi

exec "$@"
