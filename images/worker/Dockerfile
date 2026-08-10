ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libsqlite3-dev \
    && docker-php-ext-install -j"$(nproc)" \
        pcntl \
        pdo_pgsql \
        pdo_sqlite \
        posix \
    && rm -rf /var/lib/apt/lists/*

COPY config/php/runtime.ini /usr/local/etc/php/conf.d/runtime.ini
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENV OCTOBER_RUNTIME_USER=www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php", "artisan", "queue:work"]
