#!/usr/bin/env bash
# run-agent.sh — convenience wrapper around `docker compose run --rm agent`.
#
# Two jobs:
#  1. On macOS, refresh ~/.claude/.credentials.json from the Keychain so the
#     sandbox picks up a fresh token (host `claude login` rotates the
#     keychain item but never touches the file on disk). A failed export is
#     non-fatal — ANTHROPIC_API_KEY or a still-valid prior export may carry
#     the run.
#  2. Bind-mount whatever directory you ran the script from as /workspace.
#     Run it from any project root and that project becomes the agent's
#     working tree. Set AGENT_WORKDIR=/abs/path to override.
#
# Usage:
#   cd ~/code/some-java-project && /path/to/run-agent.sh
#   AGENT_WORKDIR=/abs/path /path/to/run-agent.sh
#   ./scripts/run-agent.sh -p "summarize the repo"   # extra args go to claude
#
# Symlink onto PATH (e.g. `ln -s "$PWD/scripts/run-agent.sh" ~/.local/bin/cas`)
# so you can just type `cas` from any project.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INVOCATION_DIR="$PWD"

# Decide the workdir to mount.
#  - AGENT_WORKDIR wins (lets callers script around this).
#  - Otherwise: $PWD, unless we were launched from inside the repo with no
#    override — then keep the historical default of ./project/ so the
#    quickstart still works.
if [[ -z "${AGENT_WORKDIR:-}" ]]; then
  if [[ "$INVOCATION_DIR" == "$REPO_ROOT" ]]; then
    AGENT_WORKDIR="$REPO_ROOT/project"
  else
    AGENT_WORKDIR="$INVOCATION_DIR"
  fi
fi

# Normalize to an absolute path so the compose bind mount is unambiguous
# regardless of where docker compose itself runs from.
if [[ ! -d "$AGENT_WORKDIR" ]]; then
  echo "ERROR: AGENT_WORKDIR is not a directory: $AGENT_WORKDIR" >&2
  exit 64
fi
AGENT_WORKDIR="$(cd "$AGENT_WORKDIR" && pwd)"
export AGENT_WORKDIR

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! "$REPO_ROOT/scripts/export-keychain-credentials.sh"; then
    echo "warn: keychain export failed — continuing with whatever creds the sandbox already has" >&2
  fi
fi

echo "workdir: $AGENT_WORKDIR -> /workspace" >&2

cd "$REPO_ROOT"
exec docker compose run --rm agent "$@"
