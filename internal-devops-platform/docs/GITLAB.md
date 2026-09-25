# GitLab setup

Use this folder as its own GitLab repository root and enable the container registry. Nested CI files are not automatically discovered from the collection root.

Build jobs require a Docker executor tagged `docker-build`, privileged DinD with TLS, and the `/certs/client` volume configured by Ansible. Restrict it to trusted projects. Deployment jobs use a separate Linux shell executor with Bash, Python 3, PyYAML, kubectl and cluster connectivity. A shell executor does not install tools from the job image.

Set `KUBE_CONFIG` as a GitLab **File** variable containing the deployment identity's kubeconfig, and `KUBE_CONTEXT` to its exact context. Use short-lived credentials through a credential broker or renew them before expiry. Keep credentials out of the repository and logs. Protect the default branch and deployment environments. The bootstrap administrator identity is not a release credential.

The pipeline tests code and Bash syntax, validates Terraform/Ansible, runs Compose smoke checks, pushes SHA-tagged images and blocks deployment on HIGH/CRITICAL scan findings. Upgrade vulnerable dependencies and rebuild to pass the gate. No AWS apply runs in CI. Kubernetes needs durable `read_registry` credentials provisioned before rollout; a publishing job password expires and is unsuitable as a cluster pull secret.

## Shared templates

`ci/templates/python.yml` provides `.python-unit`; `ci/templates/docker.yml` provides `.docker-publish` and `.container-scan`. Copy `ci/consumer-example.yml` into another project, replace its include project path and pin the ref to a reviewed release tag. Consumers provide a Dockerfile, requirements and tests. Pinning avoids silently changing every consumer when the platform changes.

Platform deployment uses `platform-deploy`. Set `GITLAB_URL` and comma-separated numeric `GITLAB_PROJECT_IDS`. Bootstrap the API token as a Kubernetes secret separately; deployment CI does not need that token itself.

## Kubernetes runner

Create a runner in GitLab with tag `k8s-build`, restrict it to trusted projects, install monitoring, then:

```bash
read -rsp 'Runner authentication token: ' RUNNER_AUTH_TOKEN; echo
export RUNNER_AUTH_TOKEN
bash scripts/runner-kubernetes.sh
unset RUNNER_AUTH_TOKEN
```

The chart uses an existing Secret, namespace RBAC, four concurrent jobs and a non-privileged Kubernetes executor. DinD templates require the separate `docker-build` executor; changing tags does not make privileged DinD compatible with this runner.

## Build workload

`kubernetes/build-job.yaml` runs rootless BuildKit and writes an OCI archive to a PVC. It needs a kernel permitting unprivileged user namespaces. Unconfined seccomp/AppArmor and disabled process sandboxing are explicit tradeoffs for this dedicated, trusted build lab; do not run it alongside sensitive workloads.

```bash
kubectl --context "$KUBE_CONTEXT" apply -f kubernetes/build-job.yaml
kubectl --context "$KUBE_CONTEXT" -n build-lab wait --for=condition=complete job/build-image --timeout=320s
kubectl --context "$KUBE_CONTEXT" -n build-lab logs job/build-image
```

The archive is `/output/image.tar` on `build-output`; it is not pushed to a registry. Inspect a failed Job before deleting/recreating only `job/build-image`; its PVC remains.

Set `RUNNER_PRIVATE_IP` to the Terraform output and run `scripts/add-runner-metrics.sh` after namespace setup. It connects monitoring to node exporter 9100 and runner exporter 9252. Update these manually maintained endpoints after replacing a runner host.
