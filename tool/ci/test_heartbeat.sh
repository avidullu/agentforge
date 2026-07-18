#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $(uname -s) == Linux ]] || {
  echo 'heartbeat functional smoke requires Linux process semantics' >&2
  exit 69
}
real_setsid=$(command -v setsid || true)
[[ -n $real_setsid ]] || {
  echo 'heartbeat functional smoke requires setsid' >&2
  exit 69
}
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

process_is_live() {
  local pid=$1 stat_line remainder state
  if [[ -r /proc/$pid/stat ]]; then
    IFS= read -r stat_line <"/proc/$pid/stat" || return 1
    remainder=${stat_line##*) }
    state=${remainder%% *}
    [[ $state != Z && $state != X ]]
  else
    kill -0 "$pid" 2>/dev/null
  fi
}

process_group_is_live() {
  local pgid=$1 states state
  if states=$(ps -o stat= --pgid "$pgid" 2>/dev/null); then
    while IFS= read -r state; do
      state=${state#"${state%%[![:space:]]*}"}
      [[ -z $state || ${state:0:1} == Z || ${state:0:1} == X ]] && continue
      return 0
    done <<<"$states"
  fi
  return 1
}

# The wrapper must fail closed before starting a command if process-group
# isolation is unavailable.
mkdir "$temp_dir/no-setsid"
status=0
PATH="$temp_dir/no-setsid" /bin/bash \
  "$script_dir/run_with_heartbeat.sh" missing-setsid 1 -- true \
  >"$temp_dir/missing-setsid.log" 2>&1 || status=$?
[[ $status -eq 69 ]]
grep -Fq 'ERROR process-group isolation requires setsid' \
  "$temp_dir/missing-setsid.log"

# Force util-linux setsid to fork, then delay the inner PGID handshake. This
# reproduces cancellation after the supervisor starts but before the real
# session leader is known.
fake_bin=$temp_dir/fake-bin
mkdir "$fake_bin"
cat >"$fake_bin/setsid" <<'FAKE_SETSID'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${1:-} == --wait ]]
shift
printf 'started\n' >"$AGENTFORGE_FAKE_SETSID_STARTED"
exec "$AGENTFORGE_REAL_SETSID" --fork --wait bash -c '
  delay=$1
  shift
  sleep "$delay"
  exec "$@"
' _ "$AGENTFORGE_FAKE_SETSID_DELAY" "$@"
FAKE_SETSID
chmod +x "$fake_bin/setsid"

PATH="$fake_bin:$PATH" \
  AGENTFORGE_REAL_SETSID="$real_setsid" \
  AGENTFORGE_FAKE_SETSID_STARTED="$temp_dir/fake-setsid.started" \
  AGENTFORGE_FAKE_SETSID_DELAY='0.75' \
  bash "$script_dir/run_with_heartbeat.sh" immediate-cancel 1 -- \
  bash -c 'sleep 60' >"$temp_dir/immediate-cancel.log" 2>&1 &
immediate_wrapper_pid=$!
for _ in $(seq 1 100); do
  [[ -s $temp_dir/fake-setsid.started ]] && break
  sleep 0.01
done
[[ -s $temp_dir/fake-setsid.started ]]
kill -TERM "$immediate_wrapper_pid"
status=0
wait "$immediate_wrapper_pid" || status=$?
cat "$temp_dir/immediate-cancel.log"
[[ $status -eq 130 ]]
immediate_pgid=$(sed -n \
  's/.*SESSION immediate-cancel pgid=\([1-9][0-9]*\)$/\1/p' \
  "$temp_dir/immediate-cancel.log" | tail -n 1)
[[ $immediate_pgid =~ ^[1-9][0-9]*$ ]]
for _ in $(seq 1 20); do
  process_group_is_live "$immediate_pgid" || break
  sleep 0.1
done
if process_group_is_live "$immediate_pgid"; then
  ps -o pid=,ppid=,pgid=,stat=,comm= --pgid "$immediate_pgid" \
    2>/dev/null || true
  echo 'immediate cancellation left a process group running' >&2
  exit 1
fi

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
for _ in $(seq 1 20); do
  if ! process_is_live "$child_pid" && ! process_is_live "$grandchild_pid"; then
    break
  fi
  sleep 0.1
done
if process_is_live "$child_pid" || process_is_live "$grandchild_pid"; then
  ps -o pid=,ppid=,pgid=,stat=,comm= -p \
    "$child_pid,$grandchild_pid" 2>/dev/null || true
  echo 'heartbeat cancellation left a descendant running' >&2
  exit 1
fi

bash "$script_dir/run_with_heartbeat.sh" success-smoke 1 -- \
  bash -c 'sleep 2'

status=0
bash "$script_dir/run_with_heartbeat.sh" failure-smoke 1 -- \
  bash -c 'sleep 1; exit 7' || status=$?
[[ $status -eq 7 ]]

echo 'heartbeat startup-cancel, process-group, success, and failure smokes: PASS'
