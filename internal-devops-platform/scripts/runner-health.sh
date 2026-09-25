#!/usr/bin/env bash
set -euo pipefail
systemctl is-active --quiet gitlab-runner
docker info >/dev/null
gitlab-runner verify >/dev/null 2>&1
echo 'Runner service, Docker engine and GitLab registration checks passed.'
