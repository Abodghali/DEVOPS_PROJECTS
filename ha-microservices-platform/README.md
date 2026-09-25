# Highly Available Microservices Platform

A product catalog split into a frontend, API gateway, catalog, inventory and pricing service. The application is deliberately small so failures are easy to trace across HTTP, PostgreSQL, Redis and Kubernetes.

The cluster deployment gives each application three replicas, readiness/liveness probes, rolling updates, topology spreading, an HPA and a disruption budget. CloudNativePG manages a three-instance PostgreSQL cluster. Redis contains only disposable five-second inventory caches; its three replicas are independent caches, not a replicated Redis database. Database reads remain available when the cache fails.

```text
Ingress → Gateway → Frontend / Catalog / Inventory / Pricing
                              ↓           ↓
                         PostgreSQL     Redis cache
```

The goal is to investigate service failure and capacity, unlike an order queue or a single-service availability monitor.

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

Local endpoints: Gateway `http://localhost:8093`, Prometheus `:9092`, Grafana `:3011`. Compose uses one database and one instance of each service for integration checks; the multi-replica topology is in Kubernetes.

```bash
curl http://localhost:8093/api/catalog
curl http://localhost:8093/api/inventory
curl http://localhost:8093/api/price
```

## Deploy to Kubernetes

Complete cluster and monitoring setup first, using `microservices` as the kind cluster name. Install the ingress controller, database operator and metrics server:

```bash
export KUBE_CONTEXT=kind-microservices CLUSTER_KIND=kind
bash scripts/controllers.sh
bash scripts/init-secrets.sh
set -a; source .env; set +a
bash scripts/bootstrap.sh
for service in frontend gateway catalog inventory pricing; do
  docker build --build-arg SERVICE="$service" -t "lab/$service:dev" .
  kind load docker-image "lab/$service:dev" --name microservices
done
export IMAGE_BASE=lab RELEASE=dev
bash scripts/deploy.sh
kubectl --context "$KUBE_CONTEXT" -n microservices port-forward service/gateway 8093:8080
```

For ingress testing, port-forward the traefik controller and send `Host: store.lab.test`, or configure DNS to the AWS NLB. Private NLB access requires connectivity into the VPC. HPA depends on metrics-server. It scales pods, not nodes.

CloudNativePG failover uses asynchronous replication by default, so this is not a zero-data-loss design. Pod disruption budgets cover voluntary disruption and cannot prevent a sudden node loss. A kind cluster still shares one physical host. See the operations guide for four bounded incident exercises and recovery commands.
