#!/usr/bin/env bash
set -euo pipefail

: "${ORG:?ORG is required}"
: "${PACKAGE:?PACKAGE is required}"

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN not set; skipping package visibility update for ${PACKAGE}"
  echo "Add an organization secret named GHCR_ADMIN_TOKEN (classic PAT with read:packages, write:packages, and admin:org) to automate this step."
  exit 0
fi

api_path="orgs/${ORG}/packages/container/${PACKAGE}"

status=$(gh api "${api_path}" --jq '.visibility' 2>/dev/null || echo "unknown")
echo "Current visibility for ${PACKAGE}: ${status}"

if [ "${status}" = "public" ]; then
  echo "Package ${PACKAGE} is already public"
  exit 0
fi

if ! gh api --method PATCH "${api_path}" --input - <<< '{"visibility":"public"}'; then
  echo "Failed to make ${PACKAGE} public."
  echo "Organization package visibility cannot be changed with GITHUB_TOKEN."
  echo "Use a classic PAT from an org owner with read:packages, write:packages, and admin:org, stored as the GHCR_ADMIN_TOKEN organization secret."
  exit 1
fi

echo "Package ${PACKAGE} is now public"
