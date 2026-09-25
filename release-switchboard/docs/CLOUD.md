# AWS and Ansible setup

This optional route provisions a dedicated Ubuntu EC2 host for `release-switchboard`. Local Docker and kind runs do not need AWS. Terraform creates a VPC, a public subnet, an SSH-only security group, a t3.medium instance and an encrypted 30 GiB disk. Compute, storage and public IPv4 usage incur charges.

## Provision

Install Terraform 1.6+, AWS CLI and Ansible on a Linux/WSL control machine. Authenticate with an AWS profile or SSO and check `aws sts get-caller-identity`. From this project's root:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Enter your public SSH key and your public IPv4 address followed by /32.
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=lab.tfplan
# Apply only after reviewing account, resources and cost.
terraform -chdir=terraform apply lab.tfplan
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory.ini
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --syntax-check
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Verify the server's SSH fingerprint before first login. The playbook installs K3s, disables public ingress components and keeps the kubeconfig private. It uses non-overlapping pod and service CIDRs. Run it again to check idempotency. K3s installation is first-run only; changing the version variable does not upgrade an existing cluster. Review the downloaded official installer before using this provisioning pattern outside the lab.

## Cluster access

```bash
ip=$(terraform -chdir=terraform output -raw public_ip)
mkdir -p .secrets
umask 077
ssh "ubuntu@$ip" 'sudo cat /etc/rancher/k3s/k3s.yaml' > .secrets/kubeconfig
export KUBECONFIG="$PWD/.secrets/kubeconfig"
export KUBE_CONTEXT=default
# Keep the tunnel open in another terminal:
ssh -N -L 6443:127.0.0.1:6443 "ubuntu@$ip"
```

Check `kubectl --context "$KUBE_CONTEXT" get nodes`, then follow the project's Kubernetes instructions using an image pushed to a reachable registry. A kind-loaded image on your laptop is not available on EC2. Registry credentials are described in [the CI guide](CI.md).

The generated K3s kubeconfig grants administration of this dedicated lab cluster. Do not reuse it as a general team deployment credential. Application access uses kubectl port-forward over the SSH tunnel. The AWS security group exposes neither the application nor port 6443.

## State and cleanup

Keep state, plans and private credentials out of Git. Commit `.terraform.lock.hcl` after initialization. Terraform state is local here; a team deployment needs a protected remote backend and locking. The latest matching official Ubuntu AMI is selected at plan time, so later plans can propose instance replacement.

Back up data before destroying the host. Review `terraform -chdir=terraform plan -destroy`, then run `terraform -chdir=terraform destroy` when you intend to remove the lab. Its root disk and local Kubernetes volumes are destroyed with the instance. No cloud resources are created simply by checking these files into Git.
