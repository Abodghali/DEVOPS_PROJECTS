#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${S3_BUCKET:?}"
[[ $# == 1 && "$1" =~ ^dr/[0-9]{8}T[0-9]{6}Z-[0-9]+\.dump$ ]] || { echo 'Pass a generated dr/TIMESTAMP-NUMBER.dump object key.' >&2; exit 2; }
umask 077
mkdir -p backups
file="backups/$(basename "$1")"
for suffix in '' .sha256 .json; do
  aws s3 cp "s3://$S3_BUCKET/$1$suffix" "$file$suffix" --only-show-errors
done
echo "$file"
