#!/usr/bin/env bash
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
child_pid=''
child_pgid=''
heartbeat_pid=''

child_is_alive() {
  if [[ -n $child_pgid ]]; then
    kill -0 -- "-$child_pgid" 2>/dev/null
  else
    kill -0 "$child_pid" 2>/dev/null
  fi
}

signal_child() {
  local signal=$1
  if [[ -n $child_pgid ]]; then
    kill -"$signal" -- "-$child_pgid" 2>/dev/null || true
  else
    kill -"$signal" "$child_pid" 2>/dev/null || true
  fi
}

terminate_child() {
  [[ -n $child_pid ]] || return 0
  signal_child TERM
  for _ in $(seq 1 20); do
    child_is_alive || break
    sleep 0.25
  done
  if child_is_alive; then
    printf '[%s] KILL %s after 5s cancellation grace\n' \
      "$(timestamp)" "$label" >&2
    signal_child KILL
  fi
  wait "$child_pid" 2>/dev/null || true
  child_pid=''
  child_pgid=''
}

cleanup() {
  if [[ -n $heartbeat_pid ]]; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
  fi
  if [[ -n $child_pid ]]; then
    terminate_child
  fi
}

on_signal() {
  local signal=$1
  printf '[%s] CANCEL %s signal=%s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$signal" "$((SECONDS - started_at))" >&2
  exit 130
}

trap cleanup EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

printf '[%s] START %s\n' "$(timestamp)" "$label"
printf '[%s] COMMAND' "$(timestamp)"
printf ' %q' "$@"
printf '\n'

if command -v setsid >/dev/null 2>&1; then
  # A dedicated session lets cancellation terminate Flutter/Gradle/Java
  # descendants, not merely the immediate wrapper process.
  setsid --wait "$@" &
  child_pid=$!
  child_pgid=$child_pid
else
  printf '[%s] WARN process-group isolation unavailable; using child PID\n' \
    "$(timestamp)" >&2
  "$@" &
  child_pid=$!
fi

(
  while kill -0 "$child_pid" 2>/dev/null; do
    sleep "$heartbeat_seconds"
    if kill -0 "$child_pid" 2>/dev/null; then
      printf '[%s] HEARTBEAT %s elapsed=%ss\n' \
        "$(timestamp)" "$label" "$((SECONDS - started_at))"
    fi
  done
) &
heartbeat_pid=$!

if wait "$child_pid"; then
  status=0
else
  status=$?
fi
child_pid=''
child_pgid=''

kill "$heartbeat_pid" 2>/dev/null || true
wait "$heartbeat_pid" 2>/dev/null || true
heartbeat_pid=''

if [[ $status -eq 0 ]]; then
  printf '[%s] PASS %s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$((SECONDS - started_at))"
else
  printf '[%s] FAIL %s exit=%s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$status" "$((SECONDS - started_at))" >&2
fi

exit "$status"
