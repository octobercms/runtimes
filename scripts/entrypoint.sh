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

for dir in "${storage_dirs[@]}"; do
    path="/var/www/html/${dir}"
    mkdir -p "${path}"

    if id www-data >/dev/null 2>&1; then
        chown -R www-data:www-data "${path}"
    fi
done

if [ -f /var/www/html/artisan ]; then
    mkdir -p /var/www/html/storage/framework/cache/cms
    rm -f /var/www/html/storage/framework/cache/cms/disabled.php
    if id www-data >/dev/null 2>&1; then
        su -s /bin/sh www-data -c 'cd /var/www/html && php artisan about' >/dev/null || true
    else
        (cd /var/www/html && php artisan about >/dev/null) || true
    fi
fi

october_scheduler_wanted() {
    case "$(printf '%s' "${OCTOBER_SCHEDULER_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

configure_supervisor_scheduler() {
    local drop_in="/etc/supervisor/conf.d/scheduler.conf"

    if october_scheduler_wanted; then
        return
    fi

    echo "October scheduler disabled (OCTOBER_SCHEDULER_ENABLED=${OCTOBER_SCHEDULER_ENABLED:-false})."
    rm -f "${drop_in}"
}

if [[ "${1:-}" == /usr/bin/supervisord ]]; then
    configure_supervisor_scheduler
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
