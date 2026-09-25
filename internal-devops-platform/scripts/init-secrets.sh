#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
if [[ ! -e .env ]]; then
  for key in API_TOKEN API_TOKEN_DEV API_TOKEN_STAGING API_TOKEN_PRODUCTION DB_PASSWORD REDIS_PASSWORD GRAFANA_PASSWORD; do
    printf '%s=%s\n' "$key" "$(openssl rand -hex 24)"
  done > .env
fi
echo 'Local credentials are ready; existing values preserved.'
