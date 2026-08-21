#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: worker-queue-smoke-test.sh IMAGE}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixtures_dir="${script_dir}/fixtures"

workdir="$(mktemp -d)"
# mktemp creates mode 0700; the container user must traverse the bind mount on Linux.
chmod 755 "${workdir}"
cid=""

cleanup() {
    if [[ -n "${cid}" ]]; then
        docker rm -f "${cid}" >/dev/null 2>&1 || true
    fi
    if [[ -d "${workdir}" ]]; then
        docker run --rm --entrypoint bash -v "${workdir}:/var/www/html" "${image}" -lc 'find /var/www/html -mindepth 1 -delete' >/dev/null 2>&1 || true
        rm -rf "${workdir}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

process_args() {
    docker exec "${cid}" bash -lc '
        for cmdline in /proc/[0-9]*/cmdline; do
            tr "\0" " " < "${cmdline}" 2>/dev/null
            echo
        done
    '
}

wait_for_file() {
    local path="$1"
    local attempts="${2:-90}"
    for _ in $(seq 1 "${attempts}"); do
        if [[ -f "${path}" ]]; then
            return 0
        fi
        sleep 1
    done
    echo "Timed out waiting for ${path}"
    process_args || true
    docker logs "${cid}" || true
    return 1
}

assert_no_web_stack() {
    if process_args | grep -Eiq 'nginx|php-fpm|schedule:work|supervisord'; then
        echo "Unexpected web/scheduler/supervisor process found in worker runtime"
        process_args
        exit 1
    fi

    if docker exec "${cid}" bash -lc 'command -v nginx' >/dev/null 2>&1; then
        echo "nginx should not be installed in the worker runtime"
        exit 1
    fi

    if docker exec "${cid}" bash -lc 'command -v supervisord' >/dev/null 2>&1; then
        echo "supervisord should not be installed in the worker runtime"
        exit 1
    fi
}

echo "Creating minimal Laravel app fixture..."
docker run --rm \
    --entrypoint bash \
    -v "${workdir}:/var/www/html" \
    -v "${fixtures_dir}:/fixtures:ro" \
    -w /var/www/html \
    -e DB_CONNECTION=sqlite \
    -e DB_DATABASE=/var/www/html/database/database.sqlite \
    -e QUEUE_CONNECTION=database \
    -e CACHE_STORE=file \
    "${image}" \
    -lc '
        set -euo pipefail
        composer create-project laravel/laravel . --no-interaction --prefer-dist --no-dev
        php artisan key:generate --force --no-interaction
        mkdir -p app/Jobs database
        touch database/database.sqlite
        cp /fixtures/QueueProbeJob.php app/Jobs/QueueProbeJob.php
        php artisan migrate --force --no-interaction
        php /fixtures/dispatch-queue-probe.php
        # Worker runs as www-data and must write cache/storage/sqlite paths.
        www_uid="$(id -u www-data)"
        www_gid="$(id -g www-data)"
        chown -R "${www_uid}:${www_gid}" storage bootstrap/cache database
    '

echo "Starting worker container..."
cid="$(docker run -d \
    -e DB_CONNECTION=sqlite \
    -e DB_DATABASE=/var/www/html/database/database.sqlite \
    -e QUEUE_CONNECTION=database \
    -e CACHE_STORE=file \
    -v "${workdir}:/var/www/html" \
    "${image}")"

echo "Verifying default queue worker process..."
for _ in $(seq 1 30); do
    if process_args | grep -F 'artisan queue:work'; then
        break
    fi
    sleep 1
done
if ! process_args | grep -F 'artisan queue:work'; then
    echo "queue:work did not start"
    docker logs "${cid}"
    process_args
    exit 1
fi

assert_no_web_stack

echo "Verifying worker runs as www-data..."
worker_user="$(docker exec "${cid}" bash -lc 'stat -c %U /proc/1')"
if [[ "${worker_user}" != "www-data" ]]; then
    echo "Expected PID 1 to run as www-data, got ${worker_user}"
    process_args
    exit 1
fi

echo "Verifying cache warm did not leave root-owned runtime files..."
root_owned="$(docker exec "${cid}" bash -lc 'find /var/www/html/storage /var/www/html/bootstrap/cache -user root -print')"
if [[ -n "${root_owned}" ]]; then
    echo "Root-owned files after artisan about would break www-data writers:"
    echo "${root_owned}"
    exit 1
fi

echo "Waiting for queued job marker..."
wait_for_file "${workdir}/storage/app/queue-job-ran" 90
echo "Queued job processed successfully."

logs="$(docker logs "${cid}" 2>&1 || true)"
if [[ -z "${logs}" ]]; then
    echo "Expected worker container logs on stdout/stderr"
    exit 1
fi
if ! grep -Eqi 'QueueProbeJob|Processing:|Processed:' <<<"${logs}"; then
    echo "Expected queue job processing output on stdout/stderr"
    echo "${logs}"
    exit 1
fi

echo "Verifying worker terminates cleanly on container stop..."
docker stop -t 30 "${cid}" >/dev/null
stop_status="$(docker inspect -f '{{.State.ExitCode}}' "${cid}")"
if [[ "${stop_status}" != "0" ]]; then
    echo "Container did not stop cleanly (exit code ${stop_status})"
    docker logs "${cid}"
    exit 1
fi
docker rm "${cid}" >/dev/null
cid=""

echo "Verifying overridden queue:work command..."
docker run --rm --entrypoint bash \
    -v "${workdir}:/var/www/html" \
    "${image}" \
    -lc 'rm -f /var/www/html/storage/app/queue-job-ran'
docker run --rm \
    --entrypoint php \
    -v "${workdir}:/var/www/html" \
    -v "${fixtures_dir}:/fixtures:ro" \
    -e DB_CONNECTION=sqlite \
    -e DB_DATABASE=/var/www/html/database/database.sqlite \
    -e QUEUE_CONNECTION=database \
    -e CACHE_STORE=file \
    "${image}" \
    /fixtures/dispatch-queue-probe.php

cid="$(docker run -d \
    -e DB_CONNECTION=sqlite \
    -e DB_DATABASE=/var/www/html/database/database.sqlite \
    -e QUEUE_CONNECTION=database \
    -e CACHE_STORE=file \
    -v "${workdir}:/var/www/html" \
    "${image}" \
    php artisan queue:work --once --stop-when-empty)"

wait_for_file "${workdir}/storage/app/queue-job-ran" 90

# --once / --stop-when-empty should cause the container to exit on its own.
for _ in $(seq 1 30); do
    if ! docker ps -q --filter "id=${cid}" | grep -q .; then
        break
    fi
    sleep 1
done
if docker ps -q --filter "id=${cid}" | grep -q .; then
    echo "Worker container did not exit after queue:work --once --stop-when-empty"
    docker logs "${cid}"
    exit 1
fi
exit_code="$(docker inspect -f '{{.State.ExitCode}}' "${cid}")"
if [[ "${exit_code}" != "0" ]]; then
    echo "Overridden worker exited with code ${exit_code}"
    docker logs "${cid}"
    exit 1
fi
docker rm "${cid}" >/dev/null
cid=""

echo "Verifying PHP-FPM is not started by the worker image defaults..."
cid="$(docker run -d --entrypoint bash "${image}" -lc 'echo cli-ok; sleep 30')"
sleep 1
if process_args | grep -Eiq 'php-fpm'; then
    echo "php-fpm should not start in the worker runtime"
    process_args
    exit 1
fi
docker logs "${cid}" 2>&1 | grep -F 'cli-ok'
docker rm -f "${cid}" >/dev/null
cid=""

echo "Worker queue smoke test passed"
