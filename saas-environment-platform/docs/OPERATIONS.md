# Release operations

Set `KUBE_CONTEXT` and `TARGET_ENV` explicitly, then run `scripts/health-check.sh`. Inspect events, logs and dashboard metrics for that namespace. Compare `/version` with the intended SHA. The Compose build smoke test also exercises the quote endpoint.

```bash
export TARGET_ENV=staging
bash scripts/rollback.sh
```

Rollback requires a previous ReplicaSet and checks readiness afterward. It does not undo data/configuration changes; this service has no database migration. Record the failed SHA, prior revision, symptom, mitigation and follow-up.

To rotate a token, update only that namespace's `app-secrets` through the administrator secret workflow, restart the deployment and test a quote with the new token. Bootstrap preserves existing secrets and is not a rotation mechanism. Never log tokens.
