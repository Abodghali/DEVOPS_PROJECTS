# Disaster Recovery and Backup Automation Platform

A notes service with PostgreSQL, a separate recovery database, verified backup archives and an explicit failover procedure. The recovery drill creates known records, takes a backup, loses lab data, restores to recovery and checks which records survived.

Backups use PostgreSQL custom-format dumps with SHA-256 checksums and metadata. Verification restores into a temporary database before declaring an archive usable. S3 storage is optional; Terraform creates a private, encrypted and versioned bucket with a scoped backup policy. GitLab schedules can test restoration without running the destructive drill.

```text
Notes → active-db service → Primary PostgreSQL
                            ↓ pg_dump + checksum → S3
                      isolated restore → Recovery PostgreSQL
Notes → active-db service ────────────────────────┘
```

This is a recovery engineering project, rather than simply adding a backup command to an application.

## Run locally

Use Docker Engine with Compose v2. Run the commands from this directory in Bash (WSL2 or Linux is recommended on Windows).

```bash
bash scripts/local.sh
```

The first run writes random local credentials to ignored `.env`; subsequent runs keep them. Grafana's user is `admin`, with `GRAFANA_PASSWORD` from that file. `docker compose down` stops the lab and retains database volumes. Only use `docker compose down -v` when you intend to discard local data.

## Repository guide

- `app/` and `tests/`: the service and executable checks.
- `compose.yaml` and `Dockerfile`: local integration environment and image build.
- `kubernetes/`: cluster workloads, configuration and access policies.
- `terraform/`: AWS infrastructure, reusable cluster module and S3 state bootstrap.
- `ansible/`: Ubuntu runner configuration.
- `.gitlab-ci.yml`: build, verification and release workflow.
- `scripts/`: operational commands; each validates required inputs.
- `monitoring/`: Prometheus discovery, rules and Grafana dashboards.

See [Infrastructure](docs/INFRASTRUCTURE.md), [Monitoring](docs/MONITORING.md), [Operations](docs/OPERATIONS.md), [GitLab setup](docs/GITLAB.md) and [Validation](VALIDATION.md). Cloud and cluster setup are optional when exploring the Compose application. Test results and deployment limits are recorded separately from the intended architecture.

Local endpoints: Notes `http://localhost:8094`, Prometheus `:9093`, Grafana `:3012`. Compose covers the application and schema migration; the separate recovery target and drill run in Kubernetes.

```bash
curl -H 'Content-Type: application/json' -d '{"text":"first recovery record"}' http://localhost:8094/notes
curl http://localhost:8094/notes
```

## Deploy and verify a backup

Complete cluster/monitoring setup with kind cluster name `recovery`, then:

```bash
export KUBE_CONTEXT=kind-recovery
bash scripts/init-secrets.sh
set -a; source .env; set +a
bash scripts/bootstrap.sh
docker build -t dr-notes:dev .
kind load docker-image dr-notes:dev --name recovery
export IMAGE=dr-notes:dev
bash scripts/deploy.sh
backup=$(bash scripts/backup.sh)
bash scripts/verify-backup.sh "$backup"
```

Set `S3_BUCKET` to the Terraform backup bucket output and authenticate AWS CLI before `backup.sh` to upload archives. The IAM policy output must be attached to the chosen operator role; it is not attached automatically. The infrastructure guide explains the separate remote-state bucket.

The [recovery runbook](docs/OPERATIONS.md) covers an opt-in destructive drill and the measured RTO/RPO definitions. This lab uses logical backups, not WAL archiving or point-in-time recovery. Primary and recovery share a cluster; they do not protect against total cluster/region loss until a new cluster is provisioned and an S3 archive is restored there. No business recovery objective is claimed from a configuration file.
