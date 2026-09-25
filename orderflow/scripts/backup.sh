#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p backups
file=$(mktemp "backups/orders-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.dump")
trap 'rm -f -- "$file"' ERR
docker compose exec -T db pg_dump -U orders -d orders -Fc > "$file"
echo "$file"
