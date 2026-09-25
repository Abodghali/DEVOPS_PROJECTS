#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
[[ "${CONFIRM_DISASTER:-}" == dr-lab ]] || { echo 'Set CONFIRM_DISASTER=dr-lab to erase the lab primary notes table.' >&2; exit 2; }
[[ "$(active_slot)" == primary ]] || exit 2
marker="drill-$(date +%s)-$RANDOM"
"${k[@]}" exec primary-0 -- psql -U app -d app -v ON_ERROR_STOP=1 -c "INSERT INTO notes(body) VALUES ('$marker-before');" >/dev/null
file=$(bash scripts/backup.sh)
bash scripts/verify-backup.sh "$file"
"${k[@]}" exec primary-0 -- psql -U app -d app -v ON_ERROR_STOP=1 -c "INSERT INTO notes(body) VALUES ('$marker-after');" >/dev/null
started=$(python3 -c 'import time;print(time.time())')
"${k[@]}" exec primary-0 -- psql -U app -d app -v ON_ERROR_STOP=1 -c 'TRUNCATE notes;' >/dev/null
CONFIRM_RESTORE=dr-lab/recovery bash scripts/restore.sh "$file"
CONFIRM_FAILOVER=dr-lab/recovery bash scripts/failover.sh
before=$("${k[@]}" exec recovery-0 -- psql -U app -d app -Atc "SELECT count(*) FROM notes WHERE body='$marker-before';")
after=$("${k[@]}" exec recovery-0 -- psql -U app -d app -Atc "SELECT count(*) FROM notes WHERE body='$marker-after';")
[[ "$before" == 1 && "$after" == 0 ]] || { echo 'Recovery marker assertions failed.' >&2; exit 1; }
latest=$("${k[@]}" exec recovery-0 -- psql -U app -d app -Atc 'SELECT extract(epoch FROM max(created_at)) FROM notes;')
mkdir -p results
python3 - "$started" "$latest" <<'PY' | tee results/recovery.json
import json,sys,time
sys.path.insert(0,'app')
from recovery import measurements
start,latest=map(float,sys.argv[1:])
result=measurements(start,time.time(),latest)
result.update({'pre_backup_marker_restored':True,'post_backup_marker_lost':True})
print(json.dumps(result,indent=2))
PY
"${k[@]}" exec -i deployment/notes -- python -c "import json,sys,urllib.request; r=json.load(sys.stdin); body=('dr_last_rto_seconds '+str(r['rto_seconds'])+'\ndr_last_rpo_seconds '+str(r['rpo_seconds'])+'\n').encode(); urllib.request.urlopen(urllib.request.Request('http://pushgateway:8080/metrics/job/dr_drill',data=body,method='PUT'),timeout=5)" < results/recovery.json
