#!/usr/bin/env bash
set -Eeuo pipefail

readonly PLATFORM_VERSION='android-36'
readonly BUILD_TOOLS_VERSION='36.0.0'
readonly NDK_VERSION='28.2.13676358'
readonly MAX_ATTEMPTS=3

timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

log() {
  printf '[%s] ANDROID-SDK %s\n' "$(timestamp)" "$*"
}

die() {
  log "ERROR $*"
  exit 1
}

sdk_root_raw=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
[[ -n $sdk_root_raw ]] || die 'ANDROID_SDK_ROOT/ANDROID_HOME is not set'
[[ $sdk_root_raw == /* ]] || die 'SDK root must be an absolute path'
[[ -d $sdk_root_raw ]] || die 'SDK root does not exist'
command -v realpath >/dev/null 2>&1 || die 'realpath is required'
sdk_root=$(realpath -e -- "$sdk_root_raw") || die 'SDK root is not canonical'
[[ $sdk_root != / ]] || die 'refusing to use filesystem root as SDK root'

sdkmanager=$(command -v sdkmanager || true)
[[ -n $sdkmanager ]] || die 'sdkmanager is not on PATH'

declare -a packages=(
  'platform-tools'
  "platforms;$PLATFORM_VERSION"
  "build-tools;$BUILD_TOOLS_VERSION"
  "ndk;$NDK_VERSION"
)

marker_for() {
  case "$1" in
    'platform-tools') printf '%s/platform-tools/adb' "$sdk_root" ;;
    "platforms;$PLATFORM_VERSION")
      printf '%s/platforms/%s/android.jar' "$sdk_root" "$PLATFORM_VERSION"
      ;;
    "build-tools;$BUILD_TOOLS_VERSION")
      printf '%s/build-tools/%s/aapt2' "$sdk_root" "$BUILD_TOOLS_VERSION"
      ;;
    "ndk;$NDK_VERSION")
      printf '%s/ndk/%s/source.properties' "$sdk_root" "$NDK_VERSION"
      ;;
    *) die 'unknown package marker request' ;;
  esac
}

directory_for() {
  case "$1" in
    'platform-tools') printf '%s/platform-tools' "$sdk_root" ;;
    "platforms;$PLATFORM_VERSION")
      printf '%s/platforms/%s' "$sdk_root" "$PLATFORM_VERSION"
      ;;
    "build-tools;$BUILD_TOOLS_VERSION")
      printf '%s/build-tools/%s' "$sdk_root" "$BUILD_TOOLS_VERSION"
      ;;
    "ndk;$NDK_VERSION") printf '%s/ndk/%s' "$sdk_root" "$NDK_VERSION" ;;
    *) die 'unknown package directory request' ;;
  esac
}

assert_package_paths_contained() {
  local package=$1
  local target marker canonical_target canonical_marker
  target=$(directory_for "$package")
  marker=$(marker_for "$package")

  case "$target" in
    "$sdk_root"/platform-tools|\
    "$sdk_root"/platforms/"$PLATFORM_VERSION"|\
    "$sdk_root"/build-tools/"$BUILD_TOOLS_VERSION"|\
    "$sdk_root"/ndk/"$NDK_VERSION") ;;
    *) die 'package target escaped the exact allow-list' ;;
  esac

  canonical_target=$(realpath -m -- "$target") ||
    die 'package target is not canonical'
  [[ $canonical_target == "$target" ]] ||
    die 'canonical package target differs from its exact allow-listed path'
  case "$canonical_target" in
    "$sdk_root"/*) ;;
    *) die 'canonical package target escaped the SDK root' ;;
  esac

  canonical_marker=$(realpath -m -- "$marker") ||
    die 'package marker is not canonical'
  [[ $canonical_marker == "$marker" ]] ||
    die 'canonical package marker differs from its exact allow-listed path'
  case "$canonical_marker" in
    "$canonical_target"/*) ;;
    *) die 'canonical package marker escaped its package directory' ;;
  esac
}

package_is_valid() {
  local package=$1
  local marker revision_pattern
  assert_package_paths_contained "$package"
  marker=$(marker_for "$package")
  revision_pattern=${NDK_VERSION//./\\.}
  case "$package" in
    'platform-tools'|"build-tools;$BUILD_TOOLS_VERSION")
      [[ -s $marker && -x $marker ]]
      ;;
    "platforms;$PLATFORM_VERSION")
      [[ -s $marker ]]
      ;;
    "ndk;$NDK_VERSION")
      [[ -s $marker ]] &&
        grep -Eq "^Pkg\\.Revision[[:space:]]*=[[:space:]]*$revision_pattern[[:space:]]*$" "$marker"
      ;;
    *) return 1 ;;
  esac
}

repair_partial_package() {
  local package=$1
  local target
  target=$(directory_for "$package")
  assert_package_paths_contained "$package"
  [[ -e $target || -L $target ]] || return 0
  package_is_valid "$package" && return 0

  log "removing incomplete package directory: ${target#"$sdk_root"/}"
  rm -rf -- "$target"
}

validate_packages() {
  local package marker missing=0
  for package in "${packages[@]}"; do
    marker=$(marker_for "$package")
    if package_is_valid "$package"; then
      log "validated $package (${marker#"$sdk_root"/})"
    else
      log "missing marker for $package (${marker#"$sdk_root"/})"
      missing=1
    fi
  done
  return "$missing"
}

log 'sdk_root configured (canonical path redacted)'
log "sdkmanager=$(basename -- "$sdkmanager")"
"$sdkmanager" --version

if validate_packages; then
  log 'all required packages were already complete'
  exit 0
fi

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  log "install attempt $attempt/$MAX_ATTEMPTS"
  for package in "${packages[@]}"; do
    repair_partial_package "$package"
  done

  if "$sdkmanager" --sdk_root="$sdk_root" "${packages[@]}"; then
    if validate_packages; then
      log 'all required packages installed and validated'
      exit 0
    fi
  else
    log "sdkmanager attempt $attempt failed"
  fi

  if [[ $attempt -lt $MAX_ATTEMPTS ]]; then
    delay=$((attempt * 10))
    log "retrying after ${delay}s"
    sleep "$delay"
  fi
done

die "required Android packages remain incomplete after $MAX_ATTEMPTS attempts"
