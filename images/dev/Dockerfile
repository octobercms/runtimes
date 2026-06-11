ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85
FROM ${BASE_IMAGE}

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

# TODO: add Codespaces / devcontainer tooling
