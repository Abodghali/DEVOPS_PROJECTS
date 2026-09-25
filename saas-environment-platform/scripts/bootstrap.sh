#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set administrator context}"
for target in dev staging production; do
  namespace="saas-$target"
  kubectl --context "$KUBE_CONTEXT" create namespace "$namespace" --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
  key="API_TOKEN_${target^^}"
  [[ -n "${!key:-}" ]] || { echo "Set $key" >&2; exit 1; }
  if ! kubectl --context "$KUBE_CONTEXT" -n "$namespace" get secret app-secrets >/dev/null 2>&1; then
    kubectl --context "$KUBE_CONTEXT" -n "$namespace" create secret generic app-secrets --from-literal=API_TOKEN="${!key}"
  fi
  python3 -c "import yaml; ds=list(yaml.safe_load_all(open('kubernetes/$target.yaml'))); print(yaml.safe_dump_all([d for d in ds if d['kind'] in ('ResourceQuota','NetworkPolicy')]))" | kubectl --context "$KUBE_CONTEXT" apply -f -
done
kubectl --context "$KUBE_CONTEXT" apply -f kubernetes/deployer-rbac.yaml
