#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${DB_PASSWORD:?}" "${REDIS_PASSWORD:?}"
k=(kubectl --context "$KUBE_CONTEXT" -n microservices)
"${k[@]}" create namespace microservices --dry-run=client -o yaml | "${k[@]}" apply -f -
for name in app-secrets database-user; do
  if "${k[@]}" get secret "$name" >/dev/null 2>&1; then continue; fi
  if [[ "$name" == app-secrets ]]; then
    "${k[@]}" create secret generic "$name" --from-literal=DB_PASSWORD="$DB_PASSWORD" --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD"
  else
    "${k[@]}" create secret generic "$name" --type=kubernetes.io/basic-auth --from-literal=username=app --from-literal=password="$DB_PASSWORD"
  fi
done
