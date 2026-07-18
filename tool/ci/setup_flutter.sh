#!/usr/bin/env bash
# Bootstrap the pinned Flutter SDK without relying on composite-action outputs.
#
# Forgejo act_runner 3.5.1 can fail while evaluating the outputs of
# subosito/flutter-action, after its SDK download has already completed. Keep
# the SDK inside this job's temporary directory and verify the exact release
# archive before adding it to PATH.

set -Eeuo pipefail

: "${FLUTTER_VERSION:=3.44.6}"

case "$FLUTTER_VERSION" in
  3.44.6)
    flutter_sha256='a6320fd72e9a2690c08e2a6a70874a30cb120dee7c78f49d2c628bd7c9e20525'
    ;;
  *)
    printf 'Unsupported pinned Flutter version: %s\n' "$FLUTTER_VERSION" >&2
    exit 64
    ;;
esac

base_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
sdk_dir="$(mktemp -d "$base_dir/agentforge-flutter.XXXXXX")"
archive="$sdk_dir/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

curl --fail --location --retry 5 --connect-timeout 15 --output "$archive" "$archive_url"
printf '%s  %s\n' "$flutter_sha256" "$archive" | sha256sum --check --status
tar -xJf "$archive" -C "$sdk_dir"

flutter_bin="$sdk_dir/flutter/bin/flutter"
[[ -x "$flutter_bin" ]]
"$flutter_bin" --version

{
  printf '%s\n' "$sdk_dir/flutter/bin"
  printf '%s\n' "$sdk_dir/flutter/bin/cache/dart-sdk/bin"
} >> "$GITHUB_PATH"
