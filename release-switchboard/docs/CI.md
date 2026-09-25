# GitLab CI/CD

Use the contents of `release-switchboard` as the root of its own GitLab repository. Its `.gitlab-ci.yml` runs Python tests, checks Bash/Ansible syntax, validates Terraform, executes the Docker smoke test, and publishes an image tagged with the commit SHA. Deployment is a separate manual job on the default branch.

## Runners

Test jobs use a Linux Docker executor. The build job needs a dedicated privileged Docker-in-Docker runner with a shared `/certs/client` volume and TLS on port 2376. Its service containers must share the runner's project checkout volume at the same path for Compose bind mounts. Follow [GitLab's DinD setup](https://docs.gitlab.com/ci/docker/docker_in_docker/).

The deployment job expects a protected **Linux shell runner** tagged `release-switchboard-deploy`, with Bash, kubectl and connectivity to the cluster. It has no container image because it deliberately uses that runner's installed tools. The job uses a resource group to serialize deployments.

Configure these protected variables:

| Variable | Type | Purpose |
| --- | --- | --- |
| `KUBE_CONFIG` | File | Target kubeconfig |
| `KUBE_CONTEXT` | Variable | Exact context name inside it |

GitLab supplies `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD`, `CI_REGISTRY_IMAGE` and `CI_COMMIT_SHA`. The build publishes the image; the deploy job passes that same commit tag as `IMAGE`.

## Private registry access

Before the first deployment, create the namespace and attach a pull secret to its default service account:

```bash
kubectl --context "$KUBE_CONTEXT" apply -f kubernetes/namespace.yaml
# Set these locally using a deploy token with read_registry scope.
kubectl --context "$KUBE_CONTEXT" -n release-switchboard create secret docker-registry registry-pull \
  --docker-server="$REGISTRY" --docker-username="$REGISTRY_USER" --docker-password="$REGISTRY_TOKEN"
kubectl --context "$KUBE_CONTEXT" -n release-switchboard patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"registry-pull"}]}'
```

Use a long-lived read-only deploy token for node pulls, not the temporary CI job password. Avoid shell tracing while handling credentials. On AWS, use a runner on the host or arrange an SSH tunnel; the Kubernetes API is not publicly exposed.

Review the smoke test result, then run the manual deployment job. Deployment does not execute Terraform apply or destroy. For release-switchboard, set `SLOT` to the inactive slot; deployment prepares that slot, and `scripts/promote.sh` performs the separate traffic switch. For the other projects, follow the README's post-deployment verification.

No remote pipeline run is claimed until the workflow has actually run in your GitLab project. Kustomize rendering and runtime checks are listed in VALIDATION.md.
