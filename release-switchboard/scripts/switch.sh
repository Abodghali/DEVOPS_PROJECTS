#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 1 && "$1" =~ ^(blue|green)$ ]] || { echo 'Usage: bash scripts/switch.sh blue|green' >&2; exit 2; }
target=$1
mkdir .switch-lock 2>/dev/null || { echo 'Another switch is running; inspect .switch-lock if a previous run crashed.' >&2; exit 1; }
backup=$(mktemp)
cp gateway/default.conf "$backup"
changed=false
cleanup() {
  status=$?
  if [[ $status != 0 && "$changed" == true ]]; then
    cp "$backup" gateway/default.conf
    docker compose exec -T gateway nginx -s reload || true
  fi
  rm -f "$backup"
  rmdir .switch-lock
  exit "$status"
}
trap cleanup EXIT
docker compose exec -T "$target" python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz',timeout=2)"
changed=true
printf 'server { listen 8080; location / { proxy_pass http://%s:8080; proxy_connect_timeout 2s; proxy_read_timeout 5s; } }\n' "$target" > gateway/default.conf
docker compose exec -T gateway nginx -t
docker compose exec -T gateway nginx -s reload
# Verify through the gateway, allowing graceful Nginx reload to finish.
for attempt in {1..15}; do
  if docker compose exec -T -e EXPECTED="$target" blue python -c "import json,os,urllib.request; r=json.load(urllib.request.urlopen('http://gateway:8080/version',timeout=2)); assert r['version']==os.environ['EXPECTED']"; then
    echo "Traffic now reaches $target"; exit 0
  fi
  sleep 1
done
echo 'Gateway verification failed; restoring previous config.' >&2
exit 1
