# Self-Hosted CI/CD and DevOps Automation Platform

An internal build platform for several GitLab projects. It provisions runner infrastructure, provides reusable CI templates, runs build workloads on Kubernetes, and collects pipeline and runner health into Prometheus and Grafana.

Terraform creates the cluster and a dedicated runner host. Ansible prepares Linux, Docker, runner registration and host monitoring. A small read-only exporter polls selected GitLab projects for recent pipeline outcomes, duration, pending age and runner status. Bash tools inspect runner health, disk headroom and retained image/log data.

```text
GitLab projects → reusable jobs → Docker runner / Kubernetes runner → images
       ↓ API polling                      ↓ node and runner metrics
   telemetry exporter ─────────────→ Prometheus → Grafana
```

This repository self-hosts execution infrastructure. It connects to an existing GitLab.com or self-managed GitLab instance; it does not install the GitLab server.

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

Local endpoints: Telemetry `http://localhost:8096`, Prometheus `:9095`, Grafana `:3014`. Compose includes a deterministic GitLab API fixture so it runs without an account. Its one successful pipeline and online runner are sample data, not measurements of your GitLab installation.

```bash
curl http://localhost:8096/summary
curl http://localhost:8096/metrics
```

## Connect real projects on Kubernetes

Complete infrastructure/monitoring setup with a kind cluster named `ci-platform`, then set a token whose owner can read the projects' pipelines and runner information. The token needs `read_api`; access also depends on the user's project role.

```bash
export KUBE_CONTEXT=kind-ci-platform
export GITLAB_URL=https://gitlab.com GITLAB_PROJECT_IDS=42,84
read -rsp 'GitLab read API token: ' GITLAB_READ_TOKEN; echo
export GITLAB_READ_TOKEN
bash scripts/bootstrap.sh
unset GITLAB_READ_TOKEN
docker build -t ci-telemetry:dev .
kind load docker-image ci-telemetry:dev --name ci-platform
export IMAGE=ci-telemetry:dev
bash scripts/deploy.sh
```

The exporter polls every 30 seconds, samples the latest 20 pipelines and up to five completed durations per project. Queue age is a pipeline-level approximation; it is not a complete job-queue histogram. API failure is reported separately from the last retained data.

Use [GitLab setup](docs/GITLAB.md) for reusable jobs, runner installation and an optional BuildKit exercise. Use [Operations](docs/OPERATIONS.md) for offline runners, disk pressure, Docker failure and queue delays. The production deploy executor stays separate from general builders.
