#!/usr/bin/env bash
# test-readiness-scoring.sh — Tests for readiness scoring scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $test_name"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $test_name"
    echo "  Expected to contain: $needle"
    echo "  Actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== calculate-readiness-composite.sh ==="

# Test: known geometric mean
result=$("$SCRIPTS_DIR/calculate-readiness-composite.sh" 3 2 2 2 1 3 1 2)
assert_contains "composite value for 3 2 2 2 1 3 1 2" '"composite": 1.86' "$result"
assert_contains "band for 3 2 2 2 1 3 1 2" '"band": "BLUE"' "$result"
assert_contains "label for 3 2 2 2 1 3 1 2" '"label": "Manageable"' "$result"

# Test: all 1s → GREEN
result=$("$SCRIPTS_DIR/calculate-readiness-composite.sh" 1 1 1 1 1 1 1 1)
assert_contains "all 1s composite" '"composite": 1.00' "$result"
assert_contains "all 1s band" '"band": "GREEN"' "$result"
assert_contains "all 1s label" '"label": "Straightforward"' "$result"

# Test: all 5s → RED
result=$("$SCRIPTS_DIR/calculate-readiness-composite.sh" 5 5 5 5 5 5 5 5)
assert_contains "all 5s composite" '"composite": 5.00' "$result"
assert_contains "all 5s band" '"band": "RED"' "$result"
assert_contains "all 5s label" '"label": "Extreme"' "$result"

# Test: all 3s → YELLOW (3.00)
result=$("$SCRIPTS_DIR/calculate-readiness-composite.sh" 3 3 3 3 3 3 3 3)
assert_contains "all 3s composite" '"composite": 3.00' "$result"
assert_contains "all 3s band" '"band": "YELLOW"' "$result"
assert_contains "all 3s label" '"label": "Complex"' "$result"

# Test: mixed scores producing ORANGE (geomean ~3.76)
result=$("$SCRIPTS_DIR/calculate-readiness-composite.sh" 4 4 4 4 3 4 3 4)
assert_contains "ORANGE band composite" '"composite": 3.72' "$result"
assert_contains "ORANGE band" '"band": "ORANGE"' "$result"
assert_contains "ORANGE label" '"label": "High complexity"' "$result"

echo ""
echo "=== get-readiness-band.sh ==="

# Test all 5 band boundaries
result=$("$SCRIPTS_DIR/get-readiness-band.sh" 1.00)
assert_eq "band 1.00 → GREEN" '{"band": "GREEN", "label": "Straightforward"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 1.70)
assert_eq "band 1.70 → GREEN" '{"band": "GREEN", "label": "Straightforward"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 1.80)
assert_eq "band 1.80 → BLUE" '{"band": "BLUE", "label": "Manageable"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 2.50)
assert_eq "band 2.50 → BLUE" '{"band": "BLUE", "label": "Manageable"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 2.60)
assert_eq "band 2.60 → YELLOW" '{"band": "YELLOW", "label": "Complex"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 3.50)
assert_eq "band 3.50 → YELLOW" '{"band": "YELLOW", "label": "Complex"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 3.60)
assert_eq "band 3.60 → ORANGE" '{"band": "ORANGE", "label": "High complexity"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 4.50)
assert_eq "band 4.50 → ORANGE" '{"band": "ORANGE", "label": "High complexity"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 4.60)
assert_eq "band 4.60 → RED" '{"band": "RED", "label": "Extreme"}' "$result"

result=$("$SCRIPTS_DIR/get-readiness-band.sh" 5.00)
assert_eq "band 5.00 → RED" '{"band": "RED", "label": "Extreme"}' "$result"

echo ""
echo "=== render-readiness-bar.sh ==="

# Test score 1 — no warning
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Cognitive Complexity" 1)
assert_eq "bar score 1" "Cognitive Complexity     1 ■□□□□" "$result"

# Test score 2
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Cognitive Complexity" 2)
assert_eq "bar score 2" "Cognitive Complexity     2 ■■□□□" "$result"

# Test score 3
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Cognitive Complexity" 3)
assert_eq "bar score 3" "Cognitive Complexity     3 ■■■□□" "$result"

# Test score 4 — has warning
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Cognitive Complexity" 4)
assert_eq "bar score 4 with warning" "Cognitive Complexity     4 ■■■■□  ⚠" "$result"

# Test score 5 — has warning
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Cognitive Complexity" 5)
assert_eq "bar score 5 with warning" "Cognitive Complexity     5 ■■■■■  ⚠" "$result"

# Test padding with short name
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "Risk" 2)
assert_eq "bar short name padding" "Risk                     2 ■■□□□" "$result"

# Test padding with long name (exactly 24 chars)
result=$("$SCRIPTS_DIR/render-readiness-bar.sh" "123456789012345678901234" 3)
assert_eq "bar exact 24 char name" "123456789012345678901234 3 ■■■□□" "$result"

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "TOTAL: $((PASS + FAIL))"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
