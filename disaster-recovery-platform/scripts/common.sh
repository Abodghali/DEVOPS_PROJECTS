#!/usr/bin/env bash
set -euo pipefail
: "${KUBE_CONTEXT:?Set the dedicated DR lab context}"
k=(kubectl --context "$KUBE_CONTEXT" -n dr-lab)
owner=$("${k[@]}" get namespace dr-lab -o jsonpath='{.metadata.labels.lab-owner}')
[[ "$owner" == portfolio ]] || { echo 'Expected the labelled dr-lab namespace.' >&2; exit 2; }
active_slot() { "${k[@]}" get service active-db -o jsonpath='{.spec.selector.slot}'; }
check_dump() {
  [[ -s "$1" && -s "$1.sha256" ]] || { echo 'Dump or checksum is missing.' >&2; return 1; }
  (cd "$(dirname "$1")" && sha256sum -c "$(basename "$1").sha256")
}
