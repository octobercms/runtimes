ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    nginx \
    supervisor \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY config/php/runtime.ini /usr/local/etc/php/conf.d/runtime.ini
COPY config/php-fpm/zz-runtime.conf /usr/local/etc/php-fpm.d/zz-runtime.conf
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/runtimes.conf
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY scripts/scheduler.sh /usr/local/bin/scheduler.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/scheduler.sh

# www-data (and other non-root runtime users) must not inherit HOME=/root.
# libpq probes $HOME/.postgresql/postgresql.crt; Permission denied on /root aborts
# SSL connects even when a client cert is not required (e.g. Neon sslmode=require).
ENV HOME=/var/www \
    PGSSLCERT=/tmp/postgresql.crt \
    OCTOBER_SCHEDULER_ENABLED=false \
    OCTOBER_SCHEDULER_AUTOSTART=false

EXPOSE 80

# start-period matches typical October Cloud ENI + layer + supervisord/FPM/nginx boot.
# Healthy is still reported as soon as the probe passes; this only avoids false failures.
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n"]
