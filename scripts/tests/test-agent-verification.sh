#!/usr/bin/env bash
# test-agent-verification.sh --- Tests for agent completion verification
#
# Validates:
#   - Role detection from agent prompts
#   - verify_implementor checks (Implementation Log + commits)
#   - verify_verifier checks (attestation file + 5 fields)
#   - verify_chronologist checks (plan file modification)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
HOOKS_LIB_DIR="${SCRIPT_DIR}/../hooks/lib"

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

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (expected: %s, got: %s)\n' "$desc" "$expected" "$actual"
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

assert_valid_json() {
  local desc="$1" json_str="$2"
  TOTAL=$((TOTAL + 1))
  if printf '%s' "$json_str" | jq empty 2>/dev/null; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (invalid JSON: %s)\n' "$desc" "$json_str"
  fi
}

assert_json_field() {
  local desc="$1" json_str="$2" field="$3" expected="$4"
  TOTAL=$((TOTAL + 1))
  local actual
  actual=$(printf '%s' "$json_str" | jq -r "$field" 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (field %s: expected %s, got %s)\n' "$desc" "$field" "$expected" "$actual"
  fi
}

# Require jq for tests
if ! command -v jq >/dev/null 2>&1; then
  printf 'SKIP: jq not available, cannot run tests\n'
  exit 0
fi

# Source the libraries
# shellcheck source=../lib/result.sh
source "${LIB_DIR}/result.sh"
# shellcheck source=../hooks/lib/verify-implementor.sh
source "${HOOKS_LIB_DIR}/verify-implementor.sh"
# shellcheck source=../hooks/lib/verify-verifier.sh
source "${HOOKS_LIB_DIR}/verify-verifier.sh"
# shellcheck source=../hooks/lib/verify-chronologist.sh
source "${HOOKS_LIB_DIR}/verify-chronologist.sh"

# ---------------------------------------------------------------------------
# Role detection function (copied from subagent-stop.sh for unit testing)
# ---------------------------------------------------------------------------
detect_role() {
  local prompt="$1"
  local prompt_lower
  prompt_lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$prompt_lower" | grep -qE '(implementor|worktree.*tdd|tdd.*worktree)'; then
    printf 'implementor'
  elif printf '%s' "$prompt_lower" | grep -qE '(verifier|verify.*checklist|verification.*checklist)'; then
    printf 'verifier'
  elif printf '%s' "$prompt_lower" | grep -qE '(chronologist|implementation.log.*write|write.*implementation.log)'; then
    printf 'chronologist'
  else
    printf 'pass-through'
  fi
}

# ============================================================
# Role Detection Tests
# ============================================================
printf '=== Role Detection Tests ===\n'

result=$(detect_role "You are the Implementor agent")
assert_equals "detect Implementor from explicit prompt" "implementor" "$result"

result=$(detect_role "Run TDD in worktree /tmp/wt-1234")
assert_equals "detect Implementor from worktree+tdd" "implementor" "$result"

result=$(detect_role "Use worktree isolation for TDD cycle")
assert_equals "detect Implementor from worktree...tdd" "implementor" "$result"

result=$(detect_role "Verifier: validate Phase 1")
assert_equals "detect Verifier from explicit prompt" "verifier" "$result"

result=$(detect_role "Please verify the checklist items")
assert_equals "detect Verifier from verify+checklist" "verifier" "$result"

result=$(detect_role "Run the verification checklist against worktree")
assert_equals "detect Verifier from verification+checklist" "verifier" "$result"

result=$(detect_role "Chronologist: log Phase 1")
assert_equals "detect Chronologist from explicit prompt" "chronologist" "$result"

result=$(detect_role "Write to the Implementation Log in the plan file")
assert_equals "detect Chronologist from implementation.log+write" "chronologist" "$result"

result=$(detect_role "Append the implementation.log section and write it")
assert_equals "detect Chronologist from write+implementation.log" "chronologist" "$result"

result=$(detect_role "Research the codebase")
assert_equals "detect pass-through from generic prompt" "pass-through" "$result"

result=$(detect_role "")
assert_equals "detect pass-through from empty prompt" "pass-through" "$result"

result=$(detect_role "IMPLEMENTOR AGENT: run tests")
assert_equals "detect Implementor case-insensitive" "implementor" "$result"

result=$(detect_role "VERIFIER: check all items")
assert_equals "detect Verifier case-insensitive" "verifier" "$result"

# ============================================================
# verify_implementor Tests
# ============================================================
printf '\n=== verify_implementor Tests ===\n'

# Setup: Plan file WITH Implementation Log
plan_with_log="$TMPDIR_TEST/plan-with-log.md"
cat > "$plan_with_log" << 'PLAN'
# Plan: Test Feature

## Phases
- Phase 1: Setup

## Implementation Log

### Phase 1: Setup -- COMPLETE
PLAN

# Setup: Plan file WITHOUT Implementation Log
plan_without_log="$TMPDIR_TEST/plan-without-log.md"
cat > "$plan_without_log" << 'PLAN'
# Plan: Test Feature

## Phases
- Phase 1: Setup
PLAN

# Setup: Git repo with commits (simulated worktree)
worktree_with_commits="$TMPDIR_TEST/wt-commits"
mkdir -p "$worktree_with_commits"
git -C "$worktree_with_commits" init -b feature-branch --quiet
git -C "$worktree_with_commits" commit --allow-empty -m "initial" --quiet
git -C "$worktree_with_commits" branch main --quiet 2>/dev/null || true
git -C "$worktree_with_commits" commit --allow-empty -m "feature commit" --quiet

# Setup: Git repo without commits beyond main
worktree_no_commits="$TMPDIR_TEST/wt-no-commits"
mkdir -p "$worktree_no_commits"
git -C "$worktree_no_commits" init -b main --quiet
git -C "$worktree_no_commits" commit --allow-empty -m "initial" --quiet

# Test: Plan with log + worktree with commits -> success
rc=0
output=$(verify_implementor "$plan_with_log" "$worktree_with_commits") || rc=$?
assert_exit "implementor: plan with log + commits = success" 0 "$rc"
assert_valid_json "implementor: success output is JSON" "$output"
assert_json_field "implementor: success has checks_passed=true" "$output" ".data.checks_passed" "true"

# Test: Plan WITHOUT Implementation Log -> failure with CB-A003
rc=0
output=$(verify_implementor "$plan_without_log" "$worktree_with_commits") || rc=$?
assert_exit "implementor: plan without log = failure" 1 "$rc"
assert_valid_json "implementor: failure output is JSON" "$output"
assert_contains "implementor: failure contains CB-A003" "$output" "CB-A003"

# Test: No commits in worktree -> failure with CB-A001
rc=0
output=$(verify_implementor "$plan_with_log" "$worktree_no_commits") || rc=$?
assert_exit "implementor: no commits = failure" 1 "$rc"
assert_valid_json "implementor: no commits output is JSON" "$output"
assert_contains "implementor: no commits contains CB-A001" "$output" "CB-A001"

# Test: Both missing -> failure with both codes
rc=0
output=$(verify_implementor "$plan_without_log" "$worktree_no_commits") || rc=$?
assert_exit "implementor: both failures = failure" 1 "$rc"
assert_valid_json "implementor: both failures output is JSON" "$output"
assert_contains "implementor: both failures contains CB-A003" "$output" "CB-A003"
assert_contains "implementor: both failures contains CB-A001" "$output" "CB-A001"

# Test: Non-existent plan file -> success (no plan file to check)
rc=0
output=$(verify_implementor "$TMPDIR_TEST/nonexistent.md" "") || rc=$?
assert_exit "implementor: nonexistent plan = success (nothing to check)" 0 "$rc"

# Test: Empty plan file path -> success
rc=0
output=$(verify_implementor "" "") || rc=$?
assert_exit "implementor: empty plan path = success" 0 "$rc"

# ============================================================
# verify_verifier Tests
# ============================================================
printf '\n=== verify_verifier Tests ===\n'

# Setup: project dir with cache
verifier_project="$TMPDIR_TEST/verifier-project"
mkdir -p "$verifier_project/.claude/cache"

# Setup: Valid attestation (all true)
plan_id_valid="plan-001"
cat > "$verifier_project/.claude/cache/verifier-attestation-${plan_id_valid}.json" << 'JSON'
{
  "plan_id": "plan-001",
  "phase": "Phase 1",
  "timestamp": "2026-04-01T12:00:00Z",
  "build_passed": true,
  "tests_passed": true,
  "guardrails_clean": true,
  "coverage_met": true,
  "log_updated": true,
  "commit_sha": "abc123"
}
JSON

# Setup: Attestation with one false field
plan_id_partial="plan-002"
cat > "$verifier_project/.claude/cache/verifier-attestation-${plan_id_partial}.json" << 'JSON'
{
  "plan_id": "plan-002",
  "phase": "Phase 1",
  "timestamp": "2026-04-01T12:00:00Z",
  "build_passed": true,
  "tests_passed": true,
  "guardrails_clean": false,
  "coverage_met": true,
  "log_updated": true,
  "commit_sha": "def456"
}
JSON

# Test: Valid attestation -> success
rc=0
output=$(verify_verifier "$plan_id_valid" "$verifier_project") || rc=$?
assert_exit "verifier: all true = success" 0 "$rc"
assert_valid_json "verifier: success output is JSON" "$output"
assert_json_field "verifier: success has checks_passed=true" "$output" ".data.checks_passed" "true"

# Test: Partial attestation -> failure with CB-A002
rc=0
output=$(verify_verifier "$plan_id_partial" "$verifier_project") || rc=$?
assert_exit "verifier: partial = failure" 1 "$rc"
assert_contains "verifier: partial contains CB-A002" "$output" "CB-A002"

# Test: Missing attestation file -> failure with CB-A002
rc=0
output=$(verify_verifier "plan-nonexistent" "$verifier_project") || rc=$?
assert_exit "verifier: missing file = failure" 1 "$rc"
assert_contains "verifier: missing file contains CB-A002" "$output" "CB-A002"

# ============================================================
# verify_chronologist Tests
# ============================================================
printf '\n=== verify_chronologist Tests ===\n'

# Setup: Git repo for chronologist tests
chrono_repo="$TMPDIR_TEST/chrono-repo"
mkdir -p "$chrono_repo"
git -C "$chrono_repo" init --quiet
chrono_plan="$chrono_repo/plan.md"
printf '# Plan\n## Implementation Log\n' > "$chrono_plan"
git -C "$chrono_repo" add plan.md
git -C "$chrono_repo" commit -m "initial" --quiet

# Test: Plan file with unstaged modifications -> success
printf '\n### Phase 1\n' >> "$chrono_plan"
rc=0
output=$(cd "$chrono_repo" && verify_chronologist "$chrono_plan") || rc=$?
assert_exit "chronologist: modified plan = success" 0 "$rc"
assert_valid_json "chronologist: modified output is JSON" "$output"
assert_json_field "chronologist: modified has checks_passed=true" "$output" ".data.checks_passed" "true"

# Reset for next test
git -C "$chrono_repo" checkout -- plan.md 2>/dev/null || true

# Test: Plan file with staged modifications -> success
printf '\n### Phase 2\n' >> "$chrono_plan"
git -C "$chrono_repo" add plan.md
rc=0
output=$(cd "$chrono_repo" && verify_chronologist "$chrono_plan") || rc=$?
assert_exit "chronologist: staged plan = success" 0 "$rc"
assert_valid_json "chronologist: staged output is JSON" "$output"
assert_json_field "chronologist: staged has checks_passed=true" "$output" ".data.checks_passed" "true"

# Reset for next test
git -C "$chrono_repo" reset HEAD -- plan.md --quiet 2>/dev/null || true
git -C "$chrono_repo" checkout -- plan.md 2>/dev/null || true

# Test: Plan file NOT modified -> success with note (non-blocking)
rc=0
output=$(cd "$chrono_repo" && verify_chronologist "$chrono_plan") || rc=$?
assert_exit "chronologist: unmodified plan = success (non-blocking)" 0 "$rc"
assert_valid_json "chronologist: unmodified output is JSON" "$output"
assert_json_field "chronologist: unmodified has note" "$output" ".data.note" "plan file not modified"

# Test: No plan file -> success with note
rc=0
output=$(verify_chronologist "$TMPDIR_TEST/nonexistent.md") || rc=$?
assert_exit "chronologist: nonexistent plan = success" 0 "$rc"
assert_valid_json "chronologist: nonexistent output is JSON" "$output"
assert_json_field "chronologist: nonexistent has note" "$output" ".data.note" "no plan file to verify"

# Test: Empty plan file path -> success with note
rc=0
output=$(verify_chronologist "") || rc=$?
assert_exit "chronologist: empty path = success" 0 "$rc"
assert_valid_json "chronologist: empty path output is JSON" "$output"

# ============================================================
# Summary
# ============================================================
printf '\n=== Results ===\n'
printf 'Total: %d  Passed: %d  Failed: %d\n' "$TOTAL" "$PASS" "$FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
