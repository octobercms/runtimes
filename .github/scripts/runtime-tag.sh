#!/usr/bin/env bash
# Emit moving-tag / default-combo helpers for a PHP + Node pair.
# Usage: eval "$(bash .github/scripts/runtime-tag.sh 8.5 26)"
set -euo pipefail

php_version="${1:?PHP version required (e.g. 8.5)}"
node_version="${2:?Node version required (e.g. 26)}"

php_compact="${php_version//./}"
moving_tag="php${php_compact}-node${node_version}"

default_php="8.5"
default_node="26"
publish_latest="false"
legacy_php_tag=""

if [[ "${php_version}" == "${default_php}" && "${node_version}" == "${default_node}" ]]; then
  publish_latest="true"
  legacy_php_tag="php${php_compact}"
fi

echo "MOVING_TAG=${moving_tag}"
echo "PUBLISH_LATEST=${publish_latest}"
echo "LEGACY_PHP_TAG=${legacy_php_tag}"
