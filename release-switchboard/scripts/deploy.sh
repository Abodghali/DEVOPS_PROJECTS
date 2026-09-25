#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the target context}"
: "${IMAGE:?Set the full image reference}"
slot=${SLOT:-green}
[[ "$slot" =~ ^(blue|green)$ && "$IMAGE" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/:@-]+$ ]] || exit 2
k=(kubectl --context "$KUBE_CONTEXT" -n release-switchboard)
"${k[@]}" apply -f kubernetes/namespace.yaml
active=$("${k[@]}" get service api -o jsonpath='{.spec.selector.slot}' --ignore-not-found)
if [[ "$active" == "$slot" && "${ALLOW_ACTIVE_UPDATE:-false}" != true ]]; then
  echo "Slot $slot is serving traffic. Deploy to the inactive slot instead." >&2; exit 1
fi
sed "s|image: release-switchboard:dev|image: $IMAGE|g" "kubernetes/$slot.yaml" | "${k[@]}" apply -f -
"${k[@]}" rollout status "deployment/$slot" --timeout=180s
if [[ -z "$active" ]]; then
  sed "s/slot: blue/slot: $slot/" kubernetes/service.yaml | "${k[@]}" apply -f -
fi
echo "Slot $slot is ready. Use scripts/promote.sh to switch existing traffic."
