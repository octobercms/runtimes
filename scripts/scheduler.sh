#!/usr/bin/env bash
set -euo pipefail

# OCTOBER_SCHEDULER_ENABLED defaults to false. Set to true/1/on/yes to run
# Laravel's schedule:work in the production container.
enabled="${OCTOBER_SCHEDULER_ENABLED:-false}"
normalized="$(printf '%s' "${enabled}" | tr '[:upper:]' '[:lower:]')"

case "${normalized}" in
    1|true|yes|on)
        ;;
    *)
        echo "October scheduler disabled (OCTOBER_SCHEDULER_ENABLED=${enabled})."
        exec sleep infinity
        ;;
esac

if [[ ! -f /var/www/html/artisan ]]; then
    echo "October scheduler waiting: /var/www/html/artisan not found."
    exec sleep infinity
fi

if ! cd /var/www/html; then
    echo "October scheduler waiting: cannot access /var/www/html."
    exec sleep infinity
fi

exec php artisan schedule:work
