#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: libpq-ssl-home-smoke-test.sh IMAGE}"

echo "Verifying WORKDIR remains /var/www/html..."
workdir="$(docker run --rm --entrypoint pwd "${image}")"
if [[ "${workdir}" != "/var/www/html" ]]; then
    echo "Expected WORKDIR /var/www/html, got ${workdir}"
    exit 1
fi

echo "Verifying image HOME / PGSSLCERT defaults..."
home_env="$(docker run --rm --entrypoint printenv "${image}" HOME)"
cert_env="$(docker run --rm --entrypoint printenv "${image}" PGSSLCERT)"
if [[ "${home_env}" != "/var/www" ]]; then
    echo "Expected HOME=/var/www, got ${home_env}"
    exit 1
fi
if [[ "${cert_env}" != "/tmp/postgresql.crt" ]]; then
    echo "Expected PGSSLCERT=/tmp/postgresql.crt, got ${cert_env}"
    exit 1
fi

echo "Verifying entrypoint drops to www-data with non-root HOME / PGSSLCERT..."
# Force OCTOBER_RUNTIME_USER so prod (which keeps root for supervisord) also drops
# for this check the same way workers do in production.
#
# These env asserts are the real gate. A PDO connect to a closed port can fail with
# "connection refused" before libpq probes client certs, so it is not a reliable
# regression check for the /root/.postgresql Permission denied bug.
docker run --rm \
    -e OCTOBER_RUNTIME_USER=www-data \
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

echo "libpq SSL home smoke test passed"
