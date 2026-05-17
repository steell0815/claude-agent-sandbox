#!/usr/bin/env bash
# entrypoint.sh — agent container entrypoint.
#
# Validates that the agent has at least one viable auth path before
# handing off to `claude`. Auth resolution order matches Claude Code's
# own: ANTHROPIC_API_KEY > ~/.claude/.credentials.json.

set -euo pipefail

CRED_FILE="${HOME}/.claude/.credentials.json"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]] && [[ ! -f "$CRED_FILE" ]]; then
  cat >&2 <<'EOF'
ERROR: no Anthropic credentials available inside the sandbox.

Provide one of:
  - Set ANTHROPIC_API_KEY in your .env (recommended for headless use).
  - Bind-mount your host ~/.claude with a valid .credentials.json
    present (the default compose stack already does this read-only).

On macOS, Claude Code stores its credential in the Keychain by default,
not as a file. Run the bundled helper on the host to extract it:

  ./scripts/export-keychain-credentials.sh

…then re-run the agent. The helper is idempotent and safe to re-run
whenever the host token rotates.
EOF
  exit 64  # EX_USAGE
fi

# Optional: surface profile freshness so it's visible in logs.
if [[ -d "${HOME}/.claude" ]]; then
  printf 'profile: %s (mounted)\n' "${HOME}/.claude"
fi

# Append the sandbox guide to the system prompt so the agent knows about
# the builder service and other sandbox-specific affordances. Skip if the
# caller already passed --append-system-prompt — their intent wins.
GUIDE=/etc/claude-code/sandbox-guide.md
APPEND_ARGS=()
if [[ -r "$GUIDE" ]] && ! printf '%s\0' "$@" | grep -qz -- '--append-system-prompt'; then
  APPEND_ARGS=(--append-system-prompt "$(cat "$GUIDE")")
fi

# Load sandbox settings (PreToolUse hooks etc.). Same "caller wins"
# convention as the system prompt: if the user passed --settings
# themselves, defer to that.
SETTINGS=/etc/claude-code/sandbox-settings.json
SETTINGS_ARGS=()
if [[ -r "$SETTINGS" ]] && ! printf '%s\0' "$@" | grep -qz -- '--settings'; then
  SETTINGS_ARGS=(--settings "$SETTINGS")
fi

exec claude "${APPEND_ARGS[@]}" "${SETTINGS_ARGS[@]}" "$@"
