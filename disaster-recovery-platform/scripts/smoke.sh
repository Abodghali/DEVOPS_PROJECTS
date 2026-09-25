#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T app python -c "import json,urllib.request; u='http://localhost:8080/notes'; req=urllib.request.Request(u,data=b'{\"text\":\"smoke-marker\"}',headers={'Content-Type':'application/json'}); row=json.load(urllib.request.urlopen(req)); assert any(x['id']==row['id'] for x in json.load(urllib.request.urlopen(u)))"
echo 'Smoke checks passed'
