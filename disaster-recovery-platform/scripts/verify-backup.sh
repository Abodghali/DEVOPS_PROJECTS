#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
[[ $# == 1 ]] || { echo 'Pass a dump path.' >&2; exit 2; }
check_dump "$1"
database="verify_$(date +%s)_$RANDOM"
"${k[@]}" exec recovery-0 -- createdb -U app "$database"
trap '"${k[@]}" exec recovery-0 -- dropdb -U app "$database"' EXIT
"${k[@]}" exec -i recovery-0 -- pg_restore --exit-on-error --no-owner -U app -d "$database" < "$1"
"${k[@]}" exec recovery-0 -- psql -U app -d "$database" -v ON_ERROR_STOP=1 -c 'SELECT count(*),max(created_at) FROM notes;'
echo 'Backup restored and queried in an isolated temporary database.'
