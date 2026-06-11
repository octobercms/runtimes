#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: devcontainer-smoke-test.sh IMAGE}"

cid=$(docker run -d "${image}" sleep infinity)
trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' EXIT

echo "Starting web stack..."
docker exec -d "${cid}" bash /usr/local/bin/devcontainer-post-start.sh

echo "Waiting for /_health..."
for _ in $(seq 1 30); do
    if docker exec "${cid}" curl -fsS http://127.0.0.1/_health >/dev/null 2>&1; then
        echo "Devcontainer smoke test passed"
        exit 0
    fi
    sleep 1
done

echo "Devcontainer smoke test failed"
docker logs "${cid}"
exit 1
