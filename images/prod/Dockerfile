ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# TODO: copy config/nginx/default.conf
# TODO: copy config/php/runtime.ini
# TODO: copy config/php-fpm/zz-runtime.conf
# TODO: copy config/supervisor/supervisord.conf
# TODO: copy scripts/entrypoint.sh
# TODO: copy scripts/healthcheck.sh

EXPOSE 80

# TODO: replace with supervisor entrypoint
CMD ["php-fpm"]
