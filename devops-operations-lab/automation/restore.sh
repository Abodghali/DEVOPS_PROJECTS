#!/usr/bin/env bash
set -euo pipefail
umask 077
if [[ $# != 2 ]]; then
  echo "Usage: bash restore.sh TRUSTED_ARCHIVE NEW_DESTINATION" >&2; exit 2
fi
archive=$(realpath "$1")
if [[ -e "$2" ]]; then echo "Destination must not exist" >&2; exit 2; fi
(cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")
mkdir -- "$2"
tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$2"
echo "Restored into $2"
