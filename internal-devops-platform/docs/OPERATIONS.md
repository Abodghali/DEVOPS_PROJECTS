# Runner operations

Run maintenance on the dedicated Ubuntu host with Docker/systemd privileges:

```bash
bash scripts/runner-health.sh
bash scripts/disk-check.sh
bash scripts/cleanup-images.sh
bash scripts/rotate-logs.sh
```

Cleanup and rotation preview by default. `CONFIRM_CLEANUP=yes` removes only dangling images older than seven days, not volumes or every cached image. `APPLY_ROTATION=yes` applies the provided policy to runner file logs. Journald retention is separate; logrotate does not manage the journal.

| Incident | Evidence and recovery |
| --- | --- |
| Offline runner | Check service status, runner verify, HTTPS reachability and token validity; fix the cause before restarting. Revoked tokens need re-registration. |
| Disk pressure | Inspect df, docker system df and log growth. Preview cleanup. `MIN_FREE_PERCENT=100 bash scripts/disk-check.sh` exercises threshold failure without filling the disk. |
| Docker failure | Read `journalctl -u docker --since '-15 min'`, validate daemon configuration and space, then restart in a maintenance window. Active jobs may fail. |
| Queue delay | Compare runner tags, protection, concurrency, pending age and available executor capacity. Wrong tags prevent scheduling on an otherwise idle runner. |

Pause a dedicated lab runner in GitLab to exercise waiting jobs, then unpause. Pausing may leave API status online; watch queue age too. To exercise process-offline metrics, stop that dedicated service in a lab window and restart it. Do not interrupt shared runners for a sample alert.

`gitlab_api_up=0` means a poll failed; retained pipeline samples may be stale. Check last-success time. Counts describe the latest 20 pipelines, not complete history/SLOs. Rotate API credentials by updating the secret and restarting telemetry; bootstrap preserves an existing secret.
