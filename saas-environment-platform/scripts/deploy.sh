#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set deployment context}"
: "${TARGET_ENV:?Choose dev, staging or production}"
: "${IMAGE:?Set the tested image reference}"
[[ "$TARGET_ENV" =~ ^(dev|staging|production)$ ]] || exit 2
python3 scripts/render.py | kubectl --context "$KUBE_CONTEXT" apply -f -
kubectl --context "$KUBE_CONTEXT" -n "saas-$TARGET_ENV" rollout status deployment/saas --timeout=180s
bash scripts/health-check.sh
