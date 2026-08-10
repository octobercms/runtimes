#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: prod-scheduler-smoke-test.sh IMAGE}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixtures_dir="${script_dir}/fixtures"

workdir="$(mktemp -d)"
# mktemp creates mode 0700; www-data must be able to traverse the bind mount on Linux.
chmod 755 "${workdir}"
cid=""

cleanup() {
    docker rm -f "${cid}" >/dev/null 2>&1 || true
    if [[ -d "${workdir}" ]]; then
        docker run --rm -v "${workdir}:/app" "${image}" bash -lc 'find /app -mindepth 1 -delete' >/dev/null 2>&1 || true
        rm -rf "${workdir}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

supervisor_status() {
    docker exec "${cid}" supervisorctl status
}

wait_for_health() {
    local attempts="${1:-30}"
    for _ in $(seq 1 "${attempts}"); do
        if docker exec "${cid}" /usr/local/bin/healthcheck.sh; then
            return 0
        fi
        sleep 1
    done
    echo "Health check failed"
    docker logs "${cid}"
    return 1
}

wait_for_program() {
    local program="$1"
    local attempts="${2:-30}"
    for _ in $(seq 1 "${attempts}"); do
        if supervisor_status | grep -E "^${program}[[:space:]]+RUNNING"; then
            return 0
        fi
        sleep 1
    done
    echo "Supervisor program ${program} did not reach RUNNING"
    supervisor_status || true
    docker logs "${cid}" || true
    return 1
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
    supervisor_status || true
    docker logs "${cid}" || true
    return 1
}

process_args() {
    docker exec "${cid}" bash -lc '
        for cmdline in /proc/[0-9]*/cmdline; do
            tr "\0" " " < "${cmdline}" 2>/dev/null
            echo
        done
    '
}

echo "Creating minimal Laravel app fixture..."
docker run --rm \
    -v "${workdir}:/app" \
    -v "${fixtures_dir}:/fixtures:ro" \
    -w /app \
    "${image}" \
    bash -lc '
        set -euo pipefail
        composer create-project laravel/laravel . --no-interaction --prefer-dist --no-dev
        php artisan key:generate --force --no-interaction
        mkdir -p app/Console/Commands
        cp /fixtures/RuntimeProbe.php app/Console/Commands/RuntimeProbe.php
        php /fixtures/register-runtime-probe.php
        # schedule:work runs as www-data and must write cache/storage/sqlite paths.
        www_uid="$(id -u www-data)"
        www_gid="$(id -g www-data)"
        chown -R "${www_uid}:${www_gid}" storage bootstrap/cache database
    '

echo "Starting production container with Laravel app..."
cid="$(docker run -d \
    -e OCTOBER_SCHEDULER_ENABLED=true \
    -e CACHE_STORE=file \
    -v "${workdir}:/var/www/html" \
    "${image}")"

wait_for_health

echo "Verifying nginx and PHP-FPM are running..."
wait_for_program nginx
wait_for_program php-fpm

echo "Verifying scheduler is running under Supervisor..."
wait_for_program scheduler
process_args | grep -F 'artisan schedule:work'

echo "Verifying queue workers are not managed by the production runtime..."
if process_args | grep -Ei 'queue:work|queue:listen|horizon'; then
    echo "Unexpected queue worker process found"
    process_args
    exit 1
fi
if docker exec "${cid}" cat /etc/supervisor/conf.d/runtimes.conf | grep -Ei 'queue|horizon'; then
    echo "Unexpected queue worker program found in Supervisor config"
    exit 1
fi

echo "Waiting for scheduled task marker..."
wait_for_file "${workdir}/storage/app/scheduler-ran" 90
echo "Scheduled task executed successfully."

echo "Verifying scheduler restarts after unexpected exit..."
old_pid="$(docker exec "${cid}" supervisorctl pid scheduler)"
docker exec "${cid}" bash -lc "kill -9 ${old_pid}"
restarted=false
for attempt in $(seq 1 30); do
    new_pid="$(docker exec "${cid}" supervisorctl pid scheduler 2>/dev/null || true)"
    if [[ -n "${new_pid}" && "${new_pid}" != "0" && "${new_pid}" != "${old_pid}" ]]; then
        if supervisor_status | grep -E '^scheduler[[:space:]]+RUNNING'; then
            echo "Scheduler restarted successfully (pid ${old_pid} -> ${new_pid})."
            restarted=true
            break
        fi
    fi
    sleep 1
done
if [[ "${restarted}" != "true" ]]; then
    echo "Scheduler did not restart after unexpected exit"
    supervisor_status || true
    docker logs "${cid}"
    exit 1
fi

echo "Verifying scheduler terminates cleanly on container stop..."
docker stop -t 30 "${cid}" >/dev/null
stop_status="$(docker inspect -f '{{.State.ExitCode}}' "${cid}")"
if [[ "${stop_status}" != "0" ]]; then
    echo "Container did not stop cleanly (exit code ${stop_status})"
    docker logs "${cid}"
    exit 1
fi
docker rm "${cid}" >/dev/null
cid=""

echo "Verifying empty document root remains healthy (scheduler idles without artisan)..."
cid="$(docker run -d "${image}")"
wait_for_health
wait_for_program nginx
wait_for_program php-fpm
wait_for_program scheduler
docker logs "${cid}" 2>&1 | grep -F 'artisan not found'
if process_args | grep -F 'artisan schedule:work'; then
    echo "schedule:work should not start without artisan"
    process_args
    exit 1
fi
docker rm -f "${cid}" >/dev/null
cid=""

echo "Verifying OCTOBER_SCHEDULER_ENABLED=false disables schedule:work..."
cid="$(docker run -d \
    -e OCTOBER_SCHEDULER_ENABLED=false \
    -v "${workdir}:/var/www/html" \
    "${image}")"
wait_for_health
wait_for_program scheduler
if process_args | grep -F 'artisan schedule:work'; then
    echo "schedule:work is running despite OCTOBER_SCHEDULER_ENABLED=false"
    process_args
    exit 1
fi
docker logs "${cid}" 2>&1 | grep -F 'October scheduler disabled'

echo "Production scheduler smoke test passed"
