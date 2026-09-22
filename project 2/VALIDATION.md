# Validation record

Date: 2026-09-22. Environment: Windows host.

| Check | Result |
| --- | --- |
| Domain unit tests | PASS: valid order, invalid field values including booleans, non-object payload |
| Python compilation | PASS for application and test modules |
| Bash syntax | PASS for all six scripts |
| Local secret generation | PASS; values are ignored by Git and not printed |
| Docker Compose configuration | PASS |
| Kubernetes Kustomize rendering | PASS outside filesystem sandbox; 197 rendered lines |
| Docker runtime / integration / backup restore | Not executed: Docker Desktop Linux engine named pipe unavailable, including outside sandbox |
| Terraform provider validation | Not executed locally; Terraform not found on PATH |
| Ansible syntax / host provisioning | Not executed locally; ansible-playbook not found on Windows PATH |
| GitLab pipeline | Supplied, not executed on a remote runner |
| AWS deployment | Not performed |

The live smoke test covers readiness, authentication rejection, duplicate-request reuse, conflicting-request rejection and eventual order completion. CI is configured to execute it against Compose and then restore a database dump into an isolated database. These checks are not claimed as passed until executed against the running stack.
