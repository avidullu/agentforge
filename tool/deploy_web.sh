#!/usr/bin/env bash
# Build AgentForge for the web and deploy it to a tailnet host (AF-019).
#
# The app is served SAME-ORIGIN with Forgejo so the browser makes no
# cross-origin requests and no Forgejo CORS configuration is required.
#
# Usage:
#   bash tool/deploy_web.sh --host <user@tailnet-host> [--path /agentforge] \
#                           [--dir ~/agentforge-web] [--build-only]
#
# Prerequisites on the target host:
#   - tailscale serve already fronting Forgejo on "/"
#   - SSH access (Tailscale SSH is fine); rsync is NOT required
#
# The real Forgejo origin comes from config/agentforge.config.json (gitignored).
# Without it the generator falls back to the synthetic forge.example.test and
# the app will refuse to connect to your instance at runtime.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo_root"

host=''
url_path='/agentforge'
remote_dir=''
build_only=0

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) host=${2:-}; shift 2 ;;
    --path) url_path=${2:-}; shift 2 ;;
    --dir) remote_dir=${2:-}; shift 2 ;;
    --build-only) build_only=1; shift ;;
    -h | --help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

[[ $url_path == /* ]] || { echo "--path must start with '/'" >&2; exit 64; }
if [[ $build_only -eq 0 && -z $host ]]; then
  echo "--host is required (or pass --build-only)" >&2
  exit 64
fi
remote_dir=${remote_dir:-"agentforge-web"}

if [[ ! -f config/agentforge.config.json ]]; then
  cat >&2 <<'EOF'
WARNING: config/agentforge.config.json not found.

The build will use the synthetic origin (https://forge.example.test) and the
app will reject your real Forgejo instance with "This build trusts only ...".
See docs/WEB_PWA_DEPLOY.md.
EOF
fi

echo "==> generating build config"
dart run tool/generate_config.dart

# base-href must start AND end with '/' for Flutter's asset resolution.
base_href="${url_path%/}/"
echo "==> building release web (base-href=${base_href})"
flutter build web --release --base-href="$base_href"

test -s build/web/index.html

if [[ $build_only -eq 1 ]]; then
  echo "==> build-only: artifact at build/web ($(du -sh build/web | cut -f1))"
  exit 0
fi

echo "==> deploying to ${host}:${remote_dir}"
# rsync is unavailable on some targets (e.g. ChromeOS Crostini), so stream a tar.
# Replace atomically-ish: stage beside the live dir, then swap.
ssh "$host" "rm -rf '${remote_dir}.new' && mkdir -p '${remote_dir}.new'"
tar -C build/web -czf - . | ssh "$host" "tar -C '${remote_dir}.new' -xzf -"
ssh "$host" "rm -rf '${remote_dir}.old' \
  && { [ -d '${remote_dir}' ] && mv '${remote_dir}' '${remote_dir}.old' || true; } \
  && mv '${remote_dir}.new' '${remote_dir}' \
  && rm -rf '${remote_dir}.old'"

echo "==> publishing path ${url_path} via tailscale serve"
ssh "$host" "sudo tailscale serve --bg --set-path='${url_path}' \"\$HOME/${remote_dir}\""

echo
echo "Deployed. Open it from any device on the tailnet:"
ssh "$host" "sudo tailscale serve status" || true
