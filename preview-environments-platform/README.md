# Dynamic Preview Environments Platform

Every same-project merge request can get an isolated, temporary application URL. The pipeline builds and scans its image, creates a namespace such as `review-42-123`, deploys the application, and publishes the review URL in GitLab.

A namespace contains a resource quota, network policy, deployment, service and ingress. GitLab's stop action removes it when the environment stops; a scheduled reconciler also removes expired or merged/closed environments. It checks both the project labels and namespace pattern before deletion.

```text
Merge request → Test → Build → Scan → Namespace → Deploy → Smoke → Review URL
                                                       ↓ merge / close / expiry
                                                     Namespace cleanup
```

Unlike permanent dev/staging/production environments, these resources belong to a merge request and have a limited lifetime.

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

Local endpoints: Demo `http://localhost:8095`, Prometheus `:9094`, Grafana `:3013`. Compose runs the application only; per-MR namespace lifecycle needs Kubernetes.

## Try one preview locally

Complete infrastructure/monitoring setup with a kind cluster named `previews`, then install ingress and create a preview:

```bash
export KUBE_CONTEXT=kind-previews CLUSTER_KIND=kind
bash scripts/controllers.sh
docker build -t preview-app:dev .
kind load docker-image preview-app:dev --name previews
export CI_PROJECT_ID=42 CI_MERGE_REQUEST_IID=123
export IMAGE=preview-app:dev REVIEW_BASE_DOMAIN=review.lab.test
bash scripts/preview.sh deploy
kubectl --context "$KUBE_CONTEXT" -n traefik port-forward service/traefik 8088:80
# In another terminal:
curl -H 'Host: review-42-123.review.lab.test' http://localhost:8088/version
```

The URL written to `results/review.env` uses port 80 and assumes wildcard DNS points to the ingress endpoint. For port-forward testing, use the Host header and port 8088 above. Configure DNS and TLS before sharing real preview URLs.

```bash
bash scripts/preview.sh stop
```

## CI access boundary

Use Kubernetes 1.30+ and a dedicated preview cluster. `CI_PROJECT_ID=42 bash scripts/bootstrap-access.sh` installs a service account and a ValidatingAdmissionPolicy that restricts its mutations to `review-42-*`. Bootstrap with an administrator, then use a kubeconfig for that service account in the deployment runner. Do not use the bootstrap admin kubeconfig in MR jobs. The account can read cluster-wide metadata needed for reconciliation; it must not share a production cluster.

Validate the admission policy's denial with that CI identity before enabling MR pipelines (steps in the GitLab guide). Fork merge requests are excluded. Same-project contributors must still be trusted: pipeline code runs on the assigned runners and receives the preview credentials. A read-only registry config file can be supplied through `REGISTRY_CONFIG` for each temporary namespace.
