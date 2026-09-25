# Operations exercises

## Worker outage

1. Run `docker compose stop worker`.
2. Submit a new order following the README; polling its ID should show `pending`.
3. Inspect `docker compose ps -a` and `docker compose logs --tail=30 worker`.
4. Run `docker compose start worker`. The existing order should become `completed`.
5. Scale with `docker compose up -d --scale worker=3 worker` and submit more uniquely keyed orders.

In Kubernetes, use `kubectl --context "$KUBE_CONTEXT" -n orderflow scale deployment/worker --replicas=0` and then restore replicas to 2. Database row locks allow workers to process different pending orders concurrently. There are no external side effects in this implementation.

## Database outage

Stop `db` in Compose. `/healthz` should remain HTTP 200 while `/readyz` becomes 503; requests that need the database fail with 503. Restart `db`; the worker retries automatically. Never delete the volume to fix a connection problem. Collect logs, check storage capacity, secret consistency and database readiness.

## Backup and restore verification

With Compose running, from the project root:

```bash
file=$(bash scripts/backup.sh)
bash scripts/restore-check.sh "$file"
```

`pg_dump -Fc` creates a consistent logical database backup. Restore verification creates a separate temporary database, restores with exit-on-error, queries the order table, then drops only that temporary database. It does not overwrite the live application database. Files are stored under ignored `backups/`; retain copies outside the host if you need disaster recovery.

For Kubernetes, take a dump through the database pod:

```bash
umask 077
mkdir -p backups
kubectl --context "$KUBE_CONTEXT" -n orderflow exec db-0 -- pg_dump -U orders -d orders -Fc > backups/k8s-orders.dump
```

Verify the command exit status and restore the dump in an isolated PostgreSQL 17 instance before relying on it. The Compose restore script targets Compose only. Dumps do not include cluster roles or Kubernetes configuration; retain those separately. No retention scheduler or offsite storage is configured.

## Release troubleshooting

- `ImagePullBackOff`: check the commit tag exists, registry pull secret is attached, and token has `read_registry`.
- Migration failure: inspect the named migration Job logs; do not proceed with incompatible application code.
- Pending PVC: verify default StorageClass and node disk capacity.
- Pending orders with Ready API: check worker logs; HTTP availability alone does not prove background processing.

Record incident start/end times, impact, evidence, root cause, recovery commands and one prevention action. Stop the local stack with `docker compose down`; add `-v` only when intentionally deleting all local order data.
