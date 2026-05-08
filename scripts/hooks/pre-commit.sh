#!/usr/bin/env bash
# pre-commit.sh — Orchestrator for pre-commit checks
#
# Runs check modules sequentially (fail-fast):
#   1. bash-syntax — validate staged .sh files
#   2. secrets     — detect hardcoded secrets in staged diff
#   3. guardrails  — check staged changes against guardrail rules
#
# Exit: 0 = all checks pass, 1 = first failure stops execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT

LIB_DIR="${SCRIPT_DIR}/lib"

# Source check modules (functions only, no execution on source)
# shellcheck source=lib/check-bash-syntax.sh
source "${LIB_DIR}/check-bash-syntax.sh"
# shellcheck source=lib/check-secrets.sh
source "${LIB_DIR}/check-secrets.sh"
# shellcheck source=lib/check-guardrails-staged.sh
source "${LIB_DIR}/check-guardrails-staged.sh"

printf '=== Pre-Commit Checks ===\n\n'

# Check 1: Bash syntax
printf '[1/3] Bash syntax check\n'
if ! run_check_bash_syntax; then
  printf '\n\xe2\x9c\x97 Pre-commit FAILED at: bash syntax check\n'
  exit 1
fi

# Check 2: Secrets detection
printf '\n[2/3] Secret detection\n'
if ! run_check_secrets; then
  printf '\n\xe2\x9c\x97 Pre-commit FAILED at: secret detection\n'
  exit 1
fi

# Check 3: Guardrails
printf '\n[3/3] Guardrails check\n'
if ! run_check_guardrails; then
  printf '\n\xe2\x9c\x97 Pre-commit FAILED at: guardrails check\n'
  exit 1
fi

printf '\n\xe2\x9c\x93 All pre-commit checks passed\n'
exit 0
