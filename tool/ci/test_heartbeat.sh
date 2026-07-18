#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Success path
bash "$script_dir/run_with_heartbeat.sh" success-smoke 1 -- \
  bash -c 'sleep 2'

# Failure path preserves exit code
status=0
bash "$script_dir/run_with_heartbeat.sh" failure-smoke 1 -- \
  bash -c 'sleep 1; exit 7' || status=$?
[[ $status -eq 7 ]]

# Heartbeat lines appear for long enough commands
log=$(bash "$script_dir/run_with_heartbeat.sh" heartbeat-lines 1 -- \
  bash -c 'sleep 2.5' 2>&1)
printf '%s\n' "$log"
printf '%s\n' "$log" | grep -q 'START heartbeat-lines'
printf '%s\n' "$log" | grep -q 'HEARTBEAT heartbeat-lines'
printf '%s\n' "$log" | grep -q 'PASS heartbeat-lines'

echo 'heartbeat success, failure, and log smokes: PASS'
