# GitLab setup

Use this folder as its own GitLab repository root and enable the container registry. Nested CI files are not automatically discovered from the collection root.

Build jobs require a Docker executor tagged `docker-build`, privileged DinD with TLS, and the `/certs/client` volume configured by Ansible. Restrict it to trusted projects. Deployment jobs use a separate Linux shell executor with Bash, Python 3, PyYAML, kubectl and cluster connectivity. A shell executor does not install tools from the job image.

Set `KUBE_CONFIG` as a GitLab **File** variable containing the deployment identity's kubeconfig, and `KUBE_CONTEXT` to its exact context. Use short-lived credentials through a credential broker or renew them before expiry. Keep credentials out of the repository and logs. Protect the default branch and deployment environments. The bootstrap administrator identity is not a release credential.

The pipeline tests code and Bash syntax, validates Terraform/Ansible, runs Compose smoke checks, pushes SHA-tagged images and blocks deployment on HIGH/CRITICAL scan findings. Upgrade vulnerable dependencies and rebuild to pass the gate. No AWS apply runs in CI. Kubernetes needs durable `read_registry` credentials provisioned before rollout; a publishing job password expires and is unsuitable as a cluster pull secret.

## Scheduled verification

Application deployment uses `platform-deploy`; restore checks use a protected `dr-operator` shell runner with PostgreSQL tools, AWS CLI when needed and permission to exec into the lab database pods.

Create a default-branch schedule every 15 minutes with `KUBE_CONFIG`, `KUBE_CONTEXT` and optionally `S3_BUCKET`. Give the runner an AWS role limited to the backup prefix. The job creates a dump, downloads it again when S3 is enabled, verifies its checksum and restores to an isolated temporary database. Failure fails the job. Review schedule failures alongside backup-age alerts. The destructive drill is never scheduled.

Set Terraform's required `backup_bucket` variable before planning. Retention is not automatically expired; choose a policy before storing real data. Archives are not CI artifacts because they can contain application data.
