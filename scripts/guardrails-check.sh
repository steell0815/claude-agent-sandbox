#!/usr/bin/env bash
# guardrails-check.sh --- Check staged changes against guardrail instant failures
#
# Delegates to the pattern-file-driven v2 engine.
#
# Usage:
#   guardrails-check.sh [staged|unstaged|branch]    --- defaults to staged
#
# Output: Result envelope JSON (see guardrails/guardrails-check-v2.sh)
# Exit code: 0 = clean, 1 = violations found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/guardrails/guardrails-check-v2.sh" --scope "${1:-staged}"
