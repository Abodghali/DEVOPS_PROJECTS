#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the target context}"
[[ $# == 1 && "$1" =~ ^(blue|green)$ ]] || { echo 'Usage: bash scripts/promote.sh blue|green' >&2; exit 2; }
slot=$1
k=(kubectl --context "$KUBE_CONTEXT" -n release-switchboard)
"${k[@]}" rollout status "deployment/$slot" --timeout=120s
old=$("${k[@]}" get service api -o jsonpath='{.spec.selector.slot}')
image=$("${k[@]}" get deployment "$slot" -o jsonpath='{.spec.template.spec.containers[0].image}')
# Execute a real in-cluster request using the candidate's Python runtime.
"${k[@]}" run "check-$RANDOM" --image="$image" --restart=Never --rm -i --command -- \
  python -c "import urllib.request; urllib.request.urlopen('http://api-$slot/healthz',timeout=5)"
"${k[@]}" patch service api --type=merge -p "{\"spec\":{\"selector\":{\"slot\":\"$slot\"}}}"
if ! "${k[@]}" run "verify-$RANDOM" --image="$image" --restart=Never --rm -i --command -- \
  python -c "import json,time,urllib.request; time.sleep(3); value=json.load(urllib.request.urlopen('http://api/version',timeout=5)); assert value['version']=='$slot', value"; then
  "${k[@]}" patch service api --type=merge -p "{\"spec\":{\"selector\":{\"slot\":\"$old\"}}}"
  echo 'Verification failed; previous selector restored.' >&2; exit 1
fi
echo "Traffic switched from $old to $slot"
