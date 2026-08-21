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
        chown -R www-data:www-data /var/www/html/storage/framework/cache
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
