#!/usr/bin/env bash
set -euo pipefail

# OCTOBER_SCHEDULER_ENABLED defaults to true so production containers run
# Laravel's schedule:work automatically. Set to false/0/off/no to disable.
enabled="${OCTOBER_SCHEDULER_ENABLED:-true}"
normalized="$(printf '%s' "${enabled}" | tr '[:upper:]' '[:lower:]')"

case "${normalized}" in
    0|false|no|off)
        echo "October scheduler disabled (OCTOBER_SCHEDULER_ENABLED=${enabled})."
        exec sleep infinity
        ;;
esac

if [[ ! -f /var/www/html/artisan ]]; then
    echo "October scheduler waiting: /var/www/html/artisan not found."
    exec sleep infinity
fi

cd /var/www/html
exec php artisan schedule:work
