# Preview operations

Inspect the namespace derived from the real project/MR IDs:

```bash
kubectl --context "$KUBE_CONTEXT" -n "review-$CI_PROJECT_ID-$CI_MERGE_REQUEST_IID" get pods,ingress,resourcequota
```

Check image availability, pull credentials, events and ingress DNS independently of pod readiness. Failed deployments retain their namespace for diagnosis; Stop or reconciliation removes it. Do not replace a denied preview identity with cluster-admin.

```bash
export CI_API_V4_URL=https://gitlab.com/api/v4
# Set CI_PROJECT_ID, KUBE_CONTEXT and GITLAB_READ_TOKEN first.
python3 scripts/cleanup.py
```

This is a dry run unless `APPLY_CLEANUP=yes`. Selection requires owned labels, a matching namespace pattern, MR state and expiry. Invalid metadata or API failure stops the command. Deployments renew a 24-hour expiry. Cleanup complements Stop when a source branch or retained artifact is gone.

Each review is limited to five pods, 1 requested CPU, 512 MiB requested memory, 2 CPU/1 GiB limits, five secrets and no PVCs. Quotas do not limit the total number of environments. Observe aggregate resource use and namespace count; adjust TTL, runner concurrency or cluster capacity.

Network policy allows ingress from traefik/monitoring and DNS egress. Additional services require explicit policy changes. Namespace deletion removes the preview's resources; keep no durable business data there.
