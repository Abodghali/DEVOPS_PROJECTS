#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${IMAGE:?}"
[[ "$IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]+$ ]] || exit 2
k=(kubectl --context "$KUBE_CONTEXT" -n dr-lab)
# Do not silently route a recovered system back to a damaged primary.
active=$("${k[@]}" get service active-db --ignore-not-found -o jsonpath='{.spec.selector.slot}')
[[ -z "$active" || "$active" == primary ]] || { echo 'System is on recovery. Complete an explicit failback plan before redeployment.' >&2; exit 1; }
sed "s|image: dr-notes:dev|image: $IMAGE|g" kubernetes/workloads.yaml | "${k[@]}" apply -f -
"${k[@]}" rollout status statefulset/primary --timeout=180s
"${k[@]}" rollout status statefulset/recovery --timeout=180s
# Migration can run in an app pod even while its readiness check is failing.
"${k[@]}" wait --for=jsonpath='{.status.phase}'=Running pod -l app=notes --timeout=180s
"${k[@]}" exec deployment/notes -- python migrate.py
"${k[@]}" rollout status deployment/notes --timeout=180s
