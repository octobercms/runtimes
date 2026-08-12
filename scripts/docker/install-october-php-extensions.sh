#!/usr/bin/env bash
# Shared October CMS PHP extensions for FPM (runtime-base) and CLI (runtime-worker).
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
    curl \
    libcurl4-openssl-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev

docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
docker-php-ext-install -j"$(nproc)" \
    curl \
    gd \
    mbstring \
    pdo_mysql \
    xml \
    zip

rm -rf /var/lib/apt/lists/*
