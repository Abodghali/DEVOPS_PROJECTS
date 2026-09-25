#!/usr/bin/env bash
set -euo pipefail
config="$(dirname "$0")/../ansible/runner-logrotate.conf"
if [[ "${APPLY_ROTATION:-}" == yes ]]; then
  logrotate --state /var/lib/logrotate/gitlab-runner-lab.status "$config"
else
  logrotate --debug "$config"
fi
