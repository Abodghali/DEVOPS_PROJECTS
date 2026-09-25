#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${CI_PROJECT_ID:?}" "${CI_MERGE_REQUEST_IID:?}"
namespace=$(python3 -c 'import sys;sys.path.insert(0,"scripts");from render import namespace;import os;print(namespace(os.environ["CI_PROJECT_ID"],os.environ["CI_MERGE_REQUEST_IID"]))')
k=(kubectl --context "$KUBE_CONTEXT")
existing=$("${k[@]}" get namespace "$namespace" --ignore-not-found -o json)
if [[ -n "$existing" ]]; then
  printf '%s' "$existing" | python3 -c 'import json,os,sys;sys.path.insert(0,"scripts");from render import owned;d=json.load(sys.stdin);assert owned(d["metadata"]["name"],d["metadata"].get("labels",{}),os.environ["CI_PROJECT_ID"],os.environ["CI_MERGE_REQUEST_IID"]), "Namespace is not owned by this project"'
fi
case "${1:-deploy}" in
  deploy)
    : "${IMAGE:?}" "${REVIEW_BASE_DOMAIN:?}"
    python3 scripts/render.py | "${k[@]}" apply -f -
    # For a private registry, supply a prebuilt dockerconfigjson FILE; never store it in Git.
    if [[ -n "${REGISTRY_CONFIG:-}" ]]; then
      "${k[@]}" -n "$namespace" create secret generic registry-pull --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson="$REGISTRY_CONFIG" --dry-run=client -o yaml | "${k[@]}" apply --server-side -f -
      "${k[@]}" -n "$namespace" patch serviceaccount default -p '{"imagePullSecrets":[{"name":"registry-pull"}]}'
      "${k[@]}" -n "$namespace" rollout restart deployment/app
    fi
    "${k[@]}" -n "$namespace" rollout status deployment/app --timeout=180s
    "${k[@]}" -n "$namespace" exec deployment/app -- python -c "import json,urllib.request; r=json.load(urllib.request.urlopen('http://localhost:8080/version')); assert r['review']=='$namespace'"
    mkdir -p results
    printf 'REVIEW_URL=http://%s.%s\n' "$namespace" "$REVIEW_BASE_DOMAIN" > results/review.env
    ;;
  stop)
    [[ -z "$existing" ]] || "${k[@]}" delete namespace "$namespace" --wait=false
    ;;
  *) echo 'Usage: bash scripts/preview.sh deploy|stop' >&2; exit 2 ;;
esac
