ARG PHP_VERSION=8.5
ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85-node26

FROM php:${PHP_VERSION}-fpm-bookworm AS php_fpm

FROM ${BASE_IMAGE}

COPY --from=php_fpm /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=php_fpm /usr/local/etc/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --from=php_fpm /usr/local/etc/php-fpm.conf.default /usr/local/etc/php-fpm.conf.default
COPY --from=php_fpm /usr/local/etc/php-fpm.d /usr/local/etc/php-fpm.d

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    less \
    libpq-dev \
    libsqlite3-dev \
    nginx \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pdo_sqlite \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
