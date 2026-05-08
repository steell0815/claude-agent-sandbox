#!/usr/bin/env bash
# pre-commit.sh — Orchestrator for pre-commit checks
#
# Runs check modules sequentially (fail-fast):
#   1. bash-syntax — validate staged .sh files
#   2. secrets     — detect hardcoded secrets in staged diff
#
# Architecture/Clean-Code guardrails are not enforced here — those rules
# live in the mounted-in agent profile and apply to projects the sandbox
# operates on, not to the sandbox repo itself.
#
# Exit: 0 = all checks pass, 1 = first failure stops execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT

LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck source=lib/check-bash-syntax.sh
source "${LIB_DIR}/check-bash-syntax.sh"
# shellcheck source=lib/check-secrets.sh
source "${LIB_DIR}/check-secrets.sh"

printf '=== Pre-Commit Checks ===\n\n'

printf '[1/2] Bash syntax check\n'
if ! run_check_bash_syntax; then
  printf '\n\xe2\x9c\x97 Pre-commit FAILED at: bash syntax check\n'
  exit 1
fi

printf '\n[2/2] Secret detection\n'
if ! run_check_secrets; then
  printf '\n\xe2\x9c\x97 Pre-commit FAILED at: secret detection\n'
  exit 1
fi

printf '\n\xe2\x9c\x93 All pre-commit checks passed\n'
exit 0
