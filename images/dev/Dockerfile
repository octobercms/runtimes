ARG BASE_IMAGE=ghcr.io/octobercms/runtime-base:php85
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    less \
    libpq-dev \
    libsqlite3-dev \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pdo_sqlite \
    && rm -rf /var/lib/apt/lists/*

# TODO: add Codespaces / devcontainer tooling
