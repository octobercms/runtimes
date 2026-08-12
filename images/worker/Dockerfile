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

ENV OCTOBER_RUNTIME_USER=www-data \
    HOME=/var/www \
    PGSSLCERT=/tmp/postgresql.crt

# www-data must not inherit HOME=/root. libpq probes $HOME/.postgresql/postgresql.crt;
# Permission denied on /root aborts SSL connects even when a client cert is not required
# (e.g. Neon sslmode=require). PGSSLCERT redirects the probe away from /root as a guard.

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php", "artisan", "queue:work"]
