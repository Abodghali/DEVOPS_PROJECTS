# DevOps Project Collection

Ten independent projects covering application operations, release workflows and infrastructure platforms. Each folder has its own source, configuration, tests and operating guide.

| Project | What it does | Main workflow |
| --- | --- | --- |
| [DevOps Operations Lab](devops-operations-lab/README.md) | Runs and monitors an HTTP service, with infrastructure and recovery exercises. | Docker, Kubernetes, Prometheus, Terraform, Ansible, GitHub Actions, Bash |
| [OrderFlow](orderflow/README.md) | Accepts orders and processes them asynchronously through PostgreSQL-backed workers. | Docker, Kubernetes, PostgreSQL, Terraform, Ansible, GitLab CI/CD, Bash |
| [Release Switchboard](release-switchboard/README.md) | Tests a candidate release and switches traffic between blue and green slots. | Docker, Nginx, Kubernetes, Terraform, Ansible, GitLab CI/CD, Bash |
| [Uptime Watch](uptime-watch/README.md) | Records HTTP availability, detects consecutive failures, and tracks recovery. | Python, SQLite, Docker, Kubernetes, Terraform, Ansible, GitLab CI/CD, Bash |
| [Log Pipeline](log-pipeline/README.md) | Validates JSONL logs and publishes reports through scheduled jobs. | Python, Docker, Kubernetes CronJobs, Terraform, Ansible, GitLab CI/CD, Bash |
| [Multi-Environment SaaS](saas-environment-platform/README.md) | Promotes one image across Dev, Staging and Production with an explicit production gate. | Docker, Kubernetes, Terraform, Ansible, GitLab CI/CD, Bash, Prometheus, Grafana |
| [HA Microservices](ha-microservices-platform/README.md) | Operates a service catalog with replicated workloads, PostgreSQL failover and bounded incident exercises. | Docker, Kubernetes, CloudNativePG, Redis, Terraform, Ansible, GitLab CI/CD, Bash, monitoring |
| [Disaster Recovery](disaster-recovery-platform/README.md) | Verifies PostgreSQL backups, restores to a separate target and measures a recovery drill. | Docker, Kubernetes, S3, Terraform, Ansible, GitLab schedules, Bash, monitoring |
| [Preview Environments](preview-environments-platform/README.md) | Creates a temporary namespace and URL per merge request, with Stop and scheduled cleanup. | Docker, Kubernetes, Terraform, Ansible, GitLab review apps, Bash, monitoring |
| [Internal DevOps Platform](internal-devops-platform/README.md) | Provisions runners, shares CI templates and monitors several projects' execution infrastructure. | Docker, Kubernetes, Terraform, Ansible, GitLab runners, Bash, Prometheus, Grafana |

`devops-operations-lab` was previously named `project 1`; `orderflow` was previously named `project 2`. The existing `bash-scripte` directory remains a separate utility collection and is not counted above. Descriptive names avoid conflicting project numbers.

The five added platforms have distinct operating workflows. SaaS manages environment promotion, while Release Switchboard handles blue/green traffic switching. HA Microservices exercises distributed service failures, while OrderFlow focuses on queued work. Disaster Recovery adds isolated restore verification and measured failover beyond a basic backup script. Preview Environments owns temporary MR resources. Internal DevOps Platform operates the runners themselves. Shared tools do not make these the same project.

Start with the README inside a project and run commands from that project's root. Each can be used independently. To enable its CI configuration, use that folder's contents as the root of a separate repository; nested GitHub/GitLab workflow files are not discovered automatically from this collection's root.

Local ports are 8080 for the first lab, 8082 for OrderFlow, 8083 for Release Switchboard, 8084 for Uptime Watch and 8085 for Log Pipeline. Cloud provisioning is optional and creates billable resources only when you apply Terraform. No cloud deployment or remote CI execution is implied by the presence of configuration files.

The added platforms use application ports 8090–8092 (SaaS), 8093 (microservices), 8094 (recovery), 8095 (previews) and 8096 (CI telemetry). Their Prometheus ports are 9091–9095 and Grafana ports 3010–3014 respectively. Run labs individually if an older project already uses a monitoring port. Bash instructions assume Linux/WSL2 and run from the chosen project's root.

Each project's VALIDATION.md distinguishes completed local checks from runtime checks that still require Docker, a cluster or external credentials.
