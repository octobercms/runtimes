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
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && if [ -e /usr/local/lib/node_modules/corepack/dist/corepack.js ]; then \
         ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack; \
       else \
         npm install -g corepack; \
       fi \
    && corepack enable \
    && corepack prepare yarn@stable --activate \
    && corepack prepare pnpm@latest --activate

WORKDIR /var/www/html
