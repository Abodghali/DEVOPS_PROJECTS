#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .secrets
chmod 700 .secrets
for name in db_password api_token; do
  if [[ ! -e ".secrets/$name" ]]; then
    printf '%s' "$(openssl rand -hex 32)" > ".secrets/$name"
  fi
  chmod 444 ".secrets/$name"
done
echo 'Local secret files are ready; existing values were preserved.'
