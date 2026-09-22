#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?Set the explicit Kubernetes context}"
: "${IMAGE:?Set the versioned image available to cluster nodes}"
[[ "$IMAGE" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/:@-]+$ ]] || { echo 'Invalid image reference' >&2; exit 2; }
k=(kubectl --context "$KUBE_CONTEXT" -n orderflow)
"${k[@]}" apply -f kubernates/namespace.yaml
# Bootstrap the secret separately; deployment must never overwrite credentials.
"${k[@]}" get secret orderflow-secrets >/dev/null
"${k[@]}" apply -f kubernates/database.yaml
"${k[@]}" rollout status statefulset/db --timeout=180s
job="migrate-$(date +%s)-$RANDOM"
cat <<EOF | "${k[@]}" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $job
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 3
  activeDeadlineSeconds: 120
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      containers:
        - name: migrate
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          command: [python, db.py]
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef: {name: orderflow-secrets, key: DB_PASSWORD}
EOF
if ! "${k[@]}" wait --for=condition=complete "job/$job" --timeout=150s; then
  "${k[@]}" logs "job/$job" || true
  exit 1
fi
kubectl kustomize kubernates | sed "s|image: orderflow:dev|image: $IMAGE|g" | "${k[@]}" apply -f -
"${k[@]}" rollout status deployment/api --timeout=180s
"${k[@]}" rollout status deployment/worker --timeout=180s
