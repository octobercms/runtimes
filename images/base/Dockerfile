FROM php:8.5-fpm

COPY scripts/docker/install-october-php-extensions.sh /tmp/install-october-php-extensions.sh
RUN chmod +x /tmp/install-october-php-extensions.sh \
    && /tmp/install-october-php-extensions.sh \
    && rm -f /tmp/install-october-php-extensions.sh

WORKDIR /var/www/html
