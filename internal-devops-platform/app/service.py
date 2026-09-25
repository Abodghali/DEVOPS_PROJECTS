"""Read-only GitLab pipeline and runner telemetry."""
import datetime
import json
import os
import threading
import time
import urllib.request
from pathlib import Path
from prometheus_client import Gauge

UP = Gauge('gitlab_api_up','Whether the last API poll succeeded')
LAST = Gauge('gitlab_api_last_success_timestamp_seconds','Last successful poll')
COUNT = Gauge('gitlab_recent_pipelines','Pipeline counts in the latest 20 results',['project','status'])
QUEUE = Gauge('gitlab_oldest_pending_seconds','Age of oldest pending pipeline in latest 20',['project'])
DURATION = Gauge('gitlab_recent_duration_seconds','Mean duration of sampled completed pipelines',['project'])
RUNNER = Gauge('gitlab_runner_online','Runner API status online',['project','runner'])
SUMMARY = {}
LOCK = threading.Lock()

def token():
    path = os.getenv('GITLAB_TOKEN_FILE')
    return Path(path).read_text().strip() if path else os.getenv('GITLAB_TOKEN','')

def api(path):
    request = urllib.request.Request(os.environ['GITLAB_URL'].rstrip('/')+'/api/v4/'+path,headers={'PRIVATE-TOKEN':token()})
    with urllib.request.urlopen(request, timeout=5) as response: return json.load(response)

def summarize(rows, now):
    counts = {}
    pending = []
    for row in rows:
        status = row['status']
        counts[status] = counts.get(status,0)+1
        if status == 'pending':
            created = datetime.datetime.fromisoformat(row['created_at'].replace('Z','+00:00')).timestamp()
            pending.append(max(0,now-created))
    return {'counts':counts,'oldest_pending_seconds':max(pending,default=0)}

def poll_once():
    values = {}
    for project in os.getenv('GITLAB_PROJECT_IDS','1').split(','):
        if not project.isdigit(): raise ValueError('Project IDs must be numeric')
        rows = api(f'projects/{project}/pipelines?per_page=20')
        result = summarize(rows,time.time())
        for status in ('success','failed','pending','running','canceled','skipped','manual','created','waiting_for_resource','preparing','scheduled'):
            COUNT.labels(project,status).set(result['counts'].get(status,0))
        QUEUE.labels(project).set(result['oldest_pending_seconds'])
        finished = [r for r in rows if r['status'] in ('success','failed')][:5]
        durations = [api(f"projects/{project}/pipelines/{r['id']}").get('duration') for r in finished]
        durations = [d for d in durations if d is not None]
        DURATION.labels(project).set(sum(durations)/len(durations) if durations else 0)
        runners = api(f'projects/{project}/runners')
        for runner in runners: RUNNER.labels(project,str(runner['id'])).set(int(runner.get('status')=='online'))
        values[project]=result
    with LOCK:
        SUMMARY.clear()
        SUMMARY.update(values)
    UP.set(1)
    LAST.set(time.time())

def loop():
    while True:
        try: poll_once()
        except Exception: UP.set(0)
        time.sleep(30)

def start():
    threading.Thread(target=loop,daemon=True).start()

def ready(): return bool(token())

def handle(method,path,data,headers):
    if path == '/summary':
        with LOCK: return 200, dict(SUMMARY)
    return 404, {'error':'not found'}
