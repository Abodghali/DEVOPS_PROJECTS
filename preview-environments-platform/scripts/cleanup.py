"""Reconcile owned namespaces against MR status and a one-day expiry."""
import datetime
import json
import os
import subprocess
import urllib.request
from render import namespace, owned

cmd=['kubectl','--context',os.environ['KUBE_CONTEXT']]
project=os.environ['CI_PROJECT_ID']
namespace(project,'1')
items=json.loads(subprocess.check_output(cmd+['get','namespaces','-l',f'preview-owner=gitlab,gitlab-project={project}','-o','json']))['items']
for item in items:
    meta=item['metadata']; mr=meta.get('labels',{}).get('gitlab-mr','')
    if not owned(meta['name'],meta.get('labels',{}),project,mr): raise RuntimeError('Unexpected namespace ownership')
    url=os.environ['CI_API_V4_URL']+f'/projects/{project}/merge_requests/{mr}'
    request=urllib.request.Request(url,headers={'PRIVATE-TOKEN':os.environ['GITLAB_READ_TOKEN']})
    with urllib.request.urlopen(request,timeout=10) as result: state=json.load(result)['state']
    expired=datetime.datetime.now(datetime.timezone.utc)>datetime.datetime.fromisoformat(meta['annotations']['expires-at'])
    if state in ('closed','merged') or expired:
        print('Cleanup candidate:',meta['name'],state,'expired=',expired)
        if os.getenv('APPLY_CLEANUP')=='yes': subprocess.run(cmd+['delete','namespace',meta['name'],'--wait=false'],check=True)
