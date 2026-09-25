# GitLab setup

Use this folder as its own GitLab repository root and enable the container registry. Nested CI files are not automatically discovered from the collection root.

Build jobs require a Docker executor tagged `docker-build`, privileged DinD with TLS, and the `/certs/client` volume configured by Ansible. Restrict it to trusted projects. Deployment jobs use a separate Linux shell executor with Bash, Python 3, PyYAML, kubectl and cluster connectivity. A shell executor does not install tools from the job image.

Set `KUBE_CONFIG` as a GitLab **File** variable containing the deployment identity's kubeconfig, and `KUBE_CONTEXT` to its exact context. Use short-lived credentials through a credential broker or renew them before expiry. Keep credentials out of the repository and logs. Protect the default branch and deployment environments. The bootstrap administrator identity is not a release credential.

The pipeline tests code and Bash syntax, validates Terraform/Ansible, runs Compose smoke checks, pushes SHA-tagged images and blocks deployment on HIGH/CRITICAL scan findings. Upgrade vulnerable dependencies and rebuild to pass the gate. No AWS apply runs in CI. Kubernetes needs durable `read_registry` credentials provisioned before rollout; a publishing job password expires and is unsuitable as a cluster pull secret.

## Preview identity and variables

Use a dedicated `preview-deploy` shell runner assigned only to the trusted project. Pipelines allow same-project MR events and schedules; forks are excluded. Set `REVIEW_BASE_DOMAIN`, and optionally a `REGISTRY_CONFIG` File variable containing read-only Docker registry credentials. Scheduled reconciliation additionally needs `GITLAB_READ_TOKEN` with `read_api`; set `APPLY_CLEANUP=yes` only when ready to delete candidates.

MR branches may not receive protected variables. Use preview-only credentials and a dedicated cluster instead of making production credentials available. Same-project contributors must still be trusted because they control pipeline code.

Run `bootstrap-access.sh` with the real `CI_PROJECT_ID` as an administrator. Then use the preview account's kubeconfig and test admission before enabling pipelines:

```bash
# Both must be rejected:
kubectl --context "$KUBE_CONTEXT" create namespace boundary-check --dry-run=server
kubectl --context "$KUBE_CONTEXT" -n default create configmap boundary-check --from-literal=x=y --dry-run=server
# This project prefix should be accepted:
kubectl --context "$KUBE_CONTEXT" create namespace "review-$CI_PROJECT_ID-999999" --dry-run=server
```

`kubectl auth can-i` checks RBAC, not admission. Inspect admission-policy status as an administrator if results differ.

## Stop and cleanup

The environment has an `on_stop` job and one-day auto-stop duration. Keep GitLab's stop-on-merge/delete behavior enabled. Stop scripts are retained as artifacts for seven days so branch deletion does not prevent checkout. Deployment and Stop share a resource group.

Add an hourly default-branch schedule to handle closed/merged MRs, TTL expiry and missing stop artifacts. Initially omit `APPLY_CLEANUP` to inspect candidates, then enable it. API errors fail closed. One-day expiry also applies to an open MR; another pipeline recreates the preview. Configure wildcard DNS to the ingress endpoint and TLS before sharing real URLs.
