#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temp_parent=$(realpath -e -- "${TMPDIR:-/tmp}")
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/agentforge-sdk-test.XXXXXX")
temp_dir=$(realpath -e -- "$temp_dir")

case "$temp_dir" in
  "$temp_parent"/agentforge-sdk-test.*) ;;
  *) echo 'unsafe Android SDK test temp path' >&2; exit 1 ;;
esac

cleanup() {
  rm -rf -- "$temp_dir"
}
trap cleanup EXIT

fake_bin=$temp_dir/bin
sdk_root=$temp_dir/sdk
mkdir -p "$fake_bin" "$sdk_root"

cat >"$fake_bin/sdkmanager" <<'FAKE'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${1:-} == --version ]]; then
  echo 'fake-sdkmanager-1'
  exit 0
fi
sdk_root=''
for argument in "$@"; do
  case "$argument" in
    --sdk_root=*) sdk_root=${argument#--sdk_root=} ;;
  esac
done
[[ -n $sdk_root ]]
mkdir -p \
  "$sdk_root/platform-tools" \
  "$sdk_root/platforms/android-36" \
  "$sdk_root/build-tools/36.0.0" \
  "$sdk_root/ndk/28.2.13676358"
printf 'adb\n' >"$sdk_root/platform-tools/adb"
printf 'android jar\n' >"$sdk_root/platforms/android-36/android.jar"
printf 'aapt2\n' >"$sdk_root/build-tools/36.0.0/aapt2"
printf 'Pkg.Revision = 28.2.13676358\n' \
  >"$sdk_root/ndk/28.2.13676358/source.properties"
chmod +x \
  "$sdk_root/platform-tools/adb" \
  "$sdk_root/build-tools/36.0.0/aapt2"
FAKE
chmod +x "$fake_bin/sdkmanager"

mkdir -p \
  "$sdk_root/platform-tools" \
  "$sdk_root/platforms/android-36" \
  "$sdk_root/build-tools/36.0.0" \
  "$sdk_root/ndk/28.2.13676358"
touch \
  "$sdk_root/platform-tools/adb" \
  "$sdk_root/platforms/android-36/android.jar" \
  "$sdk_root/build-tools/36.0.0/aapt2"
printf 'Pkg.Revision = 0.0.0\n' \
  >"$sdk_root/ndk/28.2.13676358/source.properties"
touch \
  "$sdk_root/platform-tools/stale" \
  "$sdk_root/platforms/android-36/stale" \
  "$sdk_root/build-tools/36.0.0/stale" \
  "$sdk_root/ndk/28.2.13676358/stale"

PATH="$fake_bin:$PATH" ANDROID_SDK_ROOT="$sdk_root" \
  bash "$script_dir/install_android_sdk.sh"

[[ -s $sdk_root/platform-tools/adb && -x $sdk_root/platform-tools/adb ]]
[[ -s $sdk_root/platforms/android-36/android.jar ]]
[[ -s $sdk_root/build-tools/36.0.0/aapt2 && \
  -x $sdk_root/build-tools/36.0.0/aapt2 ]]
grep -Fqx 'Pkg.Revision = 28.2.13676358' \
  "$sdk_root/ndk/28.2.13676358/source.properties"
if find "$sdk_root" -name stale -print -quit | grep -q .; then
  echo 'corrupt package directory was not repaired' >&2
  exit 1
fi

# An allow-listed path that resolves outside the canonical SDK root must fail
# without touching the external target.
escape_root=$temp_dir/escape-sdk
outside=$temp_dir/outside
mkdir -p "$escape_root" "$outside"
touch "$outside/sentinel"
if ln -s "$outside" "$escape_root/platform-tools" 2>/dev/null; then
  status=0
  PATH="$fake_bin:$PATH" ANDROID_SDK_ROOT="$escape_root" \
    bash "$script_dir/install_android_sdk.sh" >/dev/null 2>&1 || status=$?
  [[ $status -ne 0 ]]
  [[ -f $outside/sentinel ]]
else
  echo 'symlink escape smoke skipped: symlink creation unavailable'
fi

# A valid-looking marker outside the SDK root must never be trusted.
valid_escape_root=$temp_dir/valid-escape-sdk
valid_outside=$temp_dir/valid-outside
mkdir -p "$valid_escape_root" "$valid_outside"
printf 'external adb\n' >"$valid_outside/adb"
chmod +x "$valid_outside/adb"
if ln -s "$valid_outside" "$valid_escape_root/platform-tools" 2>/dev/null; then
  status=0
  PATH="$fake_bin:$PATH" ANDROID_SDK_ROOT="$valid_escape_root" \
    bash "$script_dir/install_android_sdk.sh" >/dev/null 2>&1 || status=$?
  [[ $status -ne 0 ]]
  grep -Fqx 'external adb' "$valid_outside/adb"
else
  echo 'valid-marker symlink escape smoke skipped: symlink creation unavailable'
fi

# A missing package below a symlinked parent must be rejected before
# sdkmanager can create it outside the canonical SDK root.
parent_escape_root=$temp_dir/parent-escape-sdk
parent_outside=$temp_dir/parent-outside
mkdir -p "$parent_escape_root" "$parent_outside"
touch "$parent_outside/sentinel"
if ln -s "$parent_outside" "$parent_escape_root/platforms" 2>/dev/null; then
  status=0
  PATH="$fake_bin:$PATH" ANDROID_SDK_ROOT="$parent_escape_root" \
    bash "$script_dir/install_android_sdk.sh" >/dev/null 2>&1 || status=$?
  [[ $status -ne 0 ]]
  [[ -f $parent_outside/sentinel ]]
  [[ ! -e $parent_outside/android-36 ]]
else
  echo 'symlinked-parent escape smoke skipped: symlink creation unavailable'
fi

if [[ $(uname -s) == Linux ]]; then
  status=0
  PATH="$fake_bin:$PATH" ANDROID_SDK_ROOT=/tmp/.. \
    bash "$script_dir/install_android_sdk.sh" >/dev/null 2>&1 || status=$?
  [[ $status -ne 0 ]]
fi

echo 'Android SDK canonicalization, repair, and marker smokes: PASS'
