#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${IMAGE_PREFIX:?IMAGE_PREFIX is required}"
: "${MOVING_TAG:?MOVING_TAG is required}"

date=$(date -u +'%Y.%m.%d')
sha="${GITHUB_SHA:0:7}"
version=""
ref="${GIT_REF:-}"

if [[ "${ref}" == v* ]]; then
  version="${ref#v}"
fi

{
  echo "tags<<EOF"
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}"
  echo "${IMAGE_PREFIX}/${IMAGE}:latest"
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${date}"
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${date}-${sha}"
  if [[ -n "${version}" ]]; then
    echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${version}"
    echo "${IMAGE_PREFIX}/${IMAGE}:${version}"
  fi
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
