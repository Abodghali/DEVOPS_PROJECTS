#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the target context}"
: "${IMAGE:?Set the full image reference}"
[[ "$IMAGE" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/:@-]+$ ]] || exit 2
kubectl kustomize kubernetes | sed "s|image: uptime-watch:dev|image: $IMAGE|g" | kubectl --context "$KUBE_CONTEXT" apply -f -
kubectl --context "$KUBE_CONTEXT" -n uptime-watch rollout status deployment/monitor --timeout=180s
kubectl --context "$KUBE_CONTEXT" -n uptime-watch rollout status deployment/demo --timeout=180s
