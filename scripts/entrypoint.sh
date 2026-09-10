#!/usr/bin/env bash
set -euo pipefail

storage_dirs=(
    storage/app
    storage/framework/cache
    storage/framework/cache/cms
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
    # Probe as www-data. A non-root owner (e.g. UID 1000 bind mount mode 0755) is
    # not necessarily writable by UID 33 — do not infer writability from ownership.
    # setpriv is required for OCTOBER_RUNTIME_USER drops and is present on these images.
    if ! command -v setpriv >/dev/null 2>&1; then
        return 1
    fi
    setpriv --reuid=www-data --regid=www-data --clear-groups -- test -w "${path}"
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

if [ -f /var/www/html/artisan ]; then
    mkdir -p /var/www/html/storage/framework/cache/cms
    rm -f /var/www/html/storage/framework/cache/cms/disabled.php
    if id www-data >/dev/null 2>&1; then
        su -s /bin/sh www-data -c 'cd /var/www/html && php artisan about' >/dev/null || true
    else
        (cd /var/www/html && php artisan about >/dev/null) || true
    fi
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
