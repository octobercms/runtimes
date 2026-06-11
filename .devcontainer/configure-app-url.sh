#!/usr/bin/env bash
set -euo pipefail

APP_URL=http://localhost

if [[ -f .env ]]; then
    sed -i "s|^APP_URL=.*|APP_URL=${APP_URL}|" .env
fi

php artisan config:clear --quiet 2>/dev/null || true
php artisan cache:clear --quiet 2>/dev/null || true

echo "APP_URL=${APP_URL}"
