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

runtime_www_user="www-data"
runtime_www_group="www-data"

ensure_storage_layout() {
    local base="/var/www/html"
    local dir path

    for dir in "${storage_dirs[@]}"; do
        mkdir -p "${base}/${dir}"
    done

    if ! id "${runtime_www_user}" >/dev/null 2>&1; then
        return
    fi

    fix_tree_if_wrong_root() {
        local tree="$1"
        [[ -d "${tree}" ]] || return 0
        if [[ "$(stat -c '%U' "${tree}")" != "${runtime_www_user}" ]]; then
            chown -R "${runtime_www_user}:${runtime_www_group}" "${tree}"
        fi
    }

    fix_tree_if_wrong_root "${base}/storage"
    fix_tree_if_wrong_root "${base}/bootstrap/cache"
    fix_tree_if_wrong_root "${base}/database"

    for dir in "${storage_dirs[@]}"; do
        path="${base}/${dir}"
        [[ -e "${path}" ]] || continue
        if [[ "$(stat -c '%U:%G' "${path}")" != "${runtime_www_user}:${runtime_www_group}" ]]; then
            chown "${runtime_www_user}:${runtime_www_group}" "${path}"
        fi
    done
}

ensure_storage_layout

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

# Worker (and similar runtimes): drop to OCTOBER_RUNTIME_USER once, then cache-warm and exec CMD.
if [[ "$(id -u)" -eq 0 && -n "${OCTOBER_RUNTIME_USER:-}" ]] && id "${OCTOBER_RUNTIME_USER}" >/dev/null 2>&1; then
    passwd_home="$(getent passwd "${OCTOBER_RUNTIME_USER}" | cut -d: -f6 || true)"
    export HOME="${passwd_home:-/var/www}"
    export PGSSLCERT="${PGSSLCERT:-/tmp/postgresql.crt}"
    exec setpriv --reuid="${OCTOBER_RUNTIME_USER}" --regid="${OCTOBER_RUNTIME_USER}" --init-groups -- \
        bash -c '
            if [ -f /var/www/html/artisan ]; then
                mkdir -p /var/www/html/storage/framework/cache/cms
                rm -f /var/www/html/storage/framework/cache/cms/disabled.php
                (cd /var/www/html && php artisan about >/dev/null) || true
            fi
            exec "$@"
        ' bash "$@"
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

exec "$@"
