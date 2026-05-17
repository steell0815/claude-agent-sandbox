#!/usr/bin/env bash
# run-agent.sh — convenience wrapper around `docker compose run --rm agent`.
#
# On macOS, refreshes ~/.claude/.credentials.json from the Keychain first so
# the sandbox picks up a fresh token on every run (host `claude login`
# rotates the keychain item but never touches the file on disk).
#
# A failed export is non-fatal: if ANTHROPIC_API_KEY is set in .env, or if
# a previously exported credentials file is still valid, the agent's own
# entrypoint will sort it out.
#
# Usage:
#   ./scripts/run-agent.sh            # interactive Claude Code
#   ./scripts/run-agent.sh -p "..."   # any args are forwarded to `claude`

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! ./scripts/export-keychain-credentials.sh; then
    echo "warn: keychain export failed — continuing with whatever creds the sandbox already has" >&2
  fi
fi

exec docker compose run --rm agent "$@"
