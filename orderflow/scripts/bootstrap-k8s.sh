#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the explicit Kubernetes context}"
bash scripts/init-secrets.sh
kubectl --context "$KUBE_CONTEXT" apply -f kubernates/namespace.yaml
if kubectl --context "$KUBE_CONTEXT" -n orderflow get secret orderflow-secrets >/dev/null 2>&1; then
  echo 'Secret already exists; leaving it unchanged.'
else
  kubectl --context "$KUBE_CONTEXT" -n orderflow create secret generic orderflow-secrets \
    --from-file=DB_PASSWORD=.secrets/db_password --from-file=API_TOKEN=.secrets/api_token
fi
