#!/usr/bin/env bash
# test-build-adf-description.sh — Tests for build-adf-description.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SCRIPT_DIR}/../build-adf-description.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0
ERRORS=""

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $test_name\n    expected: $expected\n    actual:   $actual"
    echo "  FAIL: $test_name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $test_name\n    expected to contain: $needle"
    echo "  FAIL: $test_name"
    echo "    expected to contain: $needle"
  fi
}

assert_not_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $test_name\n    should not contain: $needle"
    echo "  FAIL: $test_name"
    echo "    should not contain: $needle"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
  fi
}

# ─── Test 1: Minimal input produces valid ADF doc with context paragraph ───
echo "Test 1: Minimal input (title + goal only)"
OUTPUT=$(cat "${FIXTURES}/plan-data-minimal.json" | "$SUT")

# 1a: Output is valid JSON
echo "$OUTPUT" | jq . > /dev/null 2>&1
assert_eq "1a: output is valid JSON" "0" "$?"

# 1b: Top-level version=1
VERSION=$(echo "$OUTPUT" | jq '.version')
assert_eq "1b: version is 1" "1" "$VERSION"

# 1c: Top-level type=doc
DOC_TYPE=$(echo "$OUTPUT" | jq -r '.type')
assert_eq "1c: type is doc" "doc" "$DOC_TYPE"

# 1d: Content is an array
CONTENT_TYPE=$(echo "$OUTPUT" | jq -r '.content | type')
assert_eq "1d: content is array" "array" "$CONTENT_TYPE"

# 1e: Content has at least one element (context paragraph)
CONTENT_LEN=$(echo "$OUTPUT" | jq '.content | length')
assert_eq "1e: content has at least 1 element" "1" "$([ "$CONTENT_LEN" -ge 1 ] && echo 1 || echo 0)"

# 1f: First content node is a paragraph with goal text
FIRST_TYPE=$(echo "$OUTPUT" | jq -r '.content[0].type')
assert_eq "1f: first node is paragraph" "paragraph" "$FIRST_TYPE"

FIRST_TEXT=$(echo "$OUTPUT" | jq -r '.content[0].content[0].text')
assert_eq "1g: paragraph contains goal text" "A simple goal for testing." "$FIRST_TEXT"

# 1h: No stories table in minimal input
TABLE_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | length')
assert_eq "1h: no table in minimal input" "0" "$TABLE_COUNT"

# 1i: No heading (no assessment)
HEADING_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "heading")] | length')
assert_eq "1i: no heading in minimal input" "0" "$HEADING_COUNT"

# ─── Test 2: Input with stories produces table with lozenges ───
echo ""
echo "Test 2: Input with stories"
OUTPUT=$(cat "${FIXTURES}/plan-data-with-stories.json" | "$SUT")

# 2a: Valid JSON
echo "$OUTPUT" | jq . > /dev/null 2>&1
assert_eq "2a: output is valid JSON" "0" "$?"

# 2b: Contains a table
TABLE_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | length')
assert_eq "2b: contains a table" "1" "$TABLE_COUNT"

# 2c: Table has header row + 3 data rows = 4 rows
ROW_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0].content | length')
assert_eq "2c: table has 4 rows (1 header + 3 data)" "4" "$ROW_COUNT"

# 2d: Header row uses tableHeader cells
HEADER_CELL_TYPE=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "table")] | .[0].content[0].content[0].type')
assert_eq "2d: header uses tableHeader cells" "tableHeader" "$HEADER_CELL_TYPE"

# 2e: Data rows use tableCell
DATA_CELL_TYPE=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "table")] | .[0].content[1].content[0].type')
assert_eq "2e: data rows use tableCell" "tableCell" "$DATA_CELL_TYPE"

# 2f: Checked story has green Done lozenge
FIRST_STATUS=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0].content[1].content[3]')
LOZENGE_TEXT=$(echo "$FIRST_STATUS" | jq -r '.. | objects | select(.type == "status") | .attrs.text' 2>/dev/null | head -1)
LOZENGE_COLOR=$(echo "$FIRST_STATUS" | jq -r '.. | objects | select(.type == "status") | .attrs.color' 2>/dev/null | head -1)
assert_eq "2f: checked story lozenge text is Done" "Done" "$LOZENGE_TEXT"
assert_eq "2g: checked story lozenge color is green" "green" "$LOZENGE_COLOR"

# 2h: Unchecked story has neutral To Do lozenge
SECOND_STATUS=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0].content[2].content[3]')
LOZENGE_TEXT2=$(echo "$SECOND_STATUS" | jq -r '.. | objects | select(.type == "status") | .attrs.text' 2>/dev/null | head -1)
LOZENGE_COLOR2=$(echo "$SECOND_STATUS" | jq -r '.. | objects | select(.type == "status") | .attrs.color' 2>/dev/null | head -1)
assert_eq "2h: unchecked story lozenge text is To Do" "To Do" "$LOZENGE_TEXT2"
assert_eq "2i: unchecked story lozenge color is neutral" "neutral" "$LOZENGE_COLOR2"

# 2j: Status lozenge has style=bold
LOZENGE_STYLE=$(echo "$FIRST_STATUS" | jq -r '.. | objects | select(.type == "status") | .attrs.style' 2>/dev/null | head -1)
assert_eq "2j: lozenge has style bold" "bold" "$LOZENGE_STYLE"

# 2k: Story with jiraKey has a link mark
FIRST_SUMMARY_CELL=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0].content[1].content[2]')
HAS_LINK=$(echo "$FIRST_SUMMARY_CELL" | jq '[.. | objects | select(.marks? // [] | map(.type) | index("link"))] | length' 2>/dev/null)
assert_eq "2k: story with jiraKey has link mark" "1" "$([ "$HAS_LINK" -ge 1 ] && echo 1 || echo 0)"

# 2l: Story without jiraKey has no link mark
SECOND_SUMMARY_CELL=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0].content[2].content[2]')
NO_LINK=$(echo "$SECOND_SUMMARY_CELL" | jq '[.. | objects | select(.marks? // [] | map(.type) | index("link"))] | length' 2>/dev/null)
assert_eq "2l: story without jiraKey has no link mark" "0" "$NO_LINK"

# ─── Test 3: Input with assessment produces assessment section ───
echo ""
echo "Test 3: Input with assessment"
OUTPUT=$(cat "${FIXTURES}/plan-data-with-assessment.json" | "$SUT")

# 3a: Valid JSON
echo "$OUTPUT" | jq . > /dev/null 2>&1
assert_eq "3a: output is valid JSON" "0" "$?"

# 3b: Has heading node
HEADING_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "heading")] | length')
assert_eq "3b: has assessment heading" "1" "$HEADING_COUNT"

# 3c: Heading text
HEADING_TEXT=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "heading")] | .[0].content[0].text')
assert_eq "3c: heading text correct" "Implementation Readiness Assessment" "$HEADING_TEXT"

# 3d: Has emoji node for band
EMOJI_NODE=$(echo "$OUTPUT" | jq -r '[.. | objects | select(.type == "emoji")] | .[0].attrs.shortName' 2>/dev/null)
assert_eq "3d: BLUE band maps to blue_circle emoji" ":blue_circle:" "$EMOJI_NODE"

# 3e: Has code block for bar chart
CODEBLOCK_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "codeBlock")] | length')
assert_eq "3e: has code block for bar chart" "1" "$CODEBLOCK_COUNT"

# 3f: Code block contains dimension names
CODEBLOCK_TEXT=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "codeBlock")] | .[0].content[0].text')
assert_contains "3f: bar chart has Cognitive Complexity" "Cognitive Complexity" "$CODEBLOCK_TEXT"
assert_contains "3g: bar chart has BDD Verification" "BDD Verification" "$CODEBLOCK_TEXT"

# 3h: Bar chart has filled/empty squares
assert_contains "3h: bar chart has filled squares" "■" "$CODEBLOCK_TEXT"
assert_contains "3i: bar chart has empty squares" "□" "$CODEBLOCK_TEXT"

# 3j: Composite score paragraph
COMPOSITE_TEXT=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "paragraph")] | .[] | .content[]? | select(.text? // "" | test("Composite")) | .text' 2>/dev/null | head -1)
assert_contains "3j: composite score line" "1.9 / 5.0" "$COMPOSITE_TEXT"

# 3k: Band label in bold text
BAND_BOLD=$(echo "$OUTPUT" | jq -r '[.. | objects | select(.text? == " BLUE (Manageable)" and (.marks? // [] | map(.type) | index("strong") != null))] | length' 2>/dev/null)
assert_eq "3k: band label is bold" "1" "$([ "$BAND_BOLD" -ge 1 ] && echo 1 || echo 0)"

# ─── Test 4: Full input has all sections ───
echo ""
echo "Test 4: Full input (stories + assessment)"
OUTPUT=$(cat "${FIXTURES}/plan-data-full.json" | "$SUT")

# 4a: Valid JSON
echo "$OUTPUT" | jq . > /dev/null 2>&1
assert_eq "4a: output is valid JSON" "0" "$?"

# 4b: Has context paragraph, table, heading, codeBlock
HAS_PARAGRAPH=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "paragraph")] | length')
HAS_TABLE=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | length')
HAS_HEADING=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "heading")] | length')
HAS_CODEBLOCK=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "codeBlock")] | length')
assert_eq "4b: has paragraph(s)" "1" "$([ "$HAS_PARAGRAPH" -ge 1 ] && echo 1 || echo 0)"
assert_eq "4c: has table" "1" "$HAS_TABLE"
assert_eq "4d: has heading" "1" "$HAS_HEADING"
assert_eq "4e: has code block" "1" "$HAS_CODEBLOCK"

# 4f: YELLOW band maps to yellow_circle emoji
EMOJI_NODE=$(echo "$OUTPUT" | jq -r '[.. | objects | select(.type == "emoji")] | .[0].attrs.shortName' 2>/dev/null)
assert_eq "4f: YELLOW band maps to yellow_circle emoji" ":yellow_circle:" "$EMOJI_NODE"

# 4g: High score (4) has warning marker in bar chart
CODEBLOCK_TEXT=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "codeBlock")] | .[0].content[0].text')
assert_contains "4g: score>=4 has warning marker" "⚠" "$CODEBLOCK_TEXT"

# 4h: Dimension with score 1 has no warning
PERF_LINE=$(echo "$CODEBLOCK_TEXT" | grep "Performance Sensitivity")
assert_not_contains "4h: score 1 has no warning" "⚠" "$PERF_LINE"

# ─── Test 4b: Input with patterns, IO, and verdict ───
echo ""
echo "Test 4b: Input with patterns, IO, and verdict"
OUTPUT=$(cat "${FIXTURES}/plan-data-with-patterns.json" | "$SUT")

echo "$OUTPUT" | jq . > /dev/null 2>&1
assert_eq "4b-a: output is valid JSON" "0" "$?"

# Has patterns paragraph
PATTERNS_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "paragraph") | select(.content[0].text == "Patterns: ")] | length')
assert_eq "4b-b: has patterns paragraph" "1" "$PATTERNS_COUNT"

PATTERNS_VALUE=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "paragraph") | select(.content[0].text == "Patterns: ")] | .[0].content[1].text')
assert_contains "4b-c: patterns lists Port/Adapter" "Port/Adapter" "$PATTERNS_VALUE"
assert_contains "4b-d: patterns lists Strategy" "Strategy" "$PATTERNS_VALUE"

# Has IO paragraph
IO_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "paragraph") | select(.content[0].text == "IO: ")] | length')
assert_eq "4b-e: has IO paragraph" "1" "$IO_COUNT"

IO_VALUE=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "paragraph") | select(.content[0].text == "IO: ")] | .[0].content[1].text')
assert_contains "4b-f: IO lists SLF4J" "SLF4J" "$IO_VALUE"

# Verdict uses full text from parser
VERDICT_VALUE=$(echo "$OUTPUT" | jq -r '[.content[] | select(.type == "paragraph") | select(.content[0].text == "Verdict: ")] | .[0].content[1].text')
assert_contains "4b-g: verdict has full text" "Well-scoped library" "$VERDICT_VALUE"
assert_contains "4b-h: verdict starts with band" "BLUE" "$VERDICT_VALUE"

# Has table with stories
TABLE_COUNT=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | length')
assert_eq "4b-i: has stories table" "1" "$TABLE_COUNT"

# ─── Test 5: Output parseable JSON (redundant but explicit) ───
echo ""
echo "Test 5: JSON parseability across all fixtures"
for fixture in minimal with-stories with-assessment full with-patterns; do
  RESULT=$(cat "${FIXTURES}/plan-data-${fixture}.json" | "$SUT" | jq . > /dev/null 2>&1; echo $?)
  assert_eq "5: ${fixture} produces parseable JSON" "0" "$RESULT"
done

# ─── Test 6: ADF structure validation ───
echo ""
echo "Test 6: ADF structure validation"
OUTPUT=$(cat "${FIXTURES}/plan-data-full.json" | "$SUT")
assert_eq "6a: version is 1" "1" "$(echo "$OUTPUT" | jq '.version')"
assert_eq "6b: type is doc" "doc" "$(echo "$OUTPUT" | jq -r '.type')"
assert_eq "6c: content is array" "array" "$(echo "$OUTPUT" | jq -r '.content | type')"

# 6d: No empty content arrays
EMPTY_CONTENT=$(echo "$OUTPUT" | jq '[.. | objects | select(has("content")) | select(.content | type == "array" and length == 0)] | length' 2>/dev/null)
assert_eq "6d: no empty content arrays" "0" "$EMPTY_CONTENT"

# ─── Test 7: Status lozenge colors match checked status ───
echo ""
echo "Test 7: Lozenge colors match checked status"
OUTPUT=$(cat "${FIXTURES}/plan-data-full.json" | "$SUT")
TABLE=$(echo "$OUTPUT" | jq '[.content[] | select(.type == "table")] | .[0]')

# Row 1 (index 1) = checked=true → green/Done
R1_STATUS=$(echo "$TABLE" | jq -r '.content[1].content[3] | .. | objects | select(.type == "status") | .attrs.color' 2>/dev/null | head -1)
assert_eq "7a: checked=true → green" "green" "$R1_STATUS"

# Row 3 (index 3) = checked=false → neutral/To Do
R3_STATUS=$(echo "$TABLE" | jq -r '.content[3].content[3] | .. | objects | select(.type == "status") | .attrs.color' 2>/dev/null | head -1)
assert_eq "7b: checked=false → neutral" "neutral" "$R3_STATUS"

# ─── Test 8: Emoji shortName matches band ───
echo ""
echo "Test 8: Emoji shortName matches band"
for band_fixture in with-assessment full; do
  OUTPUT=$(cat "${FIXTURES}/plan-data-${band_fixture}.json" | "$SUT")
  BAND=$(cat "${FIXTURES}/plan-data-${band_fixture}.json" | jq -r '.assessment.band')
  EMOJI=$(echo "$OUTPUT" | jq -r '[.. | objects | select(.type == "emoji")] | .[0].attrs.shortName' 2>/dev/null)

  case "$BAND" in
    GREEN)  EXPECTED=":green_circle:" ;;
    BLUE)   EXPECTED=":blue_circle:" ;;
    YELLOW) EXPECTED=":yellow_circle:" ;;
    ORANGE) EXPECTED=":orange_circle:" ;;
    RED)    EXPECTED=":red_circle:" ;;
  esac
  assert_eq "8: ${band_fixture} band ${BAND} → emoji ${EXPECTED}" "$EXPECTED" "$EMOJI"
done

# ─── Summary ───
echo ""
echo "═══════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (total: $((PASS + FAIL)))"
if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failures:"
  echo -e "$ERRORS"
  echo "═══════════════════════════════════════"
  exit 1
fi
echo "═══════════════════════════════════════"
