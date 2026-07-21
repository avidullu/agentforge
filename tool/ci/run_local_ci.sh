#!/usr/bin/env bash
# AgentForge CI harness — single source of truth for product steps.
#
# Remote Forgejo CI and local debugging run THIS script so failures are
# reproducible without API job logs.
#
# Usage:
#   bash tool/ci/run_local_ci.sh --lane quality
#   bash tool/ci/run_local_ci.sh --lane quality --base-sha origin/main
#   bash tool/ci/run_local_ci.sh --lane build-smoke          # web only (PR CI)
#   bash tool/ci/run_local_ci.sh --lane android-smoke        # SDK+APK+lint (nightly)
#   bash tool/ci/run_local_ci.sh --lane all
#   bash tool/ci/run_local_ci.sh --list-steps
#
# Lanes:
#   quality       — format/analyze/test/coverage/PII/shell smokes (every PR)
#   build-smoke   — release Web only (every PR; NO Android SDK install)
#   android-smoke — install/validate SDK packages + debug APK + lint (nightly only)
#
# Defaults match .github/workflows/ci.yml env (override via environment):
#   TEST_RANDOM_SEED=424242
#   LINE_COVERAGE_FLOOR=35.5
#   DIFF_COVERAGE_FLOOR=80
#   AGENTFORGE_CONFIG=config/agentforge.config.example.json
#
# Exit non-zero on first failed step; prints STEP FAIL with the step name.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd -- "$repo_root"

TEST_RANDOM_SEED=${TEST_RANDOM_SEED:-424242}
LINE_COVERAGE_FLOOR=${LINE_COVERAGE_FLOOR:-35.5}
DIFF_COVERAGE_FLOOR=${DIFF_COVERAGE_FLOOR:-80}
export AGENTFORGE_CONFIG=${AGENTFORGE_CONFIG:-config/agentforge.config.example.json}

lane=quality
base_sha=''
list_steps=0
keep_going=0

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane)
      lane=${2:-}
      shift 2
      ;;
    --base-sha)
      base_sha=${2:-}
      shift 2
      ;;
    --skip-android)
      # Deprecated: build-smoke is always web-only. Kept as no-op for callers.
      shift
      ;;
    --list-steps)
      list_steps=1
      shift
      ;;
    --keep-going)
      keep_going=1
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      ;;
  esac
done

timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

hb() {
  # Observable wrapper (same as remote CI).
  bash tool/ci/run_with_heartbeat.sh "$@"
}

step_failures=0
current_step=''

step() {
  current_step=$1
  printf '\n[%s] ===== STEP START: %s =====\n' "$(timestamp)" "$current_step"
}

step_ok() {
  printf '[%s] ===== STEP PASS: %s =====\n' "$(timestamp)" "$current_step"
  current_step=''
}

on_err() {
  local ec=$?
  if [[ -n $current_step ]]; then
    printf '[%s] ===== STEP FAIL: %s (exit %s) =====\n' \
      "$(timestamp)" "$current_step" "$ec" >&2
  else
    printf '[%s] ===== FAIL (exit %s) =====\n' "$(timestamp)" "$ec" >&2
  fi
  if [[ $keep_going -eq 1 ]]; then
    step_failures=$((step_failures + 1))
    return 0
  fi
  exit "$ec"
}
trap on_err ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 127
  }
}

resolve_base_sha() {
  if [[ -n $base_sha ]]; then
    # Allow branch names / short SHAs.
    git rev-parse --verify "${base_sha}^{commit}"
    return
  fi

  local event_name=${FORGEJO_EVENT_NAME:-${GITHUB_EVENT_NAME:-}}
  local event_path=${FORGEJO_EVENT_PATH:-${GITHUB_EVENT_PATH:-}}
  local sha=''

  if [[ -n $event_path && -f $event_path ]]; then
    sha=$(
      python3 - "$event_path" "$event_name" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as event_file:
    event = json.load(event_file)
if sys.argv[2] == "pull_request":
    print(event.get("pull_request", {}).get("base", {}).get("sha", ""))
elif sys.argv[2] == "push":
    print(event.get("before", ""))
PY
    )
  fi

  if [[ ! $sha =~ ^[0-9a-fA-F]{40}$ || $sha =~ ^0+$ ]]; then
    # Local default: merge-base with origin/main when available, else parent.
    if git rev-parse --verify --quiet origin/main >/dev/null; then
      sha=$(git merge-base HEAD origin/main)
    else
      sha=$(git rev-parse HEAD^)
    fi
  fi
  git rev-parse --verify "${sha}^{commit}"
}

run_diagnostics() {
  step "diagnostics"
  printf '[%s] CI event=%s ref=%s sha=%s\n' \
    "$(timestamp)" \
    "${FORGEJO_EVENT_NAME:-${GITHUB_EVENT_NAME:-local}}" \
    "${FORGEJO_REF:-${GITHUB_REF:-$(git rev-parse --abbrev-ref HEAD)}}" \
    "$(git rev-parse HEAD)"
  git log --oneline -3
  flutter --version
  dart --version
  git --version
  printf '%s\n' '--- disk ---'
  df -h . || true
  printf '%s\n' '--- memory ---'
  free -h 2>/dev/null || true
  step_ok
}

run_quality() {
  require_cmd flutter
  require_cmd dart
  require_cmd git
  require_cmd python3
  require_cmd bash

  run_diagnostics

  step "pub get --enforce-lockfile"
  hb "Flutter dependency resolution" 20 -- flutter pub get --enforce-lockfile
  step_ok

  step "lockfile exact"
  git diff --exit-code -- pubspec.lock
  step_ok

  step "generate synthetic config"
  printf '[%s] AGENTFORGE_CONFIG=%s\n' "$(timestamp)" "$AGENTFORGE_CONFIG"
  dart run tool/generate_config.dart
  git diff --exit-code -- \
    lib/core/config/generated/app_config.selected.dart \
    agentforge-config.properties \
    ios/Flutter/AgentForge.xcconfig
  step_ok

  step "dart format"
  dart format --output=none --set-exit-if-changed lib test tool
  step_ok

  step "flutter analyze --fatal-infos"
  hb "Flutter static analysis" 20 -- flutter analyze --no-pub --fatal-infos
  step_ok

  step "flutter test (seed=${TEST_RANDOM_SEED})"
  hb "Flutter randomized test suite" 20 -- \
    flutter test --no-pub --coverage --branch-coverage \
    --test-randomize-ordering-seed="${TEST_RANDOM_SEED}"
  step_ok

  step "global line coverage floor ${LINE_COVERAGE_FLOOR}%"
  dart run tool/check_coverage.dart coverage/lcov.info "${LINE_COVERAGE_FLOOR}"
  step_ok

  step "changed-line coverage floor ${DIFF_COVERAGE_FLOOR}%"
  local base
  base=$(resolve_base_sha)
  printf '[%s] diff coverage base=%s head=%s\n' \
    "$(timestamp)" "$base" "$(git rev-parse HEAD)"
  dart run tool/check_diff_coverage.dart \
    coverage/lcov.info "$base" "${DIFF_COVERAGE_FLOOR}"
  step_ok

  step "PII report-only inventory"
  dart run tool/check_no_pii.dart --mode=report --scope=tracked
  step_ok

  step "CI shell script smokes"
  # Syntax-check Android install scripts, but do NOT execute SDK install
  # functional suites here (those are nightly / android-smoke only).
  bash -n tool/ci/run_with_heartbeat.sh
  bash -n tool/ci/test_heartbeat.sh
  bash -n tool/ci/install_android_sdk.sh
  bash -n tool/ci/test_install_android_sdk.sh
  bash -n tool/ci/run_local_ci.sh
  bash -n tool/ci/setup_flutter.sh
  bash -n tool/deploy_web.sh
  bash -n tool/hooks/pre-commit
  bash -n tool/hooks/install.sh
  bash tool/ci/test_heartbeat.sh
  step_ok

  step "staged-PII guard is wired and fails closed"
  # Same check the pre-commit hook runs; on a clean CI index it must pass.
  dart run tool/check_no_pii.dart --mode=structural --scope=staged
  step_ok

  step "final tracked-tree cleanliness"
  git diff --check
  git diff --exit-code
  local tracked_status
  tracked_status=$(git status --porcelain --untracked-files=no)
  if [[ -n $tracked_status ]]; then
    printf '%s\n' "$tracked_status" >&2
    exit 1
  fi
  step_ok

  printf '\n[%s] quality lane complete\n' "$(timestamp)"
}

run_build_smoke() {
  # PR/push CI path: Web only. Never installs Android SDK packages.
  require_cmd flutter
  require_cmd dart
  require_cmd git

  step "pub get --enforce-lockfile (build-smoke)"
  hb "Build-lane dependency resolution" 20 -- flutter pub get --enforce-lockfile
  step_ok

  step "generate synthetic config (build-smoke)"
  dart run tool/generate_config.dart
  git diff --exit-code -- \
    lib/core/config/generated/app_config.selected.dart \
    agentforge-config.properties \
    ios/Flutter/AgentForge.xcconfig
  step_ok

  step "flutter build web --release"
  hb "Flutter release Web build" 20 -- \
    flutter build web --release --no-wasm-dry-run --no-pub
  step_ok

  step "verify web artifact"
  test -s build/web/index.html
  printf '[%s] web index bytes=%s total=%s\n' \
    "$(timestamp)" \
    "$(wc -c <build/web/index.html | tr -d ' ')" \
    "$(du -sh build/web | cut -f1)"
  step_ok

  printf '\n[%s] build-smoke lane complete (web only; no Android SDK)\n' \
    "$(timestamp)"
}

run_android_smoke() {
  # Nightly / on-demand only. Installs or validates SDK packages then APK+lint.
  require_cmd flutter
  require_cmd dart
  require_cmd git
  require_cmd java

  if [[ -z ${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}} ]]; then
    echo "ANDROID_SDK_ROOT/ANDROID_HOME must be set for android-smoke" >&2
    exit 1
  fi

  step "pub get --enforce-lockfile (android-smoke)"
  hb "Android-lane dependency resolution" 20 -- flutter pub get --enforce-lockfile
  step_ok

  step "generate synthetic config (android-smoke)"
  dart run tool/generate_config.dart
  git diff --exit-code -- \
    lib/core/config/generated/app_config.selected.dart \
    agentforge-config.properties \
    ios/Flutter/AgentForge.xcconfig
  step_ok

  step "Android SDK install-script unit smoke"
  bash tool/ci/test_install_android_sdk.sh
  step_ok

  step "install/validate Android SDK packages"
  hb "Android SDK package installation" 30 -- bash tool/ci/install_android_sdk.sh
  step_ok

  step "flutter build apk --debug"
  hb "Flutter debug APK build" 30 -- flutter build apk --debug --no-pub
  step_ok

  step "android lintDebug"
  hb "Android lintDebug" 30 -- \
    bash -c 'cd android && ./gradlew --stop && ./gradlew --no-daemon --console=plain --stacktrace lintDebug'
  step_ok

  step "verify apk + clean tree"
  local apk=build/app/outputs/flutter-apk/app-debug.apk
  test -s "$apk"
  printf '[%s] apk bytes=%s\n' "$(timestamp)" "$(wc -c <"$apk" | tr -d ' ')"
  git diff --check
  git diff --exit-code
  step_ok

  printf '\n[%s] android-smoke lane complete\n' "$(timestamp)"
}

if [[ $list_steps -eq 1 ]]; then
  cat <<'EOF'
quality:        every PR/push (no Android SDK install)
build-smoke:    every PR/push — release Web only
android-smoke:  nightly / workflow_dispatch — SDK packages + debug APK + lint

quality:
  - diagnostics
  - pub get --enforce-lockfile
  - lockfile exact
  - generate synthetic config
  - dart format
  - flutter analyze --fatal-infos
  - flutter test (seed)
  - global line coverage floor
  - changed-line coverage floor
  - PII report-only inventory
  - CI shell script smokes (no real SDK install)
  - staged-PII guard is wired and fails closed
  - final tracked-tree cleanliness

build-smoke:
  - pub get --enforce-lockfile
  - generate synthetic config
  - flutter build web --release
  - verify web artifact

android-smoke:
  - pub get --enforce-lockfile
  - generate synthetic config
  - test_install_android_sdk.sh (fake sdkmanager unit smoke)
  - install_android_sdk.sh (real packages)
  - flutter build apk --debug
  - android lintDebug
  - verify apk
EOF
  exit 0
fi

printf '[%s] run_local_ci lane=%s root=%s\n' "$(timestamp)" "$lane" "$repo_root"

case "$lane" in
  quality)
    run_quality
    ;;
  build-smoke)
    run_build_smoke
    ;;
  android-smoke)
    run_android_smoke
    ;;
  all)
    run_quality
    run_build_smoke
    run_android_smoke
    ;;
  *)
    echo "unknown lane: $lane (use quality|build-smoke|android-smoke|all)" >&2
    exit 64
    ;;
esac

if [[ $step_failures -gt 0 ]]; then
  printf '[%s] completed with %s step failure(s)\n' "$(timestamp)" "$step_failures" >&2
  exit 1
fi

printf '[%s] run_local_ci OK (lane=%s)\n' "$(timestamp)" "$lane"
