#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Exercise packaged code without host bind mounts; works on a DinD runner too.
docker build -t log-pipeline:dev .
docker run --rm --read-only --tmpfs /output:uid=10001,gid=10001 log-pipeline:dev python -c "from pipeline import run; r=run('/input/events.jsonl','/output/report.json'); assert r['accepted']==3 and r['rejected']==1, r; print('PASS: packaged sample batch')"
