#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the target context}"
: "${IMAGE:?Set the full image reference}"
[[ "$IMAGE" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/:@-]+$ ]] || exit 2
k=(kubectl --context "$KUBE_CONTEXT" -n log-pipeline)
kubectl kustomize kubernetes | sed "s|image: log-pipeline:dev|image: $IMAGE|g" | "${k[@]}" apply -f -
job="verify-$(date +%s)-$RANDOM"
"${k[@]}" create job "$job" --from=cronjob/aggregate
if ! "${k[@]}" wait --for=condition=complete "job/$job" --timeout=180s; then
  "${k[@]}" logs "job/$job" || true
  exit 1
fi
"${k[@]}" logs "job/$job"
"${k[@]}" rollout status deployment/reports --timeout=180s
