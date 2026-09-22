#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 1 && -s "$1" ]] || { echo 'Usage: bash scripts/restore-check.sh backups/FILE.dump' >&2; exit 2; }
database="restore_check_$(date +%s)_$RANDOM"
docker compose exec -T db createdb -U orders "$database"
trap 'docker compose exec -T db dropdb -U orders "$database"' EXIT
docker compose exec -T db pg_restore -U orders -d "$database" --exit-on-error --no-owner < "$1"
docker compose exec -T db psql -U orders -d "$database" -v ON_ERROR_STOP=1 -c 'SELECT status, count(*) FROM orders GROUP BY status;'
echo 'Restore succeeded in an isolated temporary database.'
