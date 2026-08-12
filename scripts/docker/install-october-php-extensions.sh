#!/usr/bin/env bash
# Shared October CMS PHP extensions for FPM (runtime-base) and CLI (runtime-worker).
# Installs runtime shared libraries permanently, compiles against *-dev headers, then
# purges build dependencies so lean images do not ship compiler headers.
set -euo pipefail

# Runtime libraries required by the compiled extensions (kept after purge).
runtime_packages=(
    curl
    libcurl4t64
    libfreetype6
    libjpeg62-turbo
    libonig5
    libpng16-16t64
    libwebp7
    libxml2
    libzip5
)

# Headers / build deps used only while compiling extensions.
build_packages=(
    libcurl4-openssl-dev
    libfreetype-dev
    libjpeg62-turbo-dev
    libonig-dev
    libpng-dev
    libwebp-dev
    libxml2-dev
    libzip-dev
)

saved_apt_mark="$(apt-mark showmanual)"

apt-get update
# $PHPIZE_DEPS comes from the official php image (phpize, headers, toolchain).
# shellcheck disable=SC2086
apt-get install -y --no-install-recommends \
    ${PHPIZE_DEPS} \
    "${runtime_packages[@]}" \
    "${build_packages[@]}"

docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
docker-php-ext-install -j"$(nproc)" \
    curl \
    gd \
    mbstring \
    pdo_mysql \
    xml \
    zip

# Allow autoremove to drop build tooling, including packages the parent image
# marked manual (e.g. libc6-dev from $PHPIZE_DEPS).
apt-mark auto '.*' >/dev/null || true
# shellcheck disable=SC2086
apt-mark manual ${saved_apt_mark} >/dev/null || true
apt-mark manual "${runtime_packages[@]}" >/dev/null
# Do not keep compiler headers just because the parent image marked them manual.
apt-mark auto \
    libc6-dev \
    libcrypt-dev \
    linux-libc-dev \
    libc-dev-bin \
    rpcsvc-proto \
    >/dev/null 2>&1 || true

# shellcheck disable=SC2086
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    ${PHPIZE_DEPS} \
    "${build_packages[@]}"
rm -rf /var/lib/apt/lists/*
