#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${DB_PASSWORD:?}"
k=(kubectl --context "$KUBE_CONTEXT" -n dr-lab)
"${k[@]}" create namespace dr-lab --dry-run=client -o yaml | "${k[@]}" apply -f -
if ! "${k[@]}" get secret app-secrets >/dev/null 2>&1; then
  "${k[@]}" create secret generic app-secrets --from-literal=DB_PASSWORD="$DB_PASSWORD"
fi
