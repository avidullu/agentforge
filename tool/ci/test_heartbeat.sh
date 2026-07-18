#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temp_parent=$(realpath -e -- "${TMPDIR:-/tmp}")
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/agentforge-heartbeat.XXXXXX")
temp_dir=$(realpath -e -- "$temp_dir")

case "$temp_dir" in
  "$temp_parent"/agentforge-heartbeat.*) ;;
  *) echo 'unsafe heartbeat test temp path' >&2; exit 1 ;;
esac

cleanup() {
  rm -rf -- "$temp_dir"
}
trap cleanup EXIT

bash "$script_dir/run_with_heartbeat.sh" cancellation-smoke 1 -- \
  bash -c \
  'echo $$ > "$1/child.pid"; sleep 60 & echo $! > "$1/grandchild.pid"; wait' \
  _ "$temp_dir" >"$temp_dir/cancellation.log" 2>&1 &
wrapper_pid=$!

for _ in $(seq 1 20); do
  [[ -s $temp_dir/grandchild.pid ]] && break
  sleep 0.1
done
[[ -s $temp_dir/child.pid && -s $temp_dir/grandchild.pid ]]

kill -TERM "$wrapper_pid"
status=0
wait "$wrapper_pid" || status=$?
cat "$temp_dir/cancellation.log"
[[ $status -eq 130 ]]

child_pid=$(<"$temp_dir/child.pid")
grandchild_pid=$(<"$temp_dir/grandchild.pid")
sleep 1
if kill -0 "$child_pid" 2>/dev/null || kill -0 "$grandchild_pid" 2>/dev/null; then
  echo 'heartbeat cancellation left a descendant running' >&2
  exit 1
fi

bash "$script_dir/run_with_heartbeat.sh" success-smoke 1 -- \
  bash -c 'sleep 2'

status=0
bash "$script_dir/run_with_heartbeat.sh" failure-smoke 1 -- \
  bash -c 'sleep 1; exit 7' || status=$?
[[ $status -eq 7 ]]

echo 'heartbeat process-group, success, and failure smokes: PASS'
