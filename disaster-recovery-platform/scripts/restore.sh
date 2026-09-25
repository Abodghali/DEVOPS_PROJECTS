#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
[[ "${CONFIRM_RESTORE:-}" == dr-lab/recovery ]] || { echo 'Set CONFIRM_RESTORE=dr-lab/recovery to replace only the recovery database.' >&2; exit 2; }
[[ $# == 1 ]] || exit 2
[[ "$(active_slot)" == primary ]] || { echo 'Recovery currently serves traffic; refusing to overwrite it.' >&2; exit 2; }
check_dump "$1"
"${k[@]}" exec -i recovery-0 -- pg_restore --clean --if-exists --exit-on-error --no-owner -U app -d app < "$1"
"${k[@]}" exec recovery-0 -- psql -U app -d app -v ON_ERROR_STOP=1 -c 'SELECT count(*),max(created_at) FROM notes;'
