ARG PHP_VERSION=8.5
ARG NODE_VERSION=26

FROM node:${NODE_VERSION}-bookworm AS node

FROM php:${PHP_VERSION}-fpm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    unzip \
    libcurl4-openssl-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        curl \
        gd \
        mbstring \
        pdo_mysql \
        xml \
        zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
# Replace vulnerable npm-bundled brace-expansion / undici until Node ships patched npm.
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm_mods=/usr/local/lib/node_modules/npm/node_modules \
    && tmp="$(mktemp -d)" \
    && npm install --prefix "$tmp" --omit=dev brace-expansion@5.0.12 undici@6.29.1 \
    && rm -rf "$npm_mods/brace-expansion" "$npm_mods/undici" \
    && mv "$tmp/node_modules/brace-expansion" "$npm_mods/brace-expansion" \
    && mv "$tmp/node_modules/undici" "$npm_mods/undici" \
    && if [ -d "$tmp/node_modules/balanced-match" ]; then \
         rm -rf "$npm_mods/balanced-match"; \
         mv "$tmp/node_modules/balanced-match" "$npm_mods/balanced-match"; \
       fi \
    && rm -rf "$tmp" /root/.npm \
    && if [ -e /usr/local/lib/node_modules/corepack/dist/corepack.js ]; then \
         ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack; \
       else \
         npm install -g corepack; \
       fi \
    && corepack enable \
    && corepack prepare yarn@stable --activate \
    && corepack prepare pnpm@latest --activate

WORKDIR /var/www/html
