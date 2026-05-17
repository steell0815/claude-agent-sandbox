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
# Env vars:
#   CAS_HOME        explicit path to the claude-agent-sandbox checkout.
#                   Overrides the script-location heuristic — set this if
#                   you copied (didn't symlink) the script, or keep
#                   multiple checkouts.
#   AGENT_WORKDIR   host dir bind-mounted at /workspace. Defaults to $PWD
#                   when invoked outside the repo; ./project/ when inside.
#
# Install on PATH (pick whichever you prefer):
#   ln -s "$PWD/scripts/run-agent.sh" ~/.local/bin/cas       # symlink
#   echo 'export CAS_HOME=~/dev/claude-agent-sandbox' >> ~/.zshrc \
#     && cp scripts/run-agent.sh ~/.local/bin/cas             # env-var path
#
# Locate the claude-agent-sandbox checkout. Resolution order:
#   1. $CAS_HOME (explicit override — handy if this script was copied, not
#      symlinked, or if you keep multiple checkouts and want to pick one).
#   2. Symlink-aware resolution from the script's own path, so
#      ~/.local/bin/cas -> .../claude-agent-sandbox/scripts/run-agent.sh works.
# Both modes validate that the resolved dir actually contains the repo.

set -euo pipefail

if [[ -n "${CAS_HOME:-}" ]]; then
  REPO_ROOT="$CAS_HOME"
else
  # Walk symlinks portably (no GNU `readlink -f` dependency).
  SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
  while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
  done
  REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
fi

if [[ ! -f "$REPO_ROOT/docker-compose.yml" ]]; then
  cat >&2 <<EOF
ERROR: claude-agent-sandbox not found at: $REPO_ROOT
(no docker-compose.yml there)

Either:
  - clone/checkout this repo and re-symlink the wrapper:
      ln -sf "/path/to/claude-agent-sandbox/scripts/run-agent.sh" "$0"
  - set CAS_HOME=/path/to/claude-agent-sandbox in your shell.
EOF
  exit 64
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
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
