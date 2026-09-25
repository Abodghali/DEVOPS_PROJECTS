#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --build --wait --wait-timeout 120
check() {
  docker compose exec -T -e EXPECT="$1" monitor python -c "import json,os,urllib.request; x=json.load(urllib.request.urlopen('http://localhost:8080/status',timeout=3))[0]; assert (x['up'] is True and not x['alert']) if os.environ['EXPECT']=='up' else x['alert'], x"
}
wait_for() {
  for attempt in {1..30}; do
    if check "$1"; then return; fi
    sleep 1
  done
  return 1
}
trap 'docker compose start demo >/dev/null' EXIT
wait_for up
docker compose stop demo
wait_for down
docker compose start demo
wait_for up
echo 'PASS: availability, outage threshold and recovery'
