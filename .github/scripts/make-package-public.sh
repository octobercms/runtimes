#!/usr/bin/env bash
set -euo pipefail

: "${ORG:?ORG is required}"
: "${PACKAGE:?PACKAGE is required}"

status=$(gh api "orgs/${ORG}/packages/container/${PACKAGE}" --jq '.visibility' 2>/dev/null || echo "unknown")
echo "Current visibility for ${PACKAGE}: ${status}"

if [ "${status}" = "public" ]; then
    echo "Package ${PACKAGE} is already public"
    exit 0
fi

gh api --method PATCH "orgs/${ORG}/packages/container/${PACKAGE}" \
    --field visibility=public

echo "Package ${PACKAGE} is now public"
