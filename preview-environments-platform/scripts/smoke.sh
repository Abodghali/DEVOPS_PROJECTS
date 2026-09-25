#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T app python -c "import json,urllib.request; r=json.load(urllib.request.urlopen('http://localhost:8080/version')); assert r['review']=='local'"
echo 'Smoke checks passed'
