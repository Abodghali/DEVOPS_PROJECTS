#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?}"
[[ "${CONFIRM_LAB:-}" == microservices ]] || { echo 'Set CONFIRM_LAB=microservices for this dedicated lab only.' >&2; exit 2; }
k=(kubectl --context "$KUBE_CONTEXT" -n microservices)
case "${1:-}" in
  http-500) "${k[@]}" set env deployment/pricing INJECT_HTTP_500=true ;;
  reset) "${k[@]}" set env deployment/pricing INJECT_HTTP_500- ;;
  node)
    : "${2:?Provide a node explicitly labelled lab-incident=allowed}"
    allowed=$("${k[@]}" get node "$2" -o jsonpath='{.metadata.labels.lab-incident}')
    [[ "$allowed" == allowed ]] || exit 2
    "${k[@]}" drain "$2" --ignore-daemonsets --delete-emptydir-data --timeout=120s
    ;;
  recover-node) "${k[@]}" uncordon "${2:?Provide the drained lab node}" ;;
  memory)
    "${k[@]}" run "memory-leak-$RANDOM" --image=python:3.13-slim --restart=Never --overrides='{"spec":{"containers":[{"name":"leak","image":"python:3.13-slim","resources":{"requests":{"memory":"32Mi"},"limits":{"memory":"64Mi"}},"command":["python","-c","import time\nblocks=[]\nwhile True:\n blocks.append(bytearray(4*1024*1024))\n time.sleep(.2)"]}]}}'
    ;;
  connections)
    "${k[@]}" create -f "$(dirname "$0")/../kubernetes/connection-incident.yaml"
    ;;
  *) echo 'Usage: incident.sh http-500|reset|node NAME|recover-node NAME|memory|connections' >&2; exit 2 ;;
esac
