#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/common.sh
umask 077
mkdir -p backups
slot=$(active_slot)
[[ "$slot" =~ ^(primary|recovery)$ ]] || exit 2
id="$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
file="backups/$id.dump"
"${k[@]}" exec "$slot-0" -- pg_dump -U app -d app -Fc > "$file"
"${k[@]}" exec -i "$slot-0" -- pg_restore --list < "$file" >/dev/null
(cd backups && sha256sum "$id.dump" > "$id.dump.sha256")
python3 -c 'import json,time,sys;json.dump({"completed_at":time.time(),"source":sys.argv[1]},open(sys.argv[2],"w"))' "$slot" "$file.json"
if [[ -n "${S3_BUCKET:-}" ]]; then
  for suffix in '' .sha256 .json; do
    aws s3 cp "$file$suffix" "s3://$S3_BUCKET/dr/$id.dump$suffix" --only-show-errors
  done
fi
# A push failure is surfaced; a successful upload alone does not prove restoration.
"${k[@]}" exec deployment/notes -- python -c "import urllib.request,time; req=urllib.request.Request('http://pushgateway:8080/metrics/job/dr_backup',data=('dr_last_backup_timestamp_seconds '+str(time.time())+'\n').encode(),method='PUT'); urllib.request.urlopen(req,timeout=5)" >/dev/null
echo "$file"
