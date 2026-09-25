# Validation record

Checked on 2026-09-25. These results describe checks actually performed, not a claim that a cloud deployment is running.

## Passed

- 5 Python unit/HTTP tests using Python 3.12. Container and CI images target Python 3.13.
- Python syntax, YAML/JSON parsing and Bash syntax for this project's source files.
- `docker compose --env-file .env.example -f compose.yaml config --quiet`.
- Terraform HCL parsing and `terraform fmt -check -recursive` (Terraform 1.14.4).
- Strict Kubernetes 1.34 schema validation for 28 core resources, including rendered placeholders where applicable.
- 3 custom resource manifests checked against the schemas from the pinned monitoring/database charts. This does not evaluate admission CEL or reconcile controllers.

The pinned Traefik 37.1.1, CloudNativePG 0.24.0, metrics-server 3.12.2, kube-prometheus-stack 75.15.1, GitLab Runner 0.82.0 and Cilium 1.18.1 charts all rendered locally with Helm 3.19.0. Each project uses the subset documented in its setup scripts.

## Blocked or not executed

- Docker image builds, Compose smoke tests and runtime integration: Docker Desktop's Linux engine pipe was unavailable. Starting the installed Ubuntu WSL distribution failed with `HCS_E_HYPERV_NOT_INSTALLED`; its diagnostic reported unavailable virtualization/Virtual Machine Platform support. No machine features were changed.
- Ansible syntax-check/provisioning: no usable Linux control environment in this session. YAML parsing passed; it is not equivalent to an Ansible syntax check.
- Terraform provider validation: AWS provider 6.66.0 downloaded successfully, but its local plugin TLS handshake failed with `x509: certificate signed by unknown authority`. Terraform 1.11.4 and 1.14.4 both encountered the issue. The shared module has not passed provider-schema validation; run the CI validation job or validate on a working host before applying.
- No Terraform plan/apply, AWS deployment, GitLab remote pipeline, vulnerability scan, Kubernetes server-side admission test or cluster incident/recovery drill was run.

## Reproduce on a working Linux host

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt PyYAML==6.0.2
python -m unittest discover -s tests -v
for script in scripts/*.sh; do bash -n "$script" || exit 1; done
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
ansible-playbook -i ansible/inventory.ini.example ansible/playbook.yml --syntax-check
bash scripts/local.sh
```

Then follow the infrastructure and operations guides on a dedicated cluster. Record rollout, smoke and incident results separately. Keep actual credentials, infrastructure state and backup data outside Git.
