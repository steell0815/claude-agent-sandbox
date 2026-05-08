#!/usr/bin/env bash
# test-error-codes.sh --- Tests for error-codes.sh and result.sh
#
# Validates:
#   - All codes are unique (no duplicates)
#   - Every code has a non-empty message and recovery
#   - cb_error outputs valid JSON with required fields
#   - cb_error with file and line includes those fields
#   - cb_success / cb_failure produce correct envelopes
#   - Error collector workflow (init/add/flush) produces valid output
#   - cb_errors_flush_or_success returns correct envelope based on state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

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
# shellcheck source=../lib/error-codes.sh
source "${LIB_DIR}/error-codes.sh"
# shellcheck source=../lib/result.sh
source "${LIB_DIR}/result.sh"

# ============================================================
# error-codes.sh: Registry integrity
# ============================================================
printf '=== Error Code Registry Tests ===\n'

# Test: All codes are unique
TOTAL=$((TOTAL + 1))
unique_count=0
for code in "${_CB_CODES[@]}"; do
  match_count=0
  for other in "${_CB_CODES[@]}"; do
    if [[ "$code" == "$other" ]]; then
      match_count=$((match_count + 1))
    fi
  done
  if [[ "$match_count" -gt 1 ]]; then
    FAIL=$((FAIL + 1))
    printf '  FAIL: duplicate code: %s (found %d times)\n' "$code" "$match_count"
    unique_count=1
    break
  fi
done
if [[ "$unique_count" -eq 0 ]]; then
  PASS=$((PASS + 1))
  printf '  PASS: all codes are unique (%d codes)\n' "${#_CB_CODES[@]}"
fi

# Test: Every code has a non-empty message
all_messages_ok=1
for i in "${!_CB_CODES[@]}"; do
  if [[ -z "${_CB_MESSAGES[$i]}" ]]; then
    all_messages_ok=0
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    printf '  FAIL: code %s has empty message\n' "${_CB_CODES[$i]}"
  fi
done
TOTAL=$((TOTAL + 1))
if [[ "$all_messages_ok" -eq 1 ]]; then
  PASS=$((PASS + 1))
  printf '  PASS: all codes have non-empty messages\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: some codes have empty messages\n'
fi

# Test: Every code has a non-empty recovery
all_recoveries_ok=1
for i in "${!_CB_CODES[@]}"; do
  if [[ -z "${_CB_RECOVERIES[$i]}" ]]; then
    all_recoveries_ok=0
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    printf '  FAIL: code %s has empty recovery\n' "${_CB_CODES[$i]}"
  fi
done
TOTAL=$((TOTAL + 1))
if [[ "$all_recoveries_ok" -eq 1 ]]; then
  PASS=$((PASS + 1))
  printf '  PASS: all codes have non-empty recoveries\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: some codes have empty recoveries\n'
fi

# Test: Expected code count (40 codes: 8 hook + 5 script + 21 guardrail + 5 plan + 4 agent = 43)
assert_equals "registry has 43 codes" "43" "${#_CB_CODES[@]}"

# ============================================================
# error-codes.sh: Lookup functions
# ============================================================
printf '\n=== Lookup Function Tests ===\n'

# Test: cb_message returns correct message
output=$(cb_message "CB-H011")
assert_equals "cb_message CB-H011" "Secret detected in staged files" "$output"

output=$(cb_message "CB-G001")
assert_equals "cb_message CB-G001" "IF-01: Framework import in domain center" "$output"

output=$(cb_message "CB-P001")
assert_equals "cb_message CB-P001" "Plan index file not found" "$output"

output=$(cb_message "CB-A001")
assert_equals "cb_message CB-A001" "Implementor did not signal completion" "$output"

# Test: cb_recovery returns correct recovery
output=$(cb_recovery "CB-H011")
assert_equals "cb_recovery CB-H011" "Remove the secret and use an environment variable instead" "$output"

output=$(cb_recovery "CB-S010")
assert_equals "cb_recovery CB-S010" "Install jq: brew install jq (macOS) or apt install jq (Linux)" "$output"

# Test: cb_message with unknown code fails
rc=0
cb_message "CB-Z999" > /dev/null 2>&1 || rc=$?
assert_exit "cb_message unknown code fails" 1 "$rc"

# Test: cb_recovery with unknown code fails
rc=0
cb_recovery "CB-Z999" > /dev/null 2>&1 || rc=$?
assert_exit "cb_recovery unknown code fails" 1 "$rc"

# ============================================================
# error-codes.sh: JSON output
# ============================================================
printf '\n=== JSON Output Tests ===\n'

# Test: cb_error outputs valid JSON
output=$(cb_error "CB-H011")
assert_valid_json "cb_error produces valid JSON" "$output"

# Test: cb_error includes required fields
assert_json_field "cb_error has code field" "$output" ".code" "CB-H011"
assert_json_field "cb_error has message field" "$output" ".message" "Secret detected in staged files"
assert_json_field "cb_error has recovery field" "$output" ".recovery" "Remove the secret and use an environment variable instead"

# Test: cb_error without file/line omits those fields
file_field=$(printf '%s' "$output" | jq 'has("file")' 2>/dev/null)
assert_equals "cb_error without file omits file field" "false" "$file_field"

line_field=$(printf '%s' "$output" | jq 'has("line")' 2>/dev/null)
assert_equals "cb_error without line omits line field" "false" "$line_field"

# Test: cb_error with file and line includes those fields
output=$(cb_error "CB-H011" "src/config.ts" "42")
assert_valid_json "cb_error with file/line produces valid JSON" "$output"
assert_json_field "cb_error has file field" "$output" ".file" "src/config.ts"
assert_json_field "cb_error has line as number" "$output" ".line" "42"

# Test: cb_error_stderr writes to stderr
stderr_output=$(cb_error_stderr "CB-S001" "missing.txt" 2>&1 1>/dev/null)
assert_valid_json "cb_error_stderr produces valid JSON on stderr" "$stderr_output"
assert_json_field "cb_error_stderr has code field" "$stderr_output" ".code" "CB-S001"

# Test: cb_error with unknown code still produces JSON (with error indication)
rc=0
output=$(cb_error "CB-Z999" 2>/dev/null) || rc=$?
assert_exit "cb_error unknown code returns non-zero" 1 "$rc"
assert_valid_json "cb_error unknown code still produces JSON" "$output"

# ============================================================
# result.sh: Envelope wrappers
# ============================================================
printf '\n=== Result Envelope Tests ===\n'

# Test: cb_success wraps data
output=$(cb_success '{"plans":[1,2,3]}')
assert_valid_json "cb_success produces valid JSON" "$output"
assert_json_field "cb_success has success=true" "$output" ".success" "true"
assert_json_field "cb_success wraps data" "$output" ".data.plans[0]" "1"

# Test: cb_success with simple value
output=$(cb_success '"hello"')
assert_valid_json "cb_success with string produces valid JSON" "$output"
assert_json_field "cb_success string has success=true" "$output" ".success" "true"
assert_json_field "cb_success string wraps data" "$output" ".data" "hello"

# Test: cb_failure wraps errors
error_json=$(cb_error "CB-P001")
output=$(cb_failure "[${error_json}]")
assert_valid_json "cb_failure produces valid JSON" "$output"
assert_json_field "cb_failure has success=false" "$output" ".success" "false"
assert_json_field "cb_failure has errors array" "$output" ".errors[0].code" "CB-P001"

# ============================================================
# result.sh: Error collector workflow
# ============================================================
printf '\n=== Error Collector Tests ===\n'

# Test: cb_errors_init creates temp file
errors_file=$(cb_errors_init)
TOTAL=$((TOTAL + 1))
if [[ -f "$errors_file" ]]; then
  PASS=$((PASS + 1))
  printf '  PASS: cb_errors_init creates temp file\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: cb_errors_init did not create file: %s\n' "$errors_file"
fi

# Test: cb_errors_any returns 1 (false) when empty
rc=0
cb_errors_any "$errors_file" || rc=$?
assert_exit "cb_errors_any returns 1 when empty" 1 "$rc"

# Test: cb_errors_add adds error
cb_errors_add "$errors_file" "CB-H011" "src/config.ts" "42"

rc=0
cb_errors_any "$errors_file" || rc=$?
assert_exit "cb_errors_any returns 0 after add" 0 "$rc"

# Test: Add a second error
cb_errors_add "$errors_file" "CB-S001" "missing.txt"

# Test: cb_errors_flush produces valid failure envelope
output=$(cb_errors_flush "$errors_file")
assert_valid_json "cb_errors_flush produces valid JSON" "$output"
assert_json_field "cb_errors_flush has success=false" "$output" ".success" "false"

errors_count=$(printf '%s' "$output" | jq '.errors | length' 2>/dev/null)
assert_equals "cb_errors_flush has 2 errors" "2" "$errors_count"
assert_json_field "cb_errors_flush first error code" "$output" ".errors[0].code" "CB-H011"
assert_json_field "cb_errors_flush second error code" "$output" ".errors[1].code" "CB-S001"

# Test: cb_errors_flush cleans up temp file
TOTAL=$((TOTAL + 1))
if [[ ! -f "$errors_file" ]]; then
  PASS=$((PASS + 1))
  printf '  PASS: cb_errors_flush removed temp file\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: cb_errors_flush did not remove temp file\n'
  rm -f "$errors_file"
fi

# ============================================================
# result.sh: cb_errors_flush_or_success
# ============================================================
printf '\n=== Flush-or-Success Tests ===\n'

# Test: Returns success when no errors
errors_file=$(cb_errors_init)
output=$(cb_errors_flush_or_success "$errors_file" '{"status":"ok"}')
assert_valid_json "flush_or_success (empty) produces valid JSON" "$output"
assert_json_field "flush_or_success (empty) has success=true" "$output" ".success" "true"
assert_json_field "flush_or_success (empty) has data" "$output" ".data.status" "ok"

# Test: Returns failure when errors exist
errors_file=$(cb_errors_init)
cb_errors_add "$errors_file" "CB-P002" "" ""
output=$(cb_errors_flush_or_success "$errors_file" '{"status":"ok"}')
assert_valid_json "flush_or_success (errors) produces valid JSON" "$output"
assert_json_field "flush_or_success (errors) has success=false" "$output" ".success" "false"
assert_json_field "flush_or_success (errors) has error code" "$output" ".errors[0].code" "CB-P002"

# ============================================================
# Summary
# ============================================================
printf '\n=== Results ===\n'
printf 'Total: %d  Passed: %d  Failed: %d\n' "$TOTAL" "$PASS" "$FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
