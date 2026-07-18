#!/usr/bin/env bash
# Run a long CI command with START/HEARTBEAT/PASS/FAIL logs.
#
# Intentionally simple: foreground execution only. Earlier versions used
# setsid/process groups for cancellation cleanup; that failed on the Forgejo
# runner ~1m after Flutter setup (quality red with no product steps). Prefer
# a portable wrapper that cannot exit before the wrapped command runs.
set -Eeuo pipefail

usage() {
  echo "usage: $0 <label> <heartbeat-seconds> -- <command> [args...]" >&2
  exit 64
}

[[ $# -ge 4 ]] || usage

label=$1
heartbeat_seconds=$2
shift 2
[[ ${1:-} == "--" ]] || usage
shift
[[ $# -gt 0 ]] || usage
[[ $heartbeat_seconds =~ ^[1-9][0-9]*$ ]] || usage

timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

started_at=$SECONDS
heartbeat_pid=''

cleanup() {
  if [[ -n ${heartbeat_pid:-} ]]; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
    heartbeat_pid=''
  fi
}

trap cleanup EXIT

printf '[%s] START %s\n' "$(timestamp)" "$label"
printf '[%s] COMMAND' "$(timestamp)"
printf ' %q' "$@"
printf '\n'

(
  while true; do
    sleep "$heartbeat_seconds"
    printf '[%s] HEARTBEAT %s elapsed=%ss\n' \
      "$(timestamp)" "$label" "$((SECONDS - started_at))"
  done
) &
heartbeat_pid=$!

set +e
"$@"
status=$?
set -e

cleanup
trap - EXIT

if [[ $status -eq 0 ]]; then
  printf '[%s] PASS %s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$((SECONDS - started_at))"
else
  printf '[%s] FAIL %s exit=%s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$status" "$((SECONDS - started_at))" >&2
fi

exit "$status"
