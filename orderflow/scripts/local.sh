#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/init-secrets.sh
docker compose up -d --build --wait --wait-timeout 120
python3 tests/smoke.py
