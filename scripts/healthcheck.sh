#!/usr/bin/env bash
set -euo pipefail

# Liveness only: nginx is up. Readiness (/_health → PHP) is for ALB/orchestrators.
curl -fsS http://127.0.0.1/_alive >/dev/null
