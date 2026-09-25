#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for attempt in {1..20}; do
  if docker compose exec -T app python -c "import json,urllib.request; r=json.load(urllib.request.urlopen('http://localhost:8080/summary')); assert r['1']['counts']['success']==1"; then
    echo 'PASS: telemetry from the local GitLab fixture'; exit 0
  fi
  sleep 2
done
exit 1
echo 'Smoke checks passed'
