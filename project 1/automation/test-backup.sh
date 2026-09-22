#!/usr/bin/env bash
set -euo pipefail
temp=$(mktemp -d)
mkdir "$temp/source"
printf 'recovery-test\n' > "$temp/source/sample.txt"
archive=$(bash automation/backup.sh "$temp/source" "$temp/backups")
bash automation/restore.sh "$archive" "$temp/restored"
diff -r "$temp/source" "$temp/restored"
if bash automation/restore.sh "$archive" "$temp/restored"; then
  echo "ERROR: restore overwrote an existing directory" >&2; exit 1
fi
printf 'corruption' >> "$archive"
if bash automation/restore.sh "$archive" "$temp/corrupt-restored"; then
  echo "ERROR: restore accepted a corrupt archive" >&2; exit 1
fi
test ! -e "$temp/corrupt-restored"
echo "PASS: round trip, overwrite protection and corruption rejection"
