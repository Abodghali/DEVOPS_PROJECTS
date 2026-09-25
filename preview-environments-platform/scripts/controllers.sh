#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}"
helm repo add traefik https://traefik.github.io/charts --force-update
helm upgrade --install traefik traefik/traefik --version 37.1.1 --namespace traefik --create-namespace --kube-context "$KUBE_CONTEXT" --set deployment.replicas=2 --set service.type=NodePort --set ports.web.nodePort=30080 --set ports.websecure.expose.default=false --set providers.kubernetesCRD.enabled=false --set providers.kubernetesIngress.enabled=true --wait --timeout 10m
