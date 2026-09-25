# Availability exercises

Use a dedicated lab with `KUBE_CONTEXT` and `CONFIRM_LAB=microservices`. Capture baseline latency, errors, pod placement and database readiness. Keep gateway requests running during an exercise.

| Incident | Trigger | Recovery |
| --- | --- | --- |
| Pricing HTTP 500 | `bash scripts/incident.sh http-500` | Observe pricing 500/gateway 503; `bash scripts/incident.sh reset` |
| Worker drained | Label a selected worker `lab-incident=allowed`, then `bash scripts/incident.sh node NODE` | Inspect rescheduling and CNPG; `bash scripts/incident.sh recover-node NODE` |
| Memory exhaustion | `bash scripts/incident.sh memory` | Inspect the printed pod for OOMKilled; delete that specific pod |
| Connection exhaustion | `bash scripts/incident.sh connections` | Inspect the printed Job; connections expire after 20s, Job deadline is 45s |

Drain is voluntary disruption and respects PDBs; it is not a power-failure simulation. Insufficient remaining capacity can cause a timeout. Do not label or drain the control plane. Memory injection uses a separate 64 MiB limited pod, not the operator host.

```bash
kubectl --context "$KUBE_CONTEXT" -n microservices get pods -o wide
kubectl --context "$KUBE_CONTEXT" -n microservices get hpa,pdb
kubectl --context "$KUBE_CONTEXT" -n microservices get cluster products-db
kubectl --context "$KUBE_CONTEXT" -n microservices logs deployment/gateway --tail=50
```

After recovery, check every deployment, database readiness and catalog/inventory requests. Record observed errors and recovery time; replica count alone is not availability evidence. HPA needs sustained load and metrics-server. The migration is idempotent; future schema changes need backward-compatible rollout planning.
