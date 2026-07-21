#!/usr/bin/env bash
# Point this clone's git hooks at the tracked tool/hooks directory.
#
# Uses core.hooksPath so the hooks stay version-controlled and every clone gets
# the same guard with one command. Idempotent.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd -- "$repo_root"

chmod +x tool/hooks/pre-commit
git config core.hooksPath tool/hooks

echo "core.hooksPath = $(git config core.hooksPath)"
echo "AgentForge pre-commit PII guard installed."
