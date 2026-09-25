# Multi-Environment SaaS Deployment Platform

A small subscription quoting API with a release workflow across development, staging and production. The useful part of this project is promoting one tested image through isolated environments, observing each release, and rolling back without rebuilding it.

The API returns plan prices and calculates quotes using a separate bearer token per environment. Kubernetes gives each environment its own namespace, secrets, quota and deployment identity. Dev runs one replica, staging two and production three. Production promotion is a blocking manual GitLab job.

```text
Commit → tests → Compose smoke → image push → vulnerability scan
       → Dev → Staging → manual production gate → Production
```

This differs from a blue/green switchboard: it manages promotion across three environments, while each environment uses rolling updates.

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

Local endpoints: Dev `http://localhost:8090`, Staging `:8091`, Production `:8092`, Prometheus `:9091`, Grafana `:3010`.

```bash
curl http://localhost:8090/api/plans
bash scripts/init-secrets.sh
set -a; source .env; set +a
curl -H "Authorization: Bearer $API_TOKEN_DEV" -H 'Content-Type: application/json' \
  -d '{"plan":"team","seats":4}' http://localhost:8090/api/quote
```

## Deploy to Kubernetes

First follow the infrastructure guide to create the cluster and install monitoring. For kind, use the name `saas` and load the local image:

```bash
docker build -t saas:dev .
kind load docker-image saas:dev --name saas
export KUBE_CONTEXT=kind-saas
bash scripts/init-secrets.sh
set -a; source .env; set +a
bash scripts/bootstrap.sh
export IMAGE=saas:dev RELEASE=local
for TARGET_ENV in dev staging production; do
  export TARGET_ENV
  bash scripts/deploy.sh
done
kubectl --context "$KUBE_CONTEXT" -n saas-dev port-forward service/saas 8090:8080
```

For a registry image, provision pull credentials after bootstrap and before rollout. Bootstrap needs administrator access; release jobs use the namespace-specific `release-deployer` service account. Environment-scoped kubeconfigs are configured in GitLab, not generated or committed here. Namespaces are an operational boundary within one cluster; stronger production isolation needs a separate cluster/account.
