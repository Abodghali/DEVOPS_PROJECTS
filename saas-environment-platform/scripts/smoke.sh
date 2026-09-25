#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for environment in dev staging production; do
  docker compose exec -T "app-$environment" python -c "import json,os,urllib.request; u='http://localhost:8080'; assert json.load(urllib.request.urlopen(u+'/version'))['environment']=='$environment'; req=urllib.request.Request(u+'/api/quote',data=b'{\"plan\":\"team\",\"seats\":2}',headers={'Authorization':'Bearer '+os.environ['API_TOKEN'],'Content-Type':'application/json'}); assert json.load(urllib.request.urlopen(req))['monthly_cents']==4800"
done
echo 'Smoke checks passed'
