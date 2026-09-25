#!/usr/bin/env bash
set -euo pipefail
minimum=${MIN_FREE_PERCENT:-15}
[[ "$minimum" =~ ^[0-9]+$ && "$minimum" -le 100 ]] || exit 2
available=$(df -P /var/lib/docker | awk 'NR==2 {gsub(/%/,"",$5); print 100-$5}')
echo "Docker filesystem free: $available%"
[[ "$available" -ge "$minimum" ]]
