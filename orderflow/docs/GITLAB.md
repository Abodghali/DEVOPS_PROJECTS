# GitLab pipeline setup

Make the contents of `orderflow` the root of its own GitLab repository so `.gitlab-ci.yml` is discovered automatically. No GitLab project or remote pipeline has been created by these files.

The test stage checks input validation, Python syntax, Terraform validation and Ansible/Bash syntax. The build stage starts the full Compose stack, checks authenticated asynchronous processing and retry behavior, tests a database dump restore, and pushes a commit-SHA image to the GitLab Container Registry.

## Runner requirements

- Test jobs: Linux Docker executor with internet access.
- Build job: dedicated Docker executor configured for privileged Docker-in-Docker with a shared `/certs/client` volume. TLS is enabled on port 2376. Follow GitLab's official DinD setup; do not run untrusted projects on this privileged runner.
- Deploy job: protected Linux **shell executor** tagged `orderflow-deploy`, with Bash, kubectl, network access to the cluster and no Docker executor image assumptions. Deployment is manual on the default branch and serialized with a resource group.

Configure protected GitLab variables:

| Variable | Kind | Value |
| --- | --- | --- |
| `KUBE_CONFIG` | File | Kubeconfig for the target staging cluster |
| `KUBE_CONTEXT` | Variable | Exact context name inside that kubeconfig |

The `CI_REGISTRY*` and `CI_COMMIT_SHA` values are supplied by GitLab. Bootstrap the namespace, application secret and long-lived registry pull secret separately using the Kubernetes guide. Keep deployment credentials available only to the protected deployment runner/environment.

For the EC2 route, a runner on that host can use a securely provisioned local kubeconfig. A runner elsewhere needs an SSH tunnel or private networking; the Terraform security group does not expose the Kubernetes API publicly. The lab kubeconfig is administrative; create a scoped deployment identity before use in a shared environment.

## Release and recovery

Merge tested changes to the default branch. Once build succeeds, manually run `deploy_staging`. The deployment runs a migration Job before updating workloads and waits for rollout completion. Failed migration prevents the new application rollout. Worker rollout status alone does not prove queue processing: after release, port-forward the API and run `tests/smoke.py` with the staging token.

Use the Kubernetes rollback steps to restore previous application images. The pipeline deliberately does not run Terraform apply, destroy, or database credential rotation automatically.

Reference: [GitLab Docker-in-Docker setup](https://docs.gitlab.com/ci/docker/docker_in_docker/).
