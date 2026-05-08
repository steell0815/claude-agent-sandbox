#!/usr/bin/env bash
# export-keychain-credentials.sh — pull the Claude Code credential from the
# macOS Keychain and write it to a file the sandbox can mount.
#
# Run this once after `claude login` on the host, and again whenever the
# host token has rotated and you want the sandbox to pick up the fresh
# value (in practice: after a long break, or if `claude` complains about
# expired auth from inside the container).
#
# Usage:
#   ./scripts/export-keychain-credentials.sh
#
# Env overrides (rarely needed):
#   KEYCHAIN_SERVICE  default: "Claude Code-credentials"
#   KEYCHAIN_ACCOUNT  default: $USER
#   TARGET            default: $HOME/.claude/.credentials.json
#
# Exit codes:
#   0  wrote the file (or it already matched)
#   2  not running on macOS
#   3  keychain item not found
#   4  retrieved value is not valid JSON

set -euo pipefail

KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-Claude Code-credentials}"
KEYCHAIN_ACCOUNT="${KEYCHAIN_ACCOUNT:-$USER}"
TARGET="${TARGET:-$HOME/.claude/.credentials.json}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS only (uname -s reports $(uname -s)). On Linux the" \
       "credential is already a file at ~/.claude/.credentials.json — no" \
       "extraction step is needed." >&2
  exit 2
fi

if ! command -v security >/dev/null 2>&1; then
  echo "ERROR: macOS 'security' tool not found in PATH" >&2
  exit 2
fi

echo "Reading keychain item: service='$KEYCHAIN_SERVICE' account='$KEYCHAIN_ACCOUNT'" >&2
if ! VALUE="$(security find-generic-password \
                -s "$KEYCHAIN_SERVICE" \
                -a "$KEYCHAIN_ACCOUNT" \
                -w 2>/dev/null)"; then
  cat >&2 <<EOF
ERROR: keychain item not found.
  service = $KEYCHAIN_SERVICE
  account = $KEYCHAIN_ACCOUNT

Common causes:
  - You haven't run \`claude login\` on the host yet.
  - Claude Code stores under a different name in your version.

Inspect what's there:
  security dump-keychain 2>/dev/null | grep -iE 'svce.*claude|svce.*anthropic'

Then re-run with overrides if needed:
  KEYCHAIN_SERVICE='...' KEYCHAIN_ACCOUNT='...' $0
EOF
  exit 3
fi

# Validate JSON before persisting.
if ! printf '%s' "$VALUE" \
      | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "ERROR: keychain value is not valid JSON; refusing to write" >&2
  exit 4
fi

mkdir -p "$(dirname "$TARGET")"

# Idempotent skip: if the existing file already holds the same bytes,
# don't churn the mtime (helps avoid restarting long-running containers
# that bind-mount this file when nothing actually changed).
if [[ -f "$TARGET" ]] && printf '%s' "$VALUE" | cmp -s - "$TARGET"; then
  echo "Already up-to-date: $TARGET" >&2
  exit 0
fi

# Atomic write with 0600 perms.
umask 077
TMP="$(mktemp "${TARGET}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
printf '%s' "$VALUE" > "$TMP"
chmod 0600 "$TMP"
mv "$TMP" "$TARGET"
trap - EXIT

echo "Wrote $TARGET (mode 0600)" >&2
