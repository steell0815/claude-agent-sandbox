#!/usr/bin/env bash
# test-parse-plan-markdown.sh — Tests for parse-plan-markdown.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="${SCRIPT_DIR}/../parse-plan-markdown.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0
ERRORS=()

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ERRORS+=("$test_name")
    FAIL=$((FAIL + 1))
  fi
}

assert_json_eq() {
  local test_name="$1" jq_filter="$2" expected="$3" json="$4"
  local actual
  actual=$(echo "$json" | jq -r "$jq_filter" 2>/dev/null) || actual="JQ_ERROR"
  assert_eq "$test_name" "$expected" "$actual"
}

echo "=== Test Suite: parse-plan-markdown.sh ==="
echo ""

# --- Minimal plan ---
echo "--- Fixture: minimal-plan.md ---"
OUTPUT=$("$PARSER" "${FIXTURES}/minimal-plan.md")

assert_json_eq "minimal: title" '.title' "Minimal Plan Title" "$OUTPUT"
assert_json_eq "minimal: goal contains text" '.goal' "This is a minimal plan with just a title and goal.
No status section, no assessment, no JIRA." "$OUTPUT"
assert_json_eq "minimal: stories is empty array" '.stories | length' "0" "$OUTPUT"
assert_json_eq "minimal: assessment is null" '.assessment' "null" "$OUTPUT"
assert_json_eq "minimal: jiraEpicKey is null" '.jiraEpicKey' "null" "$OUTPUT"

echo ""

# --- Plan with assessment ---
echo "--- Fixture: plan-with-assessment.md ---"
OUTPUT=$("$PARSER" "${FIXTURES}/plan-with-assessment.md")

assert_json_eq "assessment: title" '.title' "Full Featured Plan" "$OUTPUT"
assert_json_eq "assessment: goal" '.goal' "Extract algorithms into reusable shell scripts for token reduction." "$OUTPUT"
assert_json_eq "assessment: composite score" '.assessment.composite' "2.1" "$OUTPUT"
assert_json_eq "assessment: band" '.assessment.band' "BLUE" "$OUTPUT"
assert_json_eq "assessment: dimension count" '.assessment.dimensions | length' "8" "$OUTPUT"
assert_json_eq "assessment: first dimension name" '.assessment.dimensions[0].name' "Cognitive Complexity" "$OUTPUT"
assert_json_eq "assessment: first dimension score" '.assessment.dimensions[0].score' "3" "$OUTPUT"
assert_json_eq "assessment: dim 1 rationale" '.assessment.dimensions[0].rationale' "Four distinct algorithms — each well-defined with clear inputs/outputs" "$OUTPUT"
# Dimension 6 has a pipe in the rationale — verify correct parsing
assert_json_eq "assessment: dim with pipe in rationale" '.assessment.dimensions[5].rationale' "Three-way merge, geometric mean scoring — pipes | in rationale are tricky" "$OUTPUT"
assert_json_eq "assessment: story count" '.stories | length' "4" "$OUTPUT"
assert_json_eq "assessment: first story phase" '.stories[0].phase' "1" "$OUTPUT"
assert_json_eq "assessment: first story label" '.stories[0].label' "Setup project structure" "$OUTPUT"
assert_json_eq "assessment: first story jiraKey" '.stories[0].jiraKey' "PROJ-10" "$OUTPUT"
assert_json_eq "assessment: first story checked" '.stories[0].checked' "true" "$OUTPUT"
assert_json_eq "assessment: second story phase" '.stories[1].phase' "2a" "$OUTPUT"
assert_json_eq "assessment: second story label" '.stories[1].label' "Implement core parser" "$OUTPUT"
assert_json_eq "assessment: second story jiraKey" '.stories[1].jiraKey' "null" "$OUTPUT"
assert_json_eq "assessment: second story checked" '.stories[1].checked' "false" "$OUTPUT"
assert_json_eq "assessment: jiraEpicKey is null" '.jiraEpicKey' "null" "$OUTPUT"

echo ""

# --- Plan with JIRA ---
echo "--- Fixture: plan-with-jira.md ---"
OUTPUT=$("$PARSER" "${FIXTURES}/plan-with-jira.md")

assert_json_eq "jira: title" '.title' "JIRA-Linked Plan" "$OUTPUT"
assert_json_eq "jira: jiraEpicKey" '.jiraEpicKey' "PROJ-99" "$OUTPUT"
assert_json_eq "jira: story count" '.stories | length' "3" "$OUTPUT"
assert_json_eq "jira: story 1 jiraKey" '.stories[0].jiraKey' "PROJ-100" "$OUTPUT"
assert_json_eq "jira: story 1 checked" '.stories[0].checked' "true" "$OUTPUT"
assert_json_eq "jira: story 2 jiraKey" '.stories[1].jiraKey' "PROJ-101" "$OUTPUT"
assert_json_eq "jira: story 3 no jiraKey" '.stories[2].jiraKey' "null" "$OUTPUT"
assert_json_eq "jira: assessment is null" '.assessment' "null" "$OUTPUT"

echo ""

# --- Plan with nested checkboxes ---
echo "--- Fixture: plan-with-nested-checkboxes.md ---"
OUTPUT=$("$PARSER" "${FIXTURES}/plan-with-nested-checkboxes.md")

assert_json_eq "nested: title" '.title' "Decomposed Plan" "$OUTPUT"
# Top-level phases only (not sub-tasks)
assert_json_eq "nested: top-level story count" '.stories | length' "3" "$OUTPUT"
assert_json_eq "nested: phase 1 checked" '.stories[0].checked' "true" "$OUTPUT"
assert_json_eq "nested: phase 1 label" '.stories[0].label' "Foundation" "$OUTPUT"
assert_json_eq "nested: phase 1 jiraKey" '.stories[0].jiraKey' "PROJ-50" "$OUTPUT"
assert_json_eq "nested: phase 2 checked" '.stories[1].checked' "false" "$OUTPUT"
assert_json_eq "nested: phase 2 label" '.stories[1].label' "Implementation" "$OUTPUT"
assert_json_eq "nested: phase 3 checked" '.stories[2].checked' "false" "$OUTPUT"
assert_json_eq "nested: phase 3 label" '.stories[2].label' "Integration" "$OUTPUT"

# --- Plan with sub-phase JIRA keys ---
echo "--- Fixture: plan-with-subphase-jira.md ---"
OUTPUT=$("$PARSER" "${FIXTURES}/plan-with-subphase-jira.md")

assert_json_eq "subphase-jira: title" '.title' "Decomposed Plan with Sub-Phase JIRA Keys" "$OUTPUT"
assert_json_eq "subphase-jira: goal from Summary" '.goal' "A plan where JIRA keys are on sub-phase lines, not top-level phases." "$OUTPUT"
assert_json_eq "subphase-jira: jiraEpicKey from inline metadata" '.jiraEpicKey' "PROJ-200" "$OUTPUT"
# 5 sub-phase stories (1a, 1b, 2a, 2b) + 1 top-level with key (Phase 3)
assert_json_eq "subphase-jira: story count" '.stories | length' "5" "$OUTPUT"
assert_json_eq "subphase-jira: story 1 phase" '.stories[0].phase' "1a" "$OUTPUT"
assert_json_eq "subphase-jira: story 1 label" '.stories[0].label' "Value objects" "$OUTPUT"
assert_json_eq "subphase-jira: story 1 jiraKey" '.stories[0].jiraKey' "PROJ-201" "$OUTPUT"
assert_json_eq "subphase-jira: story 1 checked" '.stories[0].checked' "true" "$OUTPUT"
assert_json_eq "subphase-jira: story 2 jiraKey" '.stories[1].jiraKey' "PROJ-202" "$OUTPUT"
assert_json_eq "subphase-jira: story 2 checked" '.stories[1].checked' "false" "$OUTPUT"
assert_json_eq "subphase-jira: story 3 jiraKey" '.stories[2].jiraKey' "PROJ-203" "$OUTPUT"
assert_json_eq "subphase-jira: story 4 jiraKey" '.stories[3].jiraKey' "PROJ-204" "$OUTPUT"
assert_json_eq "subphase-jira: story 5 (top-level) jiraKey" '.stories[4].jiraKey' "PROJ-205" "$OUTPUT"
assert_json_eq "subphase-jira: story 5 (top-level) label" '.stories[4].label' "Stack trace sanitization" "$OUTPUT"
# Assessment with patterns and IO
assert_json_eq "subphase-jira: composite" '.assessment.composite' "1.71" "$OUTPUT"
assert_json_eq "subphase-jira: band" '.assessment.band' "BLUE" "$OUTPUT"
assert_json_eq "subphase-jira: patterns count" '.assessment.patterns | length' "3" "$OUTPUT"
assert_json_eq "subphase-jira: first pattern" '.assessment.patterns[0]' "Port/Adapter" "$OUTPUT"
assert_json_eq "subphase-jira: io count" '.assessment.io | length' "1" "$OUTPUT"
assert_json_eq "subphase-jira: first io" '.assessment.io[0]' "SLF4J/Logback" "$OUTPUT"
assert_json_eq "subphase-jira: verdict starts with band" '.assessment.verdict' "BLUE — Well-scoped library with established patterns." "$OUTPUT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi
