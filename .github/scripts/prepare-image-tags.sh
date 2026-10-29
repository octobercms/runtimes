#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${IMAGE_PREFIX:?IMAGE_PREFIX is required}"
: "${MOVING_TAG:?MOVING_TAG is required}"

date=$(date -u +'%Y.%m.%d')
sha="${GITHUB_SHA:0:7}"
version=""
ref="${GIT_REF:-}"
publish_latest="${PUBLISH_LATEST:-false}"
legacy_php_tag="${LEGACY_PHP_TAG:-}"

if [[ "${ref}" == v* ]]; then
  version="${ref#v}"
fi

{
  echo "tags<<EOF"
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}"
  if [[ "${publish_latest}" == "true" ]]; then
    echo "${IMAGE_PREFIX}/${IMAGE}:latest"
  fi
  if [[ -n "${legacy_php_tag}" ]]; then
    echo "${IMAGE_PREFIX}/${IMAGE}:${legacy_php_tag}"
  fi
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${date}"
  echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${date}-${sha}"
  if [[ -n "${version}" ]]; then
    echo "${IMAGE_PREFIX}/${IMAGE}:${MOVING_TAG}-${version}"
    if [[ "${publish_latest}" == "true" ]]; then
      echo "${IMAGE_PREFIX}/${IMAGE}:${version}"
    fi
  fi
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
