# GitLab setup

Use this folder as its own GitLab repository root and enable the container registry. Nested CI files are not automatically discovered from the collection root.

Build jobs require a Docker executor tagged `docker-build`, privileged DinD with TLS, and the `/certs/client` volume configured by Ansible. Restrict it to trusted projects. Deployment jobs use a separate Linux shell executor with Bash, Python 3, PyYAML, kubectl and cluster connectivity. A shell executor does not install tools from the job image.

Set `KUBE_CONFIG` as a GitLab **File** variable containing the deployment identity's kubeconfig, and `KUBE_CONTEXT` to its exact context. Use short-lived credentials through a credential broker or renew them before expiry. Keep credentials out of the repository and logs. Protect the default branch and deployment environments. The bootstrap administrator identity is not a release credential.

The pipeline tests code and Bash syntax, validates Terraform/Ansible, runs Compose smoke checks, pushes SHA-tagged images and blocks deployment on HIGH/CRITICAL scan findings. Upgrade vulnerable dependencies and rebuild to pass the gate. No AWS apply runs in CI. Kubernetes needs durable `read_registry` credentials provisioned before rollout; a publishing job password expires and is unsuitable as a cluster pull secret.

## Promotion

Tag the release executor `platform-deploy`. Scope separate `KUBE_CONFIG` and context variables to `dev`, `staging` and `production`. Each credential uses that namespace's `release-deployer` account; bootstrap installs its Role and RoleBinding.

Default-branch pipelines promote the same SHA image automatically to Dev, then Staging, then wait at a blocking manual production job. Protect the `production` environment and select allowed deployers in GitLab. Required multi-person approvals, where supported by your GitLab tier, are an additional UI setting; a manual job alone is not that approval policy.

Bootstrap creates separate app tokens, quotas, network policies and registry secrets. The release Role grants no Secrets API access; treat release identities as trusted within their own namespace because they can control its workloads. Resource groups serialize environment deployments. Rollback remains an explicit operator action.
