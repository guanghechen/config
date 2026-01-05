#!/usr/bin/env bash

# Usage: duration.sh <session_created_timestamp>
# Output: formatted duration like "1d 4h 43m", "4h 43m", or "43m"

session_created=$1
now=$(date +%s)
s=$((now - session_created))

d=$((s / 86400))
h=$(((s % 86400) / 3600))
m=$(((s % 3600) / 60))

if [ "$d" -gt 0 ]; then
  printf '%dd %dh %02dm' "$d" "$h" "$m"
elif [ "$h" -gt 0 ]; then
  printf '%dh %02dm' "$h" "$m"
else
  printf '%dm' "$m"
fi
