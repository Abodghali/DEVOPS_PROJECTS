#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the explicit target context}"
: "${GRAFANA_PASSWORD:?Set a Grafana administrator password}"
k=(kubectl --context "$KUBE_CONTEXT")
if [[ "${CLUSTER_KIND:-existing}" == kind ]]; then
  helm repo add cilium https://helm.cilium.io/ --force-update
  helm upgrade --install cilium cilium/cilium --version 1.18.1 --namespace kube-system --kube-context "$KUBE_CONTEXT" --set ipam.mode=kubernetes --wait --timeout 10m
fi
if [[ "${CLUSTER_KIND:-existing}" == aws ]]; then
  "${k[@]}" apply -f kubernetes/storageclass.yaml
fi
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
"${k[@]}" create namespace monitoring --dry-run=client -o yaml | "${k[@]}" apply -f -
if ! "${k[@]}" -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  "${k[@]}" -n monitoring create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password="$GRAFANA_PASSWORD"
fi
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --version 75.15.1 --namespace monitoring --kube-context "$KUBE_CONTEXT" -f monitoring/values.yaml --wait --timeout 10m
"${k[@]}" apply -f monitoring/dashboard.yaml -f monitoring/servicemonitor.yaml -f monitoring/rules.yaml
