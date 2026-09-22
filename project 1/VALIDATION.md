# Local validation

Checked on 2026-09-08 on Windows.

| Check | Result |
| --- | --- |
| Python API behavior tests | PASS: 4 tests; health/readiness, service identity, increasing metrics, HTTP 404 |
| Docker Compose configuration | PASS: exit 0 |
| Monitoring Compose configuration | PASS: exit 0 |
| Bash script syntax | PASS |
| Backup and recovery | PASS: file round trip, refusal to overwrite existing directory, rejection of corrupt archive |
| Docker image build and container runtime | Retry blocked: Docker Desktop Linux engine pipe is unavailable, including outside the sandbox |
| Kubernetes rendering | PASS on retry: kubectl kustomize rendered Namespace, Service, Deployment and PodDisruptionBudget outside the sandbox |
| Kubernetes deployment | Not run: kubeconfig has no contexts and Docker runtime is unavailable |
| Terraform format/provider validation | Not run: terraform is not on the Windows PATH; WSL cannot start |
| Ansible syntax/VM execution | Not run: ansible-playbook is not on the Windows PATH; WSL cannot start |
| Prometheus rule execution | Not run: Docker engine is not running |
| GitHub Actions | Workflow supplied; no remote run performed |

Compose emitted a warning that the local Docker user configuration was inaccessible, but both configuration checks returned exit 0. Python tests used the bundled Python runtime. Bash recovery tests used Git Bash with its GNU utilities on PATH.

The CI workflow covers additional validation when run on GitHub. A passing configuration check does not establish successful infrastructure deployment. Follow each project's README to perform the runtime exercises and record the actual results.

## Retry after user started tools

On 2026-09-08, the four API tests, both Compose configuration checks and the backup recovery/protection checks passed again. Kubernetes rendering also passed after running outside the filesystem sandbox.

Docker's selected context is `desktop-linux`, but its `dockerDesktopLinuxEngine` named pipe is unavailable. An attempt to start Docker Desktop did not produce a working engine. Starting Ubuntu through WSL returned `Wsl/Service/CreateInstance/CreateVm/HCS/HCS_E_HYPERV_NOT_INSTALLED`, with instructions to enable Virtual Machine Platform and check firmware virtualization. This prevents testing the Linux runtime. No Windows features or firmware settings were changed, and no reboot was initiated.

Recovery guidance: [Microsoft WSL troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting). Verify Virtual Machine Platform and firmware virtualization, restart Windows if required, then confirm `wsl -d Ubuntu -- uname -a` and `docker info` succeed before rerunning container tests.
