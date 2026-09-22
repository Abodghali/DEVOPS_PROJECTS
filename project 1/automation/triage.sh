#!/usr/bin/env bash
set -euo pipefail
printf '\nUTC time\n'
date -u
printf '\nUptime and load\n'
uptime
printf '\nMemory\n'
free -h
printf '\nFilesystem usage\n'
df -h
printf '\nListening TCP sockets\n'
ss -lnt
printf '\nFailed services\n'
systemctl --failed --no-pager
