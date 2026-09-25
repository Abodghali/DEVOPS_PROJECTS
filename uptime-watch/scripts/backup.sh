#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
umask 077
docker compose exec -T monitor python -c "import sqlite3; a=sqlite3.connect('/data/checks.db'); b=sqlite3.connect('/data/snapshot.db'); a.backup(b); b.close(); a.close()"
file="backups/checks-$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM.db"
docker compose cp monitor:/data/snapshot.db "$file"
echo "$file"
