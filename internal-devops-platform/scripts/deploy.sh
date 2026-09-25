#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KUBE_CONTEXT:?}" "${IMAGE:?}" "${GITLAB_URL:?}" "${GITLAB_PROJECT_IDS:?}"
[[ "$IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]+$ && "$GITLAB_PROJECT_IDS" =~ ^[0-9]+(,[0-9]+)*$ ]] || exit 2
python3 - <<'PY' | kubectl --context "$KUBE_CONTEXT" apply -f -
import os,yaml
docs=list(yaml.safe_load_all(open('kubernetes/workloads.yaml')))
for d in docs:
    if d['kind']=='Deployment':
        c=d['spec']['template']['spec']['containers'][0]
        c['image']=os.environ['IMAGE']
        for env in c['env']:
            if env['name'] in ('GITLAB_URL','GITLAB_PROJECT_IDS'): env['value']=os.environ[env['name']]
print(yaml.safe_dump_all(docs,sort_keys=False))
PY
kubectl --context "$KUBE_CONTEXT" -n ci-platform rollout status deployment/telemetry --timeout=180s
