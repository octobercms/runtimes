ARG BUILD_IMAGE=ghcr.io/octobercms/runtime-build:php85
FROM ${BUILD_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    bash \
    less \
    libpq5 \
    libpq-dev \
    libsqlite3-0 \
    libsqlite3-dev \
    nginx \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pdo_sqlite \
    && { apt-mark auto libc6-dev libcrypt-dev linux-libc-dev libc-dev-bin rpcsvc-proto >/dev/null 2>&1 || true; } \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        $PHPIZE_DEPS \
        libpq-dev \
        libsqlite3-dev \
    && apt-mark manual libpq5 libsqlite3-0 >/dev/null \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
