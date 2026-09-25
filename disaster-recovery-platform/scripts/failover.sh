#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
[[ "${CONFIRM_FAILOVER:-}" == dr-lab/recovery ]] || { echo 'Set CONFIRM_FAILOVER=dr-lab/recovery.' >&2; exit 2; }
"${k[@]}" exec recovery-0 -- psql -U app -d app -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM notes;' >/dev/null
"${k[@]}" patch service active-db --type=merge -p '{"spec":{"selector":{"slot":"recovery"}}}'
"${k[@]}" rollout restart deployment/notes
"${k[@]}" rollout status deployment/notes --timeout=180s
"${k[@]}" exec deployment/notes -- python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/readyz',timeout=5)"
