# Kubernetes deployment

Requirements: Docker, kubectl, kind, Bash and a default StorageClass. kind and K3s normally provide local storage; its volumes are tied to a node and are not an external backup.

Run from the project root:

```bash
kind create cluster --name orderflow
docker build -t orderflow:dev .
kind load docker-image orderflow:dev --name orderflow
export KUBE_CONTEXT=kind-orderflow
bash scripts/bootstrap-k8s.sh
export IMAGE=orderflow:dev
bash scripts/deploy.sh
kubectl --context "$KUBE_CONTEXT" -n orderflow get pods,pvc
kubectl --context "$KUBE_CONTEXT" -n orderflow port-forward service/api 8082:80
```

Run `python3 tests/smoke.py` in another terminal. Stop the Compose API first if port 8082 is already occupied. `deploy.sh` waits for the database, runs schema creation as a Job, then rolls out the API and workers. The schema is additive and repeatable; future incompatible schema changes need explicit migrations and compatibility planning.

## Registry images

For a private GitLab registry, create a Kubernetes pull secret using a GitLab deploy token with `read_registry`, then attach it to the default service account before deployment:

```bash
# Set REGISTRY, REGISTRY_USER and REGISTRY_TOKEN locally; do not commit them.
kubectl --context "$KUBE_CONTEXT" -n orderflow create secret docker-registry registry-pull \
  --docker-server="$REGISTRY" --docker-username="$REGISTRY_USER" --docker-password="$REGISTRY_TOKEN"
kubectl --context "$KUBE_CONTEXT" -n orderflow patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"registry-pull"}]}'
```

All workloads, including the migration Job, use that service account. A deploy token must outlive the CI build job; the temporary CI registry password is not suitable for future node pulls. Avoid shell tracing while creating credentials. Export IMAGE as the full registry reference with the commit SHA tag.

## Rollback

```bash
kubectl --context "$KUBE_CONTEXT" -n orderflow rollout undo deployment/api
kubectl --context "$KUBE_CONTEXT" -n orderflow rollout undo deployment/worker
```

Rollback changes the workloads, not database schema. Set IMAGE to the previous release before the next deployment. Bootstrap never replaces existing credentials; if using another cluster's secret, use that cluster's API token for smoke tests.

Cleanup of the entire local lab: `kind delete cluster --name orderflow`. This destroys the local database; take a backup first if you need its contents.
