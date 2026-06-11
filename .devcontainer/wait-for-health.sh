#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
    if curl -sf http://127.0.0.1/_health >/dev/null; then
        exit 0
    fi
    sleep 1
done

echo "wait-for-health: /_health did not become ready" >&2
exit 1
