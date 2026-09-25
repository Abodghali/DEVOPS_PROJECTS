#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${TARGET_ENV:?}"
[[ "$TARGET_ENV" =~ ^(dev|staging|production)$ ]] || exit 2
kubectl --context "$KUBE_CONTEXT" -n "saas-$TARGET_ENV" exec deployment/saas -- python -c "import json,urllib.request; u='http://localhost:8080'; urllib.request.urlopen(u+'/readyz',timeout=5); assert json.load(urllib.request.urlopen(u+'/version'))['environment']=='$TARGET_ENV'"
