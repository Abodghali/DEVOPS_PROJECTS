# GitLab setup

Use this folder as its own GitLab repository root and enable the container registry. Nested CI files are not automatically discovered from the collection root.

Build jobs require a Docker executor tagged `docker-build`, privileged DinD with TLS, and the `/certs/client` volume configured by Ansible. Restrict it to trusted projects. Deployment jobs use a separate Linux shell executor with Bash, Python 3, PyYAML, kubectl and cluster connectivity. A shell executor does not install tools from the job image.

Set `KUBE_CONFIG` as a GitLab **File** variable containing the deployment identity's kubeconfig, and `KUBE_CONTEXT` to its exact context. Use short-lived credentials through a credential broker or renew them before expiry. Keep credentials out of the repository and logs. Protect the default branch and deployment environments. The bootstrap administrator identity is not a release credential.

The pipeline tests code and Bash syntax, validates Terraform/Ansible, runs Compose smoke checks, pushes SHA-tagged images and blocks deployment on HIGH/CRITICAL scan findings. Upgrade vulnerable dependencies and rebuild to pass the gate. No AWS apply runs in CI. Kubernetes needs durable `read_registry` credentials provisioned before rollout; a publishing job password expires and is unsuitable as a cluster pull secret.

## Service deployment

Five parallel image builds use each service's `SERVICE` build argument and `$CI_REGISTRY_IMAGE/<service>:$CI_COMMIT_SHA`. Compose integration and all five scans must pass. The manual default-branch release runs on `platform-deploy`, waits for CloudNativePG, runs the migration Job and checks the gateway.

Install controllers, monitoring, database secrets and pull credentials first. The deployment identity needs access to workloads and the CloudNativePG Cluster resource in `microservices`; controller installation remains an administrator action. Shared source means each commit rebuilds all services. The pipeline does not claim independently versioned, path-filtered releases.
