#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}" "${NAMESPACE:?}" "${REGISTRY_CONFIG:?Path to read_registry Docker config JSON}"
[[ -f "$REGISTRY_CONFIG" ]] || exit 2
kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" create secret generic registry-pull --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson="$REGISTRY_CONFIG" --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply --server-side -f -
kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" patch serviceaccount default -p '{"imagePullSecrets":[{"name":"registry-pull"}]}'
