# Infrastructure and cluster setup

This project includes a reusable Terraform EKS module, remote-state bootstrap, and Ansible provisioning for a separate CI host. Cloud provisioning is optional. Local Compose runs need no AWS account. Do not apply this stack just to read or test the application code.

## What Terraform creates

The module creates a VPC across two availability zones, three managed EKS worker nodes, an EKS control plane, encrypted runner storage, a dedicated Ubuntu runner host, and EBS CSI with Pod Identity. Nodes use public subnets with outbound access to image registries to keep the lab topology understandable; production networking commonly places workers in private subnets. The cluster API accepts public traffic only from the supplied administrator /32 and also has a private endpoint.

The microservices and preview projects additionally enable a Network Load Balancer targeting Traefik's node port 30080. It is internal by default. Setting `public_ingress=true` exposes the HTTP listener; configure TLS and access controls before serving sensitive data. The managed node group's maximum size is a capacity setting, not a node autoscaler installation.

EKS, four EC2 instances, EBS volumes and optional load balancing incur charges. No resources are created until Terraform apply. Use a dedicated account or sandbox and inspect the plan first.

## Remote state

Install Terraform 1.10+, AWS CLI, kubectl and Helm. Authenticate with AWS SSO or an approved role, then confirm the account with `aws sts get-caller-identity`.

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -var='bucket_name=YOUR-UNIQUE-STATE-BUCKET' -out=bootstrap.tfplan
# Review, then apply the saved plan:
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
cp terraform/backend.hcl.example terraform/backend.hcl
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Fill in bucket, IAM principal ARN, public SSH key and operator IPv4 /32.
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan -out=cluster.tfplan
# Review, then apply:
terraform -chdir=terraform apply cluster.tfplan
```

State uses an encrypted, versioned private S3 bucket with native S3 locking (`use_lockfile=true`). The bootstrap state starts locally; retain it securely or migrate it to a separate protected backend. Commit generated provider lockfiles. Never commit state, plans, private keys or credentials. Use a distinct backend key for each independent cluster. The shared cluster for this project has one infrastructure state; Kubernetes application releases do not own the Terraform state.

The bootstrap administrator is an IAM user/role ARN, not an STS assumed-role session ARN. Application CI identities should be narrower than that bootstrap identity.

## Provision the runner host

```bash
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory.ini
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --syntax-check
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Verify the SSH fingerprint first. The playbook installs Docker, Compose, kubectl, Helm, PostgreSQL client tools, node exporter and GitLab Runner. It bounds Docker logs. To register a runner, provide `runner_auth_token` through Ansible Vault or a protected extra-vars file. The registration task suppresses its output. Create the runner in GitLab first, set tags and protected/trusted-project restrictions in the UI, then supply its authentication token. Registration preserves an existing configured runner; it is not a token-rotation mechanism.

This host's Docker executor supports TLS-enabled DinD through a shared `/certs/client` volume. Privileged builders must be dedicated to trusted code. Metrics ports 9100 and 9252 are allowed only from the VPC by Terraform. The deployment jobs expect a separate, protected Linux **shell executor** with kubectl, Helm, Python, PyYAML and an appropriate kubeconfig. Do not hand production credentials to the general build executor. Host installation does not automatically grant the runner an AWS identity or Kubernetes privileges.

## Connect and install monitoring

```bash
aws eks update-kubeconfig --name "$(terraform -chdir=terraform output -raw cluster_name)" --region eu-central-1
export KUBE_CONTEXT="$(kubectl config current-context)"
export CLUSTER_KIND=aws
export GRAFANA_PASSWORD='SET-A-PRIVATE-PASSWORD'
bash scripts/monitoring.sh
```

For local Kubernetes, create the supplied four-node kind cluster first:

```bash
kind create cluster --name YOUR-LAB-NAME --image kindest/node:v1.34.0 --config kubernetes/kind.yaml
export KUBE_CONTEXT=kind-YOUR-LAB-NAME
export CLUSTER_KIND=kind
export GRAFANA_PASSWORD='SET-A-PRIVATE-PASSWORD'
bash scripts/monitoring.sh
```

The kind configuration disables the default CNI; the monitoring setup installs Cilium first so NetworkPolicies are enforced. This needs considerably more memory than Compose; use a host with at least 16 GiB available for the full microservices lab. kind nodes share one physical host and do not demonstrate host-level high availability. On EKS, VPC CNI network policy support is enabled by Terraform. Storage on EKS uses the installed EBS driver and gp3 StorageClass; kind uses its local provisioner.

If the project has `scripts/controllers.sh`, run it next to install ingress and any database/operator or metrics-server dependencies. All chart versions are explicit lab baselines; validate compatibility and security updates before a long-lived deployment.

## Registry and cleanup

For private application images, attach a read-only registry pull secret to the namespace's default service account before rollout. Use a deploy token with `read_registry`, not a CI job password that expires. The preview project creates a per-review pull secret from `REGISTRY_CONFIG` instead. Restart an existing failed rollout after adding credentials.

Back up data before cleanup. Review Terraform's destroy plan before applying it. State buckets, and the DR backup bucket, intentionally have `prevent_destroy`; removing that guard requires a separate reviewed decision about retention. Deleting a kind cluster deletes its local volumes. This repository does not run apply, destroy, or a cloud deployment automatically.

References: [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3), [EKS EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), [GitLab runner registration](https://docs.gitlab.com/runner/register/).

After namespace bootstrap, set `NAMESPACE` to the application namespace and `REGISTRY_CONFIG` to a private Docker config JSON file made with a read-only deploy token. Run `bash scripts/registry.sh` using an administrator context before deployment. Repeat for each SaaS namespace. Keep that file outside the repository; the script does not print its content. Public images and images loaded into kind need no pull secret.

Ingress uses Traefik with the Kubernetes Ingress provider. Its [chart values](https://github.com/traefik/traefik-helm-chart/blob/v37.1.1/traefik/values.yaml) define the NodePort configuration. The community ingress-nginx controller [retired in March 2026](https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/).
