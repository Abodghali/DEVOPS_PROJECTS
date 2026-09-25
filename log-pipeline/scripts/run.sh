#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p output
export LOCAL_UID=$(id -u) LOCAL_GID=$(id -g)
docker compose run --build --rm pipeline
test -s output/report.json
cat output/report.json
docker compose up -d reports
echo 'Report URL: http://localhost:8085/report.json'
