#!/usr/bin/env bash
set -euo pipefail
umask 077
if [[ $# != 2 ]]; then
  echo "Usage: bash backup.sh SOURCE_DIRECTORY BACKUP_DIRECTORY" >&2; exit 2
fi
source_dir=$(realpath "$1")
mkdir -p -- "$2"
backup_dir=$(realpath "$2")
case "$backup_dir/" in "$source_dir/"*) echo "Backup directory must be outside source" >&2; exit 2 ;; esac
archive=$(mktemp "$backup_dir/backup-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.tar.gz")
trap 'rm -f -- "$archive" "$archive.sha256"' ERR
tar -czf "$archive" -C "$source_dir" .
(cd "$backup_dir" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
echo "$archive"
