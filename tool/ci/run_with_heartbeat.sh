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
child_pgid_file=''
heartbeat_pid=''
pending_signal=''

command -v setsid >/dev/null 2>&1 || {
  echo 'ERROR process-group isolation requires setsid' >&2
  exit 69
}

read_child_pgid() {
  local candidate
  [[ -n $child_pgid ]] && return 0
  [[ -n $child_pgid_file && -r $child_pgid_file ]] || return 1
  IFS= read -r candidate <"$child_pgid_file" || return 1
  [[ $candidate =~ ^[1-9][0-9]*$ ]] || return 1
  child_pgid=$candidate
  printf '[%s] SESSION %s pgid=%s\n' \
    "$(timestamp)" "$label" "$child_pgid"
}

await_child_pgid() {
  local attempts=${1:-100}
  for _ in $(seq 1 "$attempts"); do
    read_child_pgid && return 0
    [[ -n $child_pid ]] || return 1
    if ! kill -0 "$child_pid" 2>/dev/null; then
      read_child_pgid
      return $?
    fi
    sleep 0.05
  done
  read_child_pgid
}

child_is_alive() {
  if [[ -n $child_pgid ]]; then
    local states state
    # Container PID 1 implementations do not always reap an orphaned zombie
    # promptly. A zombie cannot execute or retain resources other than its
    # process-table entry, so do not mistake it for a live command and spin
    # through the entire cancellation grace period.
    if states=$(ps -o stat= --pgid "$child_pgid" 2>/dev/null); then
      while IFS= read -r state; do
        state=${state#"${state%%[![:space:]]*}"}
        [[ -z $state || ${state:0:1} == Z || ${state:0:1} == X ]] && continue
        return 0
      done <<<"$states"
      return 1
    fi
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
  if [[ -z $child_pgid ]] && ! await_child_pgid 100; then
    printf '[%s] ERROR unable to establish command process group during cleanup\n' \
      "$(timestamp)" >&2
  fi
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
  if [[ -n $child_pgid_file ]]; then
    rm -f -- "$child_pgid_file"
  fi
}

on_signal() {
  local signal=$1
  printf '[%s] CANCEL %s signal=%s elapsed=%ss\n' \
    "$(timestamp)" "$label" "$signal" "$((SECONDS - started_at))" >&2
  exit 130
}

defer_signal() {
  pending_signal=$1
}

trap cleanup EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

printf '[%s] START %s\n' "$(timestamp)" "$label"
printf '[%s] COMMAND' "$(timestamp)"
printf ' %q' "$@"
printf '\n'

# A dedicated session lets cancellation terminate Flutter/Gradle/Java
# descendants, not merely the immediate wrapper process. `setsid --wait` may
# fork when its caller is already a process-group leader, so `$!` is not a
# portable PGID. Record the real session leader from inside the session.
pgid_temp_root=${RUNNER_TEMP:-${TMPDIR:-/tmp}}
[[ -d $pgid_temp_root ]] || {
  printf '[%s] ERROR heartbeat temp directory is unavailable\n' \
    "$(timestamp)" >&2
  exit 1
}
child_pgid_file=$(mktemp "$pgid_temp_root/agentforge-pgid.XXXXXX")
chmod 600 "$child_pgid_file"

# Defer signals across the narrow spawn/$! assignment window. Without this,
# a cancellation can arrive after `setsid` starts but before child_pid is set,
# leaving cleanup with no process to terminate.
trap 'defer_signal INT' INT
trap 'defer_signal TERM' TERM
setsid --wait bash -c '
  set -Eeuo pipefail
  pgid_file=$1
  shift
  printf "%s\n" "$$" >"$pgid_file"
  exec "$@"
' _ "$child_pgid_file" "$@" &
child_pid=$!
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
if [[ -n $pending_signal ]]; then
  on_signal "$pending_signal"
fi

await_child_pgid 100 || {
  printf '[%s] ERROR unable to establish command process group\n' \
    "$(timestamp)" >&2
  exit 1
}
rm -f -- "$child_pgid_file"
child_pgid_file=''

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
