# Continuous Integration and Release Procedure

The executable workflow is in `../.github/workflows/ci.yml`, the location required by GitHub Actions. Push the entire repository to GitHub to enable it. There are no cloud credentials or image registry credentials required.

The workflow runs API behavior tests, builds and starts the Docker service, checks its HTTP health, validates Compose and Kustomize rendering, validates Terraform, checks Ansible syntax, validates Prometheus rules and performs a backup/restore round trip.

## Release to the local Kubernetes lab

After a green workflow, choose a new version such as `1.0.1`. From the repository root:

```sh
docker build -t ops-api:1.0.1 docker
kind load docker-image ops-api:1.0.1 --name ops-lab
```

Update the image in `kubernates/deployment.yaml` to `ops-api:1.0.1`, review and commit the change, then:

```sh
kubectl --context kind-ops-lab apply -k kubernates
kubectl --context kind-ops-lab -n ops-lab rollout status deployment/ops-api --timeout=120s
```

Update `APP_VERSION` in the application environment if you want the HTTP response to report the new version. For rollback, use the Kubernetes runbook and revert the manifest change in Git so the next apply preserves the rollback.

Deployment is manual because GitHub-hosted runners cannot reach a local kind cluster. A real delivery environment needs an approved registry, immutable image references, environment controls and short-lived deployment authentication. No successful workflow run is claimed until you actually execute it in your repository.
