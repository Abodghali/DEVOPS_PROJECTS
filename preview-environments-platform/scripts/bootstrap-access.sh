#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Use an administrator context for the dedicated preview cluster}" "${CI_PROJECT_ID:?}"
[[ "$CI_PROJECT_ID" =~ ^[1-9][0-9]{0,11}$ ]] || exit 2
sed "s/PROJECT_ID/$CI_PROJECT_ID/g" kubernetes/deployer-access.yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
echo "Use the preview-$CI_PROJECT_ID service account through a short-lived kubeconfig or your credential broker."
