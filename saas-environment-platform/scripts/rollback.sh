#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${TARGET_ENV:?}"
[[ "$TARGET_ENV" =~ ^(dev|staging|production)$ ]] || exit 2
kubectl --context "$KUBE_CONTEXT" -n "saas-$TARGET_ENV" rollout undo deployment/saas
kubectl --context "$KUBE_CONTEXT" -n "saas-$TARGET_ENV" rollout status deployment/saas --timeout=180s
bash scripts/health-check.sh
