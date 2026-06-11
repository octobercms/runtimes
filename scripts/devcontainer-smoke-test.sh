#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: devcontainer-smoke-test.sh IMAGE}"

http_status() {
    docker exec "${cid}" curl -sS -o /dev/null -w "%{http_code}" "$1"
}

cid=$(docker run -d "${image}" sleep infinity)
trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' EXIT

echo "Installing October CMS..."
docker exec "${cid}" bash /usr/local/bin/devcontainer-post-create.sh

echo "Starting web stack..."
docker exec -d "${cid}" bash /usr/local/bin/devcontainer-post-start.sh

echo "Waiting for /_health..."
for _ in $(seq 1 30); do
    if [[ "$(http_status http://127.0.0.1/_health)" == "200" ]]; then
        break
    fi
    sleep 1
done

if [[ "$(http_status http://127.0.0.1/_health)" != "200" ]]; then
    echo "Devcontainer smoke test failed: /_health did not return HTTP 200"
    docker logs "${cid}"
    exit 1
fi

echo "Waiting for October CMS homepage..."
homepage_status=""
for _ in $(seq 1 30); do
    homepage_status="$(http_status http://127.0.0.1/)"
    if [[ "${homepage_status}" == "200" ]]; then
        echo "Devcontainer smoke test passed"
        exit 0
    fi
    sleep 2
done

echo "Devcontainer smoke test failed: / returned HTTP ${homepage_status:-unknown}, expected 200"
docker logs "${cid}"
exit 1
