#!/usr/bin/env bash
# test-guardrails-v2.sh --- Tests for the pattern-file-driven guardrails v2 engine
#
# Validates:
#   - Pattern DSL parsing (RULE|GLOB|REGEX|MODE)
#   - Glob-to-regex file matching
#   - Blocking rules cause exit 1
#   - Advisory rules cause exit 0 with warnings
#   - Clean files cause exit 0 with no violations
#   - Stack auto-detection from project files
#   - Multiple violations collected in single run
#   - IF-01, IF-02, IF-09, IF-14, IF-18, IF-19, IF-20, IF-21 coverage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="${SCRIPT_DIR}/../guardrails/guardrails-check-v2.sh"

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

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (output unexpectedly contains: %s)\n' "$desc" "$needle"
  fi
}

assert_json_field() {
  local desc="$1" json_str="$2" field="$3" expected="$4"
  TOTAL=$((TOTAL + 1))
  if ! command -v jq >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  SKIP: %s (jq not available)\n' "$desc"
    return
  fi
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

assert_valid_json() {
  local desc="$1" json_str="$2"
  TOTAL=$((TOTAL + 1))
  if ! command -v jq >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  SKIP: %s (jq not available)\n' "$desc"
    return
  fi
  if printf '%s' "$json_str" | jq empty 2>/dev/null; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (invalid JSON)\n' "$desc"
  fi
}

# ---------------------------------------------------------------------------
# Setup: create temp project with fixtures
# ---------------------------------------------------------------------------

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Create project structure mirroring a scaffolded project
create_fixture_project() {
  local project_dir="$1"
  local stack="${2:-ts-node}"

  mkdir -p "${project_dir}/scripts/guardrails/patterns"
  mkdir -p "${project_dir}/scripts/lib"
  mkdir -p "${project_dir}/domain/entity"
  mkdir -p "${project_dir}/src/controllers"
  mkdir -p "${project_dir}/src/services"
  mkdir -p "${project_dir}/test"

  # Copy engine and patterns
  cp "${ENGINE}" "${project_dir}/scripts/guardrails/"
  cp "${SCRIPT_DIR}/../guardrails/patterns/common.patterns" "${project_dir}/scripts/guardrails/patterns/"
  if [[ "$stack" == "ts-node" ]]; then
    cp "${SCRIPT_DIR}/../guardrails/patterns/ts-node.patterns" "${project_dir}/scripts/guardrails/patterns/"
  elif [[ "$stack" == "java-spring" ]]; then
    cp "${SCRIPT_DIR}/../guardrails/patterns/java-spring.patterns" "${project_dir}/scripts/guardrails/patterns/"
  fi

  # Copy lib files
  cp "${SCRIPT_DIR}/../lib/error-codes.sh" "${project_dir}/scripts/lib/"
  cp "${SCRIPT_DIR}/../lib/result.sh" "${project_dir}/scripts/lib/"

  # Stack indicator file
  if [[ "$stack" == "ts-node" ]]; then
    echo '{"name":"test-project"}' > "${project_dir}/package.json"
  elif [[ "$stack" == "java-spring" ]]; then
    echo '<project></project>' > "${project_dir}/pom.xml"
  fi

  # Initialize git repo for the fixture
  git -C "$project_dir" init -q
  git -C "$project_dir" config user.email "test@test.com"
  git -C "$project_dir" config user.name "Test"
  # Initial commit so git diff works
  git -C "$project_dir" add -A
  git -C "$project_dir" commit -q -m "init"
}

# Helper to run v2 engine against a fixture project with specific files
run_v2() {
  local project_dir="$1"
  shift
  PROJECT_ROOT="$project_dir" "${project_dir}/scripts/guardrails/guardrails-check-v2.sh" "$@"
}

# Helper to create a file, stage it, and run the engine
run_v2_with_staged_file() {
  local project_dir="$1"
  local filepath="$2"
  local content="$3"
  shift 3

  local dir
  dir="$(dirname "${project_dir}/${filepath}")"
  mkdir -p "$dir"
  printf '%s\n' "$content" > "${project_dir}/${filepath}"
  git -C "$project_dir" add "${filepath}"

  run_v2 "$project_dir" --scope staged "$@"
}

# ============================================================
printf '=== Guardrails V2 Engine Tests ===\n\n'

# ============================================================
# Test 1: Clean project — no violations
# ============================================================
printf '\n--- Clean Files ---\n'

PROJ1="${TMPDIR_TEST}/proj-clean"
create_fixture_project "$PROJ1" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ1" "src/services/calc.ts" \
  'export function add(a: number, b: number): number { return a + b; }' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "clean file passes" 0 "$rc"
assert_valid_json "clean file output is valid JSON" "$output"
assert_json_field "clean file has success=true" "$output" ".success" "true"

# ============================================================
# Test 2: IF-14 — Hardcoded secrets (blocking)
# ============================================================
printf '\n--- IF-14: Hardcoded Secrets ---\n'

PROJ2="${TMPDIR_TEST}/proj-secrets"
create_fixture_project "$PROJ2" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ2" "src/services/auth.ts" \
  'const password = "SuperSecret123456";' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-14 hardcoded password blocks" 1 "$rc"
assert_contains "IF-14 reports CB-G014" "$output" "CB-G014"
assert_valid_json "IF-14 output is valid JSON" "$output"

# ============================================================
# Test 3: IF-14 — AWS access key detection
# ============================================================
printf '\n--- IF-14: AWS Key ---\n'

PROJ3="${TMPDIR_TEST}/proj-aws"
create_fixture_project "$PROJ3" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ3" "src/services/config.ts" \
  'const awsKey = "AKIAIOSFODNN7EXAMPLE";' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-14 AWS key blocks" 1 "$rc"
assert_contains "IF-14 reports CB-G014 for AWS key" "$output" "CB-G014"

# ============================================================
# Test 4: IF-01 — Framework import in domain (TypeScript)
# ============================================================
printf '\n--- IF-01: Domain Framework Import (TS) ---\n'

PROJ4="${TMPDIR_TEST}/proj-domain-import"
create_fixture_project "$PROJ4" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ4" "domain/entity/user.ts" \
  "import { Injectable } from '@nestjs/common';" \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-01 domain framework import blocks" 1 "$rc"
assert_contains "IF-01 reports CB-G001" "$output" "CB-G001"

# ============================================================
# Test 5: IF-01 — Clean domain file passes
# ============================================================
printf '\n--- IF-01: Clean Domain File ---\n'

PROJ5="${TMPDIR_TEST}/proj-domain-clean"
create_fixture_project "$PROJ5" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ5" "domain/entity/user.ts" \
  'export class User { constructor(public readonly id: string, public readonly name: string) {} }' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "clean domain file passes" 0 "$rc"

# ============================================================
# Test 6: IF-02 — SQL string concatenation
# ============================================================
printf '\n--- IF-02: SQL Concatenation ---\n'

PROJ6="${TMPDIR_TEST}/proj-sql-concat"
create_fixture_project "$PROJ6" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ6" "src/services/repo.ts" \
  "const query = \"SELECT * FROM users WHERE id = \" + userId;" \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-02 SQL concatenation blocks" 1 "$rc"
assert_contains "IF-02 reports CB-G002" "$output" "CB-G002"

# ============================================================
# Test 7: IF-09 — Skipped tests
# ============================================================
printf '\n--- IF-09: Skipped Tests ---\n'

PROJ7="${TMPDIR_TEST}/proj-skip-test"
create_fixture_project "$PROJ7" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ7" "test/user.test.ts" \
  'it.skip("should create user", () => { });' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-09 skipped test blocks" 1 "$rc"
assert_contains "IF-09 reports CB-G009" "$output" "CB-G009"

# ============================================================
# Test 8: IF-18 — Console.log in production code
# ============================================================
printf '\n--- IF-18: Console Output ---\n'

PROJ8="${TMPDIR_TEST}/proj-console"
create_fixture_project "$PROJ8" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ8" "src/services/handler.ts" \
  'console.log("debugging something");' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-18 console.log in src blocks" 1 "$rc"
assert_contains "IF-18 reports CB-G018" "$output" "CB-G018"

# ============================================================
# Test 9: IF-19 — Generic catch block
# ============================================================
printf '\n--- IF-19: Generic Catch ---\n'

PROJ9="${TMPDIR_TEST}/proj-catch"
create_fixture_project "$PROJ9" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ9" "src/services/handler.ts" \
  'try { doSomething(); } catch (err) { handleError(err); }' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-19 generic catch blocks" 1 "$rc"
assert_contains "IF-19 reports CB-G019" "$output" "CB-G019"

# ============================================================
# Test 10: IF-20 — Empty catch block
# ============================================================
printf '\n--- IF-20: Empty Catch ---\n'

PROJ10="${TMPDIR_TEST}/proj-empty-catch"
create_fixture_project "$PROJ10" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ10" "src/services/handler.ts" \
  'try { doSomething(); } catch (err) {}' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-20 empty catch blocks" 1 "$rc"
assert_contains "IF-20 reports CB-G020" "$output" "CB-G020"

# ============================================================
# Test 11: IF-21 — TODO markers
# ============================================================
printf '\n--- IF-21: TODO Markers ---\n'

PROJ11="${TMPDIR_TEST}/proj-todo"
create_fixture_project "$PROJ11" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ11" "src/services/handler.ts" \
  '// TODO fix this later' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-21 TODO marker blocks" 1 "$rc"
assert_contains "IF-21 reports CB-G021" "$output" "CB-G021"

# ============================================================
# Test 12: Advisory rules — exit 0 with warnings
# ============================================================
printf '\n--- Advisory Rules ---\n'

PROJ12="${TMPDIR_TEST}/proj-advisory"
create_fixture_project "$PROJ12" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ12" "src/controllers/UserController.ts" \
  'if (user.age > 18) { return "allowed"; }' \
  --stack ts-node 2>&1) || rc=$?

assert_exit "advisory rule does not block" 0 "$rc"
assert_valid_json "advisory output is valid JSON" "$output"
assert_json_field "advisory has success=true" "$output" ".success" "true"

# ============================================================
# Test 13: Multiple violations collected
# ============================================================
printf '\n--- Multiple Violations ---\n'

PROJ13="${TMPDIR_TEST}/proj-multi"
create_fixture_project "$PROJ13" "ts-node"

mkdir -p "${PROJ13}/src/services"
cat > "${PROJ13}/src/services/bad.ts" << 'FIXTURE'
const password = "SuperSecret123456";
console.log("debug info");
// TODO remove this
FIXTURE
git -C "$PROJ13" add src/services/bad.ts

rc=0
output=$(run_v2 "$PROJ13" --scope staged --stack ts-node 2>&1) || rc=$?

assert_exit "multiple violations block" 1 "$rc"
assert_contains "multiple violations include CB-G014" "$output" "CB-G014"
assert_contains "multiple violations include CB-G018" "$output" "CB-G018"
assert_contains "multiple violations include CB-G021" "$output" "CB-G021"

# Count errors in JSON
if command -v jq >/dev/null 2>&1; then
  error_count=$(printf '%s' "$output" | jq '.errors | length' 2>/dev/null || echo "0")
  TOTAL=$((TOTAL + 1))
  if [[ "$error_count" -ge 3 ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: multiple violations has >= 3 errors (%s)\n' "$error_count"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: multiple violations expected >= 3 errors, got %s\n' "$error_count"
  fi
fi

# ============================================================
# Test 14: Stack auto-detection — ts-node
# ============================================================
printf '\n--- Stack Auto-Detection ---\n'

PROJ14="${TMPDIR_TEST}/proj-autodetect-ts"
create_fixture_project "$PROJ14" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ14" "domain/entity/user.ts" \
  "import { Repository } from 'typeorm';" \
  --stack auto 2>&1) || rc=$?

assert_exit "auto-detect ts-node catches IF-01" 1 "$rc"
assert_contains "auto-detect ts-node reports CB-G001" "$output" "CB-G001"

# ============================================================
# Test 15: Stack auto-detection — java-spring
# ============================================================

PROJ15="${TMPDIR_TEST}/proj-autodetect-java"
create_fixture_project "$PROJ15" "java-spring"

rc=0
output=$(run_v2_with_staged_file "$PROJ15" "domain/entity/User.java" \
  'import org.springframework.stereotype.Component;' \
  --stack auto 2>&1) || rc=$?

assert_exit "auto-detect java-spring catches IF-01" 1 "$rc"
assert_contains "auto-detect java-spring reports CB-G001" "$output" "CB-G001"

# ============================================================
# Test 16: Java IF-09 — @Disabled test
# ============================================================
printf '\n--- Java IF-09: Disabled Tests ---\n'

PROJ16="${TMPDIR_TEST}/proj-java-disabled"
create_fixture_project "$PROJ16" "java-spring"

rc=0
output=$(run_v2_with_staged_file "$PROJ16" "test/UserTest.java" \
  '@Disabled public void testCreateUser() { }' \
  --stack java-spring 2>&1) || rc=$?

assert_exit "Java IF-09 @Disabled blocks" 1 "$rc"
assert_contains "Java IF-09 reports CB-G009" "$output" "CB-G009"

# ============================================================
# Test 17: Java IF-19 — Generic catch(Exception)
# ============================================================
printf '\n--- Java IF-19: Generic Catch ---\n'

PROJ17="${TMPDIR_TEST}/proj-java-catch"
create_fixture_project "$PROJ17" "java-spring"

rc=0
output=$(run_v2_with_staged_file "$PROJ17" "src/services/Handler.java" \
  'try { doSomething(); } catch (Exception e) { log(e); }' \
  --stack java-spring 2>&1) || rc=$?

assert_exit "Java IF-19 generic catch blocks" 1 "$rc"
assert_contains "Java IF-19 reports CB-G019" "$output" "CB-G019"

# ============================================================
# Test 18: No changed files — clean exit
# ============================================================
printf '\n--- No Changed Files ---\n'

PROJ18="${TMPDIR_TEST}/proj-nochange"
create_fixture_project "$PROJ18" "ts-node"

rc=0
output=$(run_v2 "$PROJ18" --scope staged --stack ts-node 2>&1) || rc=$?

assert_exit "no changed files passes" 0 "$rc"
assert_valid_json "no changed files output is valid JSON" "$output"
assert_json_field "no changed files has success=true" "$output" ".success" "true"

# ============================================================
# Test 19: IF-13 — DB driver import in domain
# ============================================================
printf '\n--- IF-13: DB Driver in Domain ---\n'

PROJ19="${TMPDIR_TEST}/proj-db-domain"
create_fixture_project "$PROJ19" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ19" "domain/entity/repo.ts" \
  "import { Pool } from 'pg';" \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-13 DB driver in domain blocks" 1 "$rc"
assert_contains "IF-13 reports CB-G013" "$output" "CB-G013"

# ============================================================
# Test 20: IF-15 — Route without /api/ prefix
# ============================================================
printf '\n--- IF-15: Missing /api/ Prefix ---\n'

PROJ20="${TMPDIR_TEST}/proj-route"
create_fixture_project "$PROJ20" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ20" "src/controllers/router.ts" \
  "router.get('/users', handler);" \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-15 missing /api/ prefix blocks" 1 "$rc"
assert_contains "IF-15 reports CB-G015" "$output" "CB-G015"

# ============================================================
# Test 21: IF-15 — Route with /api/ prefix passes
# ============================================================
printf '\n--- IF-15: With /api/ Prefix ---\n'

PROJ21="${TMPDIR_TEST}/proj-route-ok"
create_fixture_project "$PROJ21" "ts-node"

rc=0
output=$(run_v2_with_staged_file "$PROJ21" "src/controllers/router.ts" \
  "router.get('/api/users', handler);" \
  --stack ts-node 2>&1) || rc=$?

assert_exit "IF-15 with /api/ prefix passes" 0 "$rc"

# ============================================================
# Test 22: Result envelope structure
# ============================================================
printf '\n--- Result Envelope Structure ---\n'

if command -v jq >/dev/null 2>&1; then
  PROJ22="${TMPDIR_TEST}/proj-envelope"
  create_fixture_project "$PROJ22" "ts-node"

  output=$(run_v2_with_staged_file "$PROJ22" "src/services/bad.ts" \
    'const api_key = "sk_live_1234567890abcdef";' \
    --stack ts-node 2>&1) || true

  assert_json_field "envelope has success field" "$output" ".success" "false"

  has_errors=$(printf '%s' "$output" | jq 'has("errors")' 2>/dev/null)
  TOTAL=$((TOTAL + 1))
  if [[ "$has_errors" == "true" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: envelope has errors array\n'
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: envelope missing errors array\n'
  fi

  has_warnings=$(printf '%s' "$output" | jq 'has("warnings")' 2>/dev/null)
  TOTAL=$((TOTAL + 1))
  if [[ "$has_warnings" == "true" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: envelope has warnings array\n'
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: envelope missing warnings array\n'
  fi

  # Check error object structure
  error_code=$(printf '%s' "$output" | jq -r '.errors[0].code' 2>/dev/null)
  TOTAL=$((TOTAL + 1))
  if [[ "$error_code" =~ ^CB-G[0-9]{3}$ ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: error code follows CB-G0xx format (%s)\n' "$error_code"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: error code format invalid: %s\n' "$error_code"
  fi

  has_file=$(printf '%s' "$output" | jq '.errors[0] | has("file")' 2>/dev/null)
  has_line=$(printf '%s' "$output" | jq '.errors[0] | has("line")' 2>/dev/null)
  has_recovery=$(printf '%s' "$output" | jq '.errors[0] | has("recovery")' 2>/dev/null)

  TOTAL=$((TOTAL + 1))
  if [[ "$has_file" == "true" ]] && [[ "$has_line" == "true" ]] && [[ "$has_recovery" == "true" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS: error object has file, line, and recovery fields\n'
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: error object missing file/line/recovery (file=%s line=%s recovery=%s)\n' \
      "$has_file" "$has_line" "$has_recovery"
  fi
fi

# ============================================================
# Summary
# ============================================================
printf '\n=== Results ===\n'
printf 'Total: %d  Passed: %d  Failed: %d\n' "$TOTAL" "$PASS" "$FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
