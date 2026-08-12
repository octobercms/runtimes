#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: libpq-ssl-home-smoke-test.sh IMAGE}"

assert_libpq_env() {
    local label="$1"
    local home="$2"
    local cert="$3"
    local user="${4:-}"

    if [[ -z "${home}" || "${home}" == false || "${home}" == /root || "${home}" == /root/* ]]; then
        echo "${label}: HOME must be non-root readable, got: ${home}"
        exit 1
    fi
    if [[ -z "${cert}" || "${cert}" == false || "${cert}" == /root || "${cert}" == /root/* ]]; then
        echo "${label}: PGSSLCERT must not point under /root, got: ${cert}"
        exit 1
    fi
    if [[ -n "${user}" && "${user}" == "root" ]]; then
        echo "${label}: expected non-root user, got root"
        exit 1
    fi
}

echo "Verifying WORKDIR remains /var/www/html..."
workdir_pwd="$(docker run --rm --entrypoint pwd "${image}")"
if [[ "${workdir_pwd}" != "/var/www/html" ]]; then
    echo "Expected WORKDIR /var/www/html, got ${workdir_pwd}"
    exit 1
fi

echo "Verifying image HOME / PGSSLCERT defaults..."
home_env="$(docker run --rm --entrypoint printenv "${image}" HOME)"
cert_env="$(docker run --rm --entrypoint printenv "${image}" PGSSLCERT)"
assert_libpq_env "image env" "${home_env}" "${cert_env}"
if [[ "${home_env}" != "/var/www" ]]; then
    echo "Expected HOME=/var/www, got ${home_env}"
    exit 1
fi
if [[ "${cert_env}" != "/tmp/postgresql.crt" ]]; then
    echo "Expected PGSSLCERT=/tmp/postgresql.crt, got ${cert_env}"
    exit 1
fi

is_prod_image=0
if docker run --rm --entrypoint bash "${image}" -lc 'command -v supervisord' >/dev/null 2>&1; then
    is_prod_image=1
fi

if [[ "${is_prod_image}" -eq 1 ]]; then
    echo "Verifying prod supervisord paths (scheduler + PHP-FPM request)..."
    workdir="$(mktemp -d)"
    chmod 755 "${workdir}"
    cid=""

    cleanup() {
        if [[ -n "${cid}" ]]; then
            docker rm -f "${cid}" >/dev/null 2>&1 || true
        fi
        if [[ -d "${workdir}" ]]; then
            docker run --rm --entrypoint bash -v "${workdir}:/var/www/html" "${image}" \
                -lc 'find /var/www/html -mindepth 1 -delete' >/dev/null 2>&1 || true
            rm -rf "${workdir}" >/dev/null 2>&1 || true
        fi
    }
    trap cleanup EXIT

    cat >"${workdir}/index.php" <<'PHP'
<?php
header('Content-Type: text/plain');
echo 'HOME=' . getenv('HOME') . "\n";
echo 'PGSSLCERT=' . getenv('PGSSLCERT') . "\n";
echo 'USER=' . (posix_getpwuid(posix_geteuid())['name'] ?? 'unknown') . "\n";
PHP

    cid="$(docker run -d \
        -e OCTOBER_SCHEDULER_ENABLED=true \
        -v "${workdir}:/var/www/html" \
        "${image}")"

    for _ in $(seq 1 30); do
        if docker exec "${cid}" /usr/local/bin/healthcheck.sh >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    if ! docker exec "${cid}" /usr/local/bin/healthcheck.sh >/dev/null 2>&1; then
        echo "Prod health check failed"
        docker logs "${cid}" || true
        exit 1
    fi

    for _ in $(seq 1 30); do
        if docker exec "${cid}" supervisorctl status scheduler 2>/dev/null | grep -Eq 'RUNNING'; then
            break
        fi
        sleep 1
    done
    if ! docker exec "${cid}" supervisorctl status scheduler 2>/dev/null | grep -Eq 'RUNNING'; then
        echo "Scheduler did not reach RUNNING"
        docker exec "${cid}" supervisorctl status || true
        docker logs "${cid}" || true
        exit 1
    fi

    sched_pid="$(docker exec "${cid}" supervisorctl pid scheduler)"
    sched_user="$(docker exec "${cid}" bash -lc "stat -c %U /proc/${sched_pid}")"
    # /proc/<pid>/environ is mode 400 as the process user; read it as www-data.
    sched_environ="$(docker exec -u www-data "${cid}" bash -lc "tr '\\0' '\\n' < /proc/${sched_pid}/environ")"
    sched_home="$(printf '%s\n' "${sched_environ}" | sed -n 's/^HOME=//p')"
    sched_cert="$(printf '%s\n' "${sched_environ}" | sed -n 's/^PGSSLCERT=//p')"
    assert_libpq_env "scheduler process" "${sched_home}" "${sched_cert}" "${sched_user}"
    echo "scheduler HOME=${sched_home} PGSSLCERT=${sched_cert} user=${sched_user}"

    php_env=""
    for _ in $(seq 1 30); do
        if php_env="$(docker exec "${cid}" curl -fsS http://127.0.0.1/ 2>/dev/null)"; then
            break
        fi
        sleep 1
    done
    if [[ -z "${php_env}" ]]; then
        echo "PHP-FPM request via nginx failed"
        docker logs "${cid}" || true
        exit 1
    fi
    php_home="$(printf '%s\n' "${php_env}" | sed -n 's/^HOME=//p')"
    php_cert="$(printf '%s\n' "${php_env}" | sed -n 's/^PGSSLCERT=//p')"
    php_user="$(printf '%s\n' "${php_env}" | sed -n 's/^USER=//p')"
    assert_libpq_env "php-fpm request" "${php_home}" "${php_cert}" "${php_user}"
    echo "php-fpm HOME=${php_home} PGSSLCERT=${php_cert} user=${php_user}"
else
    echo "Verifying worker entrypoint drops to www-data with non-root HOME / PGSSLCERT..."
    # These env asserts are the real gate for the worker path. A PDO connect to a
    # closed port can fail with "connection refused" before libpq probes client
    # certs, so it is not a reliable regression check for /root/.postgresql.
    docker run --rm \
        --entrypoint bash \
        "${image}" \
        -lc '
set -euo pipefail
exec /usr/local/bin/entrypoint.sh php -r "
\$home = getenv(\"HOME\");
\$cert = getenv(\"PGSSLCERT\");
\$user = posix_getpwuid(posix_geteuid())[\"name\"] ?? \"unknown\";

if (\$user === \"root\") {
    fwrite(STDERR, \"Expected non-root after entrypoint, got root\n\");
    exit(1);
}
if (\$home === false || \$home === \"\" || str_starts_with(\$home, \"/root\")) {
    fwrite(STDERR, \"HOME must be non-root readable, got: \" . var_export(\$home, true) . \"\n\");
    exit(1);
}
if (!is_dir(\$home) || !is_readable(\$home)) {
    fwrite(STDERR, \"HOME is not readable by {\$user}: {\$home}\n\");
    exit(1);
}
if (\$cert === false || \$cert === \"\" || str_starts_with(\$cert, \"/root\")) {
    fwrite(STDERR, \"PGSSLCERT must not point under /root, got: \" . var_export(\$cert, true) . \"\n\");
    exit(1);
}

echo \"HOME={\$home} PGSSLCERT={\$cert} user={\$user}\n\";
"
'
fi

echo "libpq SSL home smoke test passed"
