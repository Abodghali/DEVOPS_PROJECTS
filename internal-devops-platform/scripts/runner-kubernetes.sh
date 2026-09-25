#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${RUNNER_AUTH_TOKEN:?Create a runner in GitLab first}" "${GITLAB_URL:?}"
k=(kubectl --context "$KUBE_CONTEXT")
"${k[@]}" create namespace build-runners --dry-run=client -o yaml | "${k[@]}" apply -f -
"${k[@]}" -n build-runners create secret generic runner-auth --from-literal=runner-token="$RUNNER_AUTH_TOKEN" --from-literal=runner-registration-token='' --dry-run=client -o yaml | "${k[@]}" apply -f -
helm repo add gitlab https://charts.gitlab.io --force-update
helm upgrade --install runner gitlab/gitlab-runner --version 0.82.0 --namespace build-runners --kube-context "$KUBE_CONTEXT" -f kubernetes/runner-values.yaml --set gitlabUrl="$GITLAB_URL" --wait
