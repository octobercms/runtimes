#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: cache-warm-smoke-test.sh IMAGE}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixtures_dir="${script_dir}/fixtures"

workdir="$(mktemp -d)"
chmod 755 "${workdir}"

cleanup() {
    if [[ -d "${workdir}" ]]; then
        docker run --rm --entrypoint bash -v "${workdir}:/var/www/html" "${image}" \
            -lc 'find /var/www/html -mindepth 1 -delete' >/dev/null 2>&1 || true
        rm -rf "${workdir}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

inspect() {
    docker run --rm --entrypoint bash -v "${workdir}:/var/www/html" "${image}" -lc "$1"
}

prepare_stale_cache() {
    inspect '
        set -euo pipefail
        mkdir -p /var/www/html/storage/framework/cache/cms /var/www/html/storage/logs
        printf "STALE\n" > /var/www/html/storage/framework/cache/cms/disabled.php
        chown -R root:root /var/www/html/storage
        chmod 644 /var/www/html/storage/framework/cache/cms/disabled.php
    '
    cp "${fixtures_dir}/cache-warm-artisan.php" "${workdir}/artisan"
}

assert_www_data_file() {
    local path="$1"
    local owner
    owner="$(inspect "stat -c %U ${path}")"
    if [[ "${owner}" != "www-data" ]]; then
        echo "Expected ${path} owned by www-data, got ${owner}"
        inspect "ls -la /var/www/html/storage /var/www/html/storage/framework/cache /var/www/html/storage/framework/cache/cms /var/www/html/storage/logs || true"
        exit 1
    fi
}

echo "Verifying cache warm runs as www-data and replaces a stale disabled.php..."
prepare_stale_cache

warm_output="$(docker run --rm -v "${workdir}:/var/www/html" "${image}" true 2>&1)" || {
    echo "Cache warm should not fail the container"
    echo "${warm_output}"
    exit 1
}

if grep -Fq 'cache-warm artisan stdout should be discarded' <<<"${warm_output}"; then
    echo "artisan about stdout should be discarded"
    echo "${warm_output}"
    exit 1
fi
if ! grep -Fq 'cache-warm artisan stderr user=www-data' <<<"${warm_output}"; then
    echo "Expected artisan about stderr from www-data"
    echo "${warm_output}"
    exit 1
fi

if inspect 'test -f /var/www/html/storage/app/cache-warm-stale-present'; then
    echo "Stale disabled.php was still present when artisan about ran"
    exit 1
fi

user="$(inspect 'cat /var/www/html/storage/app/cache-warm-user')"
if [[ "${user}" != "www-data" ]]; then
    echo "Expected artisan about to run as www-data, got ${user}"
    exit 1
fi

if ! inspect 'test -d /var/www/html/storage/framework/cache/cms'; then
    echo "Expected storage/framework/cache/cms to exist after warm"
    exit 1
fi

contents="$(inspect 'cat /var/www/html/storage/framework/cache/cms/disabled.php')"
if grep -Fq 'STALE' <<<"${contents}"; then
    echo "Stale disabled.php was not replaced"
    echo "${contents}"
    exit 1
fi
if ! grep -Fq "['warmed' => true]" <<<"${contents}"; then
    echo "Expected warmed disabled.php contents"
    echo "${contents}"
    exit 1
fi

assert_www_data_file /var/www/html/storage/framework/cache/cms/disabled.php
assert_www_data_file /var/www/html/storage/framework/cache/cms/manifest.php
assert_www_data_file /var/www/html/storage/logs/laravel.log

echo "Verifying a failing artisan about does not fail container start..."
prepare_stale_cache
fail_output="$(docker run --rm -e CACHE_WARM_FAIL=1 -v "${workdir}:/var/www/html" "${image}" true 2>&1)" || {
    echo "Failed artisan about should not fail the container"
    echo "${fail_output}"
    exit 1
}
if ! grep -Fq 'cache-warm artisan forced failure' <<<"${fail_output}"; then
    echo "Expected failing artisan stderr to remain visible"
    echo "${fail_output}"
    exit 1
fi

echo "Cache warm smoke test passed"
