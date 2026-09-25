#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${IMAGE_BASE:?}" "${RELEASE:?}"
[[ "$IMAGE_BASE:$RELEASE" =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]+$ ]] || exit 2
k=(kubectl --context "$KUBE_CONTEXT" -n microservices)
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT
cp kubernetes/workloads.yaml "$rendered"
for service in frontend gateway catalog inventory pricing; do
  sed -i "s|image: microservices-$service:dev|image: $IMAGE_BASE/$service:$RELEASE|g" "$rendered"
done
"${k[@]}" apply -f "$rendered"
"${k[@]}" wait --for=condition=Ready cluster/products-db --timeout=600s
job="migrate-$(date +%s)-$RANDOM"
cat <<EOF | "${k[@]}" apply -f -
apiVersion: batch/v1
kind: Job
metadata: {name: $job}
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 2
  activeDeadlineSeconds: 120
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      containers:
        - name: migrate
          image: $IMAGE_BASE/catalog:$RELEASE
          command: [python, migrate.py]
          env:
            - {name: PGHOST, value: products-db-rw}
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef: {name: app-secrets, key: DB_PASSWORD}
EOF
"${k[@]}" wait --for=condition=complete "job/$job" --timeout=150s
for service in frontend gateway catalog inventory pricing; do
  "${k[@]}" rollout status "deployment/$service" --timeout=180s
done
"${k[@]}" exec deployment/gateway -- python -c "import json,urllib.request; assert json.load(urllib.request.urlopen('http://localhost:8080/api/catalog'))[0]['sku']=='book'"
