#!/usr/bin/env bash
set -euo pipefail

php-fpm -D

exec nginx -g "daemon off;"
