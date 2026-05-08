#!/usr/bin/env bash
# test-pre-commit-hooks.sh — Fixture-based tests for pre-commit hook modules
#
# Tests:
#   - commit-msg.sh: conventional commit validation
#   - check-secrets.sh: hardcoded secret detection
#   - check-bash-syntax.sh: shell script syntax validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
LIB_DIR="${HOOKS_DIR}/lib"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0
TOTAL=0

assert_exit() {
  local desc="$1" expected_exit="$2" actual_exit="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected_exit" -eq "$actual_exit" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (expected exit %d, got %d)\n' "$desc" "$expected_exit" "$actual_exit"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (output does not contain: %s)\n' "$desc" "$needle"
  fi
}

# ============================================================
# commit-msg.sh tests
# ============================================================
printf '=== commit-msg.sh Tests ===\n'

run_commit_msg() {
  local msg="$1"
  local tmpfile="${TMPDIR_TEST}/commit-msg-$$"
  printf '%s\n' "$msg" > "$tmpfile"
  local rc=0
  bash "$HOOKS_DIR/commit-msg.sh" "$tmpfile" > /dev/null 2>&1 || rc=$?
  rm -f "$tmpfile"
  return "$rc"
}

# Valid messages
rc=0; run_commit_msg "feat: add login" || rc=$?
assert_exit "valid: feat: add login" 0 "$rc"

rc=0; run_commit_msg "fix(auth): resolve token bug" || rc=$?
assert_exit "valid: fix(auth): resolve token bug" 0 "$rc"

rc=0; run_commit_msg "feat!: breaking change" || rc=$?
assert_exit "valid: feat!: breaking change" 0 "$rc"

rc=0; run_commit_msg "Merge branch 'main'" || rc=$?
assert_exit "valid: Merge branch 'main'" 0 "$rc"

rc=0; run_commit_msg "Revert \"feat: add login\"" || rc=$?
assert_exit "valid: Revert commit" 0 "$rc"

rc=0
MSG_WITH_COAUTHOR="$(printf 'feat: add login\n\nCo-Authored-By: Bot <bot@test.com>')"
run_commit_msg "$MSG_WITH_COAUTHOR" || rc=$?
assert_exit "valid: message with Co-Authored-By" 0 "$rc"

# Invalid messages
rc=0; run_commit_msg "Add login feature" || rc=$?
assert_exit "invalid: no type prefix" 1 "$rc"

rc=0; run_commit_msg "feat: " || rc=$?
assert_exit "invalid: empty subject after type" 1 "$rc"

rc=0; run_commit_msg "feat: A capitalized subject" || rc=$?
assert_exit "invalid: capitalized subject" 1 "$rc"

rc=0; run_commit_msg "unknown: some message" || rc=$?
assert_exit "invalid: unknown type" 1 "$rc"

rc=0; run_commit_msg "feat: this is a very long commit message that definitely exceeds the seventy-two character limit for subject lines" || rc=$?
assert_exit "invalid: exceeds 72 chars" 1 "$rc"

# ============================================================
# check-secrets.sh tests (using a temporary git repo)
# ============================================================
printf '\n=== check-secrets.sh Tests ===\n'

SECRETS_REPO="${TMPDIR_TEST}/secrets-repo"
mkdir -p "$SECRETS_REPO"
git -C "$SECRETS_REPO" init --quiet
git -C "$SECRETS_REPO" config user.email "test@test.com"
git -C "$SECRETS_REPO" config user.name "Test"

# Create initial commit so HEAD exists
printf 'init\n' > "${SECRETS_REPO}/init.txt"
git -C "$SECRETS_REPO" add init.txt
git -C "$SECRETS_REPO" commit -m "init" --quiet

# shellcheck source=../hooks/lib/check-secrets.sh
source "$LIB_DIR/check-secrets.sh"

# Test: AWS key detection
printf 'aws_key = AKIAIOSFODNN7EXAMPLE\n' > "${SECRETS_REPO}/config.py"
git -C "$SECRETS_REPO" add config.py
rc=0
output=$(cd "$SECRETS_REPO" && run_check_secrets 2>&1) || rc=$?
assert_exit "secrets: detect AWS key" 1 "$rc"
assert_contains "secrets: AWS key in output" "$output" "AWS key pattern"
git -C "$SECRETS_REPO" reset --quiet HEAD -- config.py
rm -f "${SECRETS_REPO}/config.py"

# Test: Generic secret detection
printf 'password = "mysecretpass"\n' > "${SECRETS_REPO}/app.py"
git -C "$SECRETS_REPO" add app.py
rc=0
output=$(cd "$SECRETS_REPO" && run_check_secrets 2>&1) || rc=$?
assert_exit "secrets: detect generic password" 1 "$rc"
assert_contains "secrets: generic secret in output" "$output" "generic secret pattern"
git -C "$SECRETS_REPO" reset --quiet HEAD -- app.py
rm -f "${SECRETS_REPO}/app.py"

# Test: GitHub token detection
printf 'token = ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij\n' > "${SECRETS_REPO}/auth.js"
git -C "$SECRETS_REPO" add auth.js
rc=0
output=$(cd "$SECRETS_REPO" && run_check_secrets 2>&1) || rc=$?
assert_exit "secrets: detect GitHub token" 1 "$rc"
assert_contains "secrets: GitHub token in output" "$output" "GitHub token pattern"
git -C "$SECRETS_REPO" reset --quiet HEAD -- auth.js
rm -f "${SECRETS_REPO}/auth.js"

# Test: Clean file passes
printf 'const name = "hello"\n' > "${SECRETS_REPO}/clean.js"
git -C "$SECRETS_REPO" add clean.js
rc=0
output=$(cd "$SECRETS_REPO" && run_check_secrets 2>&1) || rc=$?
assert_exit "secrets: clean file passes" 0 "$rc"
git -C "$SECRETS_REPO" reset --quiet HEAD -- clean.js
rm -f "${SECRETS_REPO}/clean.js"

# Test: Test files are skipped
printf 'password = "testfixture"\n' > "${SECRETS_REPO}/auth.test.js"
git -C "$SECRETS_REPO" add auth.test.js
rc=0
output=$(cd "$SECRETS_REPO" && run_check_secrets 2>&1) || rc=$?
assert_exit "secrets: test files skipped" 0 "$rc"
git -C "$SECRETS_REPO" reset --quiet HEAD -- auth.test.js
rm -f "${SECRETS_REPO}/auth.test.js"

# ============================================================
# check-bash-syntax.sh tests (using a temporary git repo)
# ============================================================
printf '\n=== check-bash-syntax.sh Tests ===\n'

SYNTAX_REPO="${TMPDIR_TEST}/syntax-repo"
mkdir -p "$SYNTAX_REPO"
git -C "$SYNTAX_REPO" init --quiet
git -C "$SYNTAX_REPO" config user.email "test@test.com"
git -C "$SYNTAX_REPO" config user.name "Test"

printf 'init\n' > "${SYNTAX_REPO}/init.txt"
git -C "$SYNTAX_REPO" add init.txt
git -C "$SYNTAX_REPO" commit -m "init" --quiet

# shellcheck source=../hooks/lib/check-bash-syntax.sh
source "$LIB_DIR/check-bash-syntax.sh"

# Test: Valid bash script
printf '#!/usr/bin/env bash\nset -euo pipefail\nif true; then\n  echo "ok"\nfi\n' > "${SYNTAX_REPO}/good.sh"
git -C "$SYNTAX_REPO" add good.sh
rc=0
output=$(cd "$SYNTAX_REPO" && run_check_bash_syntax 2>&1) || rc=$?
assert_exit "syntax: valid script passes" 0 "$rc"
git -C "$SYNTAX_REPO" reset --quiet HEAD -- good.sh
rm -f "${SYNTAX_REPO}/good.sh"

# Test: Script with syntax error (missing fi)
printf '#!/usr/bin/env bash\nif true; then\n  echo "broken"\n' > "${SYNTAX_REPO}/bad.sh"
git -C "$SYNTAX_REPO" add bad.sh
rc=0
output=$(cd "$SYNTAX_REPO" && run_check_bash_syntax 2>&1) || rc=$?
assert_exit "syntax: broken script fails" 1 "$rc"
assert_contains "syntax: error output mentions CB-H012" "$output" "[CB-H012]"
git -C "$SYNTAX_REPO" reset --quiet HEAD -- bad.sh
rm -f "${SYNTAX_REPO}/bad.sh"

# Test: No staged .sh files passes
rc=0
output=$(cd "$SYNTAX_REPO" && run_check_bash_syntax 2>&1) || rc=$?
assert_exit "syntax: no staged .sh files passes" 0 "$rc"

# ============================================================
# Summary
# ============================================================
printf '\n=== Results ===\n'
printf 'Total: %d  Passed: %d  Failed: %d\n' "$TOTAL" "$PASS" "$FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
