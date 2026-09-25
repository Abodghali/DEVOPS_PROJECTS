#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T gateway python -c "import json,urllib.request; u='http://localhost:8080'; assert json.load(urllib.request.urlopen(u+'/api/catalog'))[0]['sku']=='book'; assert json.load(urllib.request.urlopen(u+'/api/inventory'))[0]['stock']==100; assert json.load(urllib.request.urlopen(u+'/api/price'))['total_cents']==1250"
echo 'Smoke checks passed'
