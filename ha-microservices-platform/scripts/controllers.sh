#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}"
helm repo add traefik https://traefik.github.io/charts --force-update
helm upgrade --install traefik traefik/traefik --version 37.1.1 --namespace traefik --create-namespace --kube-context "$KUBE_CONTEXT" --set deployment.replicas=2 --set service.type=NodePort --set ports.web.nodePort=30080 --set ports.websecure.expose.default=false --set providers.kubernetesCRD.enabled=false --set providers.kubernetesIngress.enabled=true --wait --timeout 10m
helm repo add cnpg https://cloudnative-pg.github.io/charts --force-update
helm upgrade --install cnpg cnpg/cloudnative-pg --version 0.24.0 --namespace cnpg-system --create-namespace --kube-context "$KUBE_CONTEXT" --wait
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
args=()
if [[ "${CLUSTER_KIND:-existing}" == kind ]]; then args+=(--set 'args[0]=--kubelet-insecure-tls'); fi
helm upgrade --install metrics-server metrics-server/metrics-server --version 3.12.2 --namespace kube-system --kube-context "$KUBE_CONTEXT" "${args[@]}" --wait
