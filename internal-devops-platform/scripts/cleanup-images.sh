#!/usr/bin/env bash
set -euo pipefail
docker image ls --filter dangling=true
if [[ "${CONFIRM_CLEANUP:-}" == yes ]]; then
  docker image prune --force --filter until=168h
else
  echo 'Preview only. Set CONFIRM_CLEANUP=yes to prune dangling images older than seven days.'
fi
