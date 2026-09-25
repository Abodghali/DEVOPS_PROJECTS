#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${GITLAB_READ_TOKEN:?Use a read_api token for the monitored projects}"
k=(kubectl --context "$KUBE_CONTEXT" -n ci-platform)
"${k[@]}" create namespace ci-platform --dry-run=client -o yaml | "${k[@]}" apply -f -
if ! "${k[@]}" get secret gitlab-api >/dev/null 2>&1; then
  "${k[@]}" create secret generic gitlab-api --from-literal=token="$GITLAB_READ_TOKEN"
fi
