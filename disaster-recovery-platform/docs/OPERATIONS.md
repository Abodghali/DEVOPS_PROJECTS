# Backup and recovery runbook

Run from the project root with explicit `KUBE_CONTEXT`. Scripts check the `dr-lab` ownership label. Archives are private, ignored files in `backups/`. Use PostgreSQL 17 clients when processing dumps outside the pods.

```bash
backup=$(bash scripts/backup.sh)
bash scripts/verify-backup.sh "$backup"
```

Verification checks SHA-256, restores into a unique temporary recovery database, queries notes and drops that temporary database on exit. It does not replace the active database. An upload alone is not a restore test.

With `S3_BUCKET` set, archive, checksum and metadata are uploaded. To retrieve one, replace the sample key with a real generated object key:

```bash
backup=$(bash scripts/download-backup.sh dr/20260925T120000Z-1234.dump)
bash scripts/verify-backup.sh "$backup"
```

Checksums detect accidental corruption, not an attacker who can replace both files. Restrict backup write permissions and choose retention deliberately.

## Recover and fail over

```bash
CONFIRM_RESTORE=dr-lab/recovery bash scripts/restore.sh "$backup"
CONFIRM_FAILOVER=dr-lab/recovery bash scripts/failover.sh
```

Restore replaces only inactive recovery. Failover verifies its schema, switches `active-db`, restarts notes to renew connections and checks readiness. Check expected records through the API. Subsequent backups follow recovery. Deployment refuses to silently route back to damaged primary.

## Destructive lab drill

This command **truncates the primary notes table** and leaves traffic on recovery:

```bash
CONFIRM_DISASTER=dr-lab bash scripts/drill.sh
cat results/recovery.json
```

It creates a pre-backup marker, backs up/verifies, creates a post-backup marker, starts timing, truncates primary, restores and fails over. Assertions prove the older marker survived and the newer one was lost. RTO is outage start through service recovery checks. RPO is outage start minus the newest restored record timestamp: a conservative age-of-data proxy including idle time, not WAL lag. Synchronize clocks.

Backup age and latest drill RTO/RPO go to Pushgateway. Review GitLab restore-job failures, database health and PVC space too. The drill cannot run again while recovery is active.

## Failback and cluster loss

Back up and verify recovery first. Plan a maintenance window to rebuild/synchronize primary, stop writes for final synchronization, verify records and switch traffic deliberately. Automated failback is outside this lab. For a disposable repeat exercise, create another cluster and restore S3 data rather than overwriting the only recovered copy.

Total cluster loss additionally requires provisioning, storage/monitoring setup, secret bootstrap and S3 restoration in a new cluster. The supplied drill measures database loss within an existing cluster only. S3 cross-region replication and point-in-time WAL recovery are not configured.
