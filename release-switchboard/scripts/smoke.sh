#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --build --wait --wait-timeout 120
bash scripts/switch.sh green
bash scripts/switch.sh blue
echo 'PASS: promote green and roll back to blue'
