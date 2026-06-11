#!/usr/bin/env bash
set -euo pipefail

storage_dirs=(
    storage/app
    storage/framework/cache
    storage/framework/sessions
    storage/framework/views
    storage/logs
    storage/cms
    storage/system
    storage/temp
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

bash /usr/local/bin/devcontainer-configure-app-url.sh

port_open() {
    (echo >/dev/tcp/127.0.0.1/"$1") 2>/dev/null
}

if port_open 9000; then
    :
else
    php-fpm -D
fi

if port_open 80; then
    nginx -s reload
else
    nginx
fi

for _ in $(seq 1 30); do
    if curl -sf http://127.0.0.1/_health >/dev/null; then
        exit 0
    fi
    sleep 1
done

echo "post-start: /_health did not become ready" >&2
exit 1
