# Kubernetes Resilient Service

The folder name follows the requested `kubernates` spelling. The project deploys the Docker API with two replicas, startup/readiness/liveness probes, restricted pod permissions, a ClusterIP service and a disruption budget.

## Run on kind

Prerequisites: Docker running, kubectl and kind installed. From the repository root:

```sh
kind create cluster --name ops-lab
docker build -t ops-api:1.0.0 docker
kind load docker-image ops-api:1.0.0 --name ops-lab
kubectl --context kind-ops-lab apply -k kubernates
kubectl --context kind-ops-lab -n ops-lab rollout status deployment/ops-api --timeout=120s
kubectl --context kind-ops-lab -n ops-lab get pods
kubectl --context kind-ops-lab -n ops-lab port-forward service/ops-api 8081:80
```

In another terminal, request `http://localhost:8081/healthz`. Expected: HTTP 200 and two Ready pods. Port forwarding is for local access; no public ingress is created.

## Failure and rollback drill

```sh
kubectl --context kind-ops-lab -n ops-lab set image deployment/ops-api api=ops-api:missing
kubectl --context kind-ops-lab -n ops-lab get pods
kubectl --context kind-ops-lab -n ops-lab describe deployment ops-api
kubectl --context kind-ops-lab -n ops-lab get events --sort-by=.lastTimestamp
kubectl --context kind-ops-lab -n ops-lab rollout undo deployment/ops-api
kubectl --context kind-ops-lab -n ops-lab rollout status deployment/ops-api --timeout=120s
```

Expected: the new pod cannot pull its image while the two existing replicas stay available, subject to cluster capacity. Undo restores the previous template. A single-node kind cluster does not provide node-level high availability. The disruption budget only constrains voluntary evictions; it does not prevent crashes or direct pod deletion.

## Cleanup

```sh
kind delete cluster --name ops-lab
```

Reference: [Kubernetes probes](https://kubernetes.io/docs/concepts/workloads/pods/probes/).
