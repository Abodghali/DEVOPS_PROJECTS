# AWS host and Ansible provisioning

This route creates a billable t3.medium EC2 instance, a 30 GiB EBS volume and a public IPv4 address. It is optional; no cloud resources are required for Compose. No resources have been provisioned as part of generating the project.

Requirements: Terraform 1.6+, AWS CLI credentials, an existing SSH key pair, Ansible on Linux/WSL. Verify the intended AWS account with `aws sts get-caller-identity`.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Enter your public SSH key and current public IPv4 address with /32.
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=lab.tfplan
# Review cost, account and plan before provisioning:
terraform -chdir=terraform apply lab.tfplan
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory.ini
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --syntax-check
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Verify the SSH host fingerprint before first login. Keep host key checking enabled. Run Ansible again to assess idempotency. The installer runs only when K3s is absent; changing `k3s_version` does not upgrade an existing server automatically. The version is a lab baseline, not a claim that it is the newest release. The official installer is downloaded over HTTPS and runs as root; review it for a production provisioning process.

The VPC range is 10.42.0.0/16; K3s pod/service ranges are explicitly set to 10.52.0.0/16 and 10.53.0.0/16 to avoid overlap. Only SSH from your /32 is allowed inbound; port 6443 and application ports are not public.

## Access the cluster through SSH

```bash
ip=$(terraform -chdir=terraform output -raw public_ip)
mkdir -p .secrets
umask 077
ssh "ubuntu@$ip" 'sudo cat /etc/rancher/k3s/k3s.yaml' > .secrets/kubeconfig
export KUBECONFIG="$PWD/.secrets/kubeconfig"
# Keep this running in another terminal:
ssh -N -L 6443:127.0.0.1:6443 "ubuntu@$ip"
```

K3s's generated kubeconfig points to `127.0.0.1:6443`, which now reaches the server through the tunnel. That file grants cluster administration; keep it private. Verify with `kubectl get nodes`, set `KUBE_CONTEXT=default`, and follow the Kubernetes bootstrap/registry/deployment steps. Use `kubectl port-forward` for application access.

## State and cleanup

Keep Terraform state private and commit the generated provider lockfile. This lab uses local state; a shared team needs a protected remote backend with locking. Ubuntu AMI selection uses the most recent matching official image, so review subsequent plans for instance replacement.

Back up PostgreSQL before destroying the host. Review `terraform -chdir=terraform plan -destroy`, then use `terraform -chdir=terraform destroy` when you intend to delete the lab, including its EBS-backed application data.
