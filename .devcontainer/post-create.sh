#!/usr/bin/env bash
set -euo pipefail

app_root=/var/www/html
october_repo=https://github.com/octobercms/october.git
october_branch=4.x

find "${app_root}" -mindepth 1 -delete

git clone --depth 1 --branch "${october_branch}" "${october_repo}" "${app_root}"

cd "${app_root}"

export COMPOSER_MEMORY_LIMIT=-1

if [[ ! -f .env ]]; then
    cp .env.example .env
fi

sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${app_root}/database/database.sqlite|" .env

mkdir -p \
    database \
    bootstrap/cache \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    storage/app/public \
    storage/temp/public \
    storage/cms \
    storage/system

touch database/database.sqlite

composer install --no-interaction

bash /usr/local/bin/devcontainer-configure-app-url.sh

if grep -q '^APP_KEY=$' .env || grep -q '^APP_KEY=""$' .env; then
    php -d memory_limit=512M artisan key:generate --force
fi

php -d memory_limit=512M artisan october:migrate --force
php -d memory_limit=512M artisan tailor:migrate
php -d memory_limit=512M artisan theme:seed demo

if id www-data >/dev/null 2>&1; then
    chown -R www-data:www-data database storage bootstrap/cache
fi
