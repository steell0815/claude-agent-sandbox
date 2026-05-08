#!/usr/bin/env bash
# build-adf-description.sh — Build ADF JSON from plan data
#
# Usage:
#   ./parse-plan-markdown.sh plan.md | ./build-adf-description.sh
#   ./build-adf-description.sh < plan-data.json
#
# Accepts plan data JSON on stdin (output of parse-plan-markdown.sh).
# Outputs a valid Atlassian Document Format (ADF) JSON document to stdout.
#
# Input schema:
#   {
#     "title": "string",
#     "goal": "string",
#     "stories": [{"phase": N, "label": "...", "jiraKey": "PROJ-N"|null, "checked": bool}],
#     "assessment": {"composite": N, "band": "...", "bandLabel": "...", "dimensions": [...]} | null,
#     "jiraEpicKey": "PROJ-N" | null
#   }

set -euo pipefail

INPUT=$(cat)

build_text_node() {
  local text="$1"
  jq -n --arg t "$text" '{"type": "text", "text": $t}'
}

build_bold_text_node() {
  local text="$1"
  jq -n --arg t "$text" '{"type": "text", "text": $t, "marks": [{"type": "strong"}]}'
}

build_paragraph() {
  local content="$1"
  jq -n --argjson c "$content" '{"type": "paragraph", "content": $c}'
}

build_context_paragraph() {
  local goal
  goal=$(echo "$INPUT" | jq -r '.goal')
  build_paragraph "$(jq -n --arg g "$goal" '[{"type": "text", "text": $g}]')"
}

build_status_lozenge() {
  local checked="$1"
  if [[ "$checked" == "true" ]]; then
    jq -n '{"type": "status", "attrs": {"text": "Done", "color": "green", "style": "bold"}}'
  else
    jq -n '{"type": "status", "attrs": {"text": "To Do", "color": "neutral", "style": "bold"}}'
  fi
}

build_table_header_cell() {
  local text="$1"
  jq -n --arg t "$text" '{
    "type": "tableHeader",
    "content": [{"type": "paragraph", "content": [{"type": "text", "text": $t}]}]
  }'
}

build_table_cell() {
  local content="$1"
  jq -n --argjson c "$content" '{
    "type": "tableCell",
    "content": [{"type": "paragraph", "content": $c}]
  }'
}

build_stories_table() {
  local stories
  stories=$(echo "$INPUT" | jq '.stories')
  local count
  count=$(echo "$stories" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    return
  fi

  local header_row
  header_row=$(jq -n \
    --argjson h1 "$(build_table_header_cell "#")" \
    --argjson h2 "$(build_table_header_cell "Phase")" \
    --argjson h3 "$(build_table_header_cell "Summary")" \
    --argjson h4 "$(build_table_header_cell "Status")" \
    '{"type": "tableRow", "content": [$h1, $h2, $h3, $h4]}')

  local rows="[$header_row"

  local i
  for i in $(seq 0 $((count - 1))); do
    local story
    story=$(echo "$stories" | jq ".[$i]")
    local phase label jiraKey checked
    phase=$(echo "$story" | jq -r '.phase')
    label=$(echo "$story" | jq -r '.label')
    jiraKey=$(echo "$story" | jq -r '.jiraKey // empty')
    checked=$(echo "$story" | jq -r '.checked')

    local num_cell
    num_cell=$(build_table_cell "$(jq -n --arg n "$((i + 1))" '[{"type": "text", "text": $n}]')")

    local phase_cell
    phase_cell=$(build_table_cell "$(jq -n --arg p "$phase" '[{"type": "text", "text": $p}]')")

    local summary_content
    if [[ -n "$jiraKey" ]]; then
      local jira_base_url="${JIRA_BASE_URL:-https://jira.example.com}"
      summary_content=$(jq -n --arg l "$label" --arg k "$jiraKey" --arg url "${jira_base_url}/browse/${jiraKey}" \
        '[{"type": "text", "text": $k, "marks": [{"type": "link", "attrs": {"href": $url}}]}, {"type": "text", "text": (" " + $l)}]')
    else
      summary_content=$(jq -n --arg l "$label" '[{"type": "text", "text": $l}]')
    fi
    local summary_cell
    summary_cell=$(build_table_cell "$summary_content")

    local status_lozenge
    status_lozenge=$(build_status_lozenge "$checked")
    local status_cell
    status_cell=$(build_table_cell "$(jq -n --argjson s "$status_lozenge" '[$s]')")

    local data_row
    data_row=$(jq -n \
      --argjson c1 "$num_cell" \
      --argjson c2 "$phase_cell" \
      --argjson c3 "$summary_cell" \
      --argjson c4 "$status_cell" \
      '{"type": "tableRow", "content": [$c1, $c2, $c3, $c4]}')

    rows="$rows,$data_row"
  done

  rows="$rows]"

  jq -n --argjson rows "$rows" '{"type": "table", "content": $rows}'
}

band_emoji() {
  local band="$1"
  case "$band" in
    GREEN)  echo ":green_circle:" ;;
    BLUE)   echo ":blue_circle:" ;;
    YELLOW) echo ":yellow_circle:" ;;
    ORANGE) echo ":orange_circle:" ;;
    RED)    echo ":red_circle:" ;;
    *)      echo ":white_circle:" ;;
  esac
}

build_bar_line() {
  local name="$1" score="$2"
  local padded
  padded=$(printf "%-24s " "$name")
  local filled="" empty=""
  local _i
  for _i in $(seq 1 "$score"); do filled="${filled}■"; done
  for _i in $(seq 1 $((5 - score))); do empty="${empty}□"; done
  local warn=""
  if [[ "$score" -ge 4 ]]; then warn="  ⚠"; fi
  echo "${padded}${score} ${filled}${empty}${warn}"
}

build_assessment_section() {
  local assessment
  assessment=$(echo "$INPUT" | jq '.assessment')

  if [[ "$assessment" == "null" ]]; then
    return
  fi

  local composite band bandLabel
  composite=$(echo "$assessment" | jq -r '.composite')
  band=$(echo "$assessment" | jq -r '.band')
  bandLabel=$(echo "$assessment" | jq -r '.bandLabel // empty')

  local emoji
  emoji=$(band_emoji "$band")

  local heading
  heading=$(jq -n '{"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Implementation Readiness Assessment"}]}')

  local band_display="$band"
  if [[ -n "$bandLabel" ]]; then
    band_display="$band ($bandLabel)"
  fi

  local composite_para
  composite_para=$(jq -n \
    --arg score_text "Composite: ${composite} / 5.0 — " \
    --arg emoji_name "$emoji" \
    --arg band_text " ${band_display}" \
    '{
      "type": "paragraph",
      "content": [
        {"type": "text", "text": $score_text},
        {"type": "emoji", "attrs": {"shortName": $emoji_name}},
        {"type": "text", "text": $band_text, "marks": [{"type": "strong"}]}
      ]
    }')

  local dim_count
  dim_count=$(echo "$assessment" | jq '.dimensions | length')
  local bar_text=""
  local d
  for d in $(seq 0 $((dim_count - 1))); do
    local dim_name dim_score
    dim_name=$(echo "$assessment" | jq -r ".dimensions[$d].name")
    dim_score=$(echo "$assessment" | jq -r ".dimensions[$d].score")
    local line
    line=$(build_bar_line "$dim_name" "$dim_score")
    if [[ -n "$bar_text" ]]; then
      bar_text="${bar_text}
${line}"
    else
      bar_text="$line"
    fi
  done

  local codeblock
  codeblock=$(jq -n --arg text "$bar_text" '{
    "type": "codeBlock",
    "attrs": {"language": "text"},
    "content": [{"type": "text", "text": $text}]
  }')

  jq -n -c --argjson h "$heading" --argjson c "$composite_para" --argjson cb "$codeblock" '[$h, $c, $cb] | .[]'
}

build_patterns_paragraph() {
  local assessment
  assessment=$(echo "$INPUT" | jq '.assessment')
  if [[ "$assessment" == "null" ]]; then return; fi

  local patterns_count
  patterns_count=$(echo "$assessment" | jq '.patterns // [] | length')
  if [[ "$patterns_count" -eq 0 ]]; then return; fi

  local patterns_text
  patterns_text=$(echo "$assessment" | jq -r '.patterns // [] | join(", ")')

  jq -n --arg p "$patterns_text" '{
    "type": "paragraph",
    "content": [
      {"type": "text", "text": "Patterns: ", "marks": [{"type": "strong"}]},
      {"type": "text", "text": $p}
    ]
  }'
}

build_io_paragraph() {
  local assessment
  assessment=$(echo "$INPUT" | jq '.assessment')
  if [[ "$assessment" == "null" ]]; then return; fi

  local io_count
  io_count=$(echo "$assessment" | jq '.io // [] | length')
  if [[ "$io_count" -eq 0 ]]; then return; fi

  local io_text
  io_text=$(echo "$assessment" | jq -r '.io // [] | join(", ")')

  jq -n --arg i "$io_text" '{
    "type": "paragraph",
    "content": [
      {"type": "text", "text": "IO: ", "marks": [{"type": "strong"}]},
      {"type": "text", "text": $i}
    ]
  }'
}

build_verdict_paragraph() {
  local assessment
  assessment=$(echo "$INPUT" | jq '.assessment')
  if [[ "$assessment" == "null" ]]; then
    return
  fi

  # Prefer full verdict text from parser; fall back to band + label
  local verdict_text
  verdict_text=$(echo "$assessment" | jq -r '.verdict // empty')
  if [[ -z "$verdict_text" ]]; then
    local band bandLabel
    band=$(echo "$assessment" | jq -r '.band')
    bandLabel=$(echo "$assessment" | jq -r '.bandLabel // empty')
    verdict_text="$band"
    if [[ -n "$bandLabel" ]]; then
      verdict_text="$band — $bandLabel"
    fi
  fi

  jq -n --arg v "$verdict_text" '{
    "type": "paragraph",
    "content": [
      {"type": "text", "text": "Verdict: ", "marks": [{"type": "strong"}]},
      {"type": "text", "text": $v}
    ]
  }'
}

# --- Main: assemble all sections into ADF doc ---

SECTIONS=()

# 1. Context paragraph
SECTIONS+=("$(build_context_paragraph)")

# 2. Stories table
STORIES_TABLE=$(build_stories_table)
if [[ -n "$STORIES_TABLE" ]]; then
  SECTIONS+=("$STORIES_TABLE")
fi

# 3. Assessment section
ASSESSMENT_NODES=$(build_assessment_section)
if [[ -n "$ASSESSMENT_NODES" ]]; then
  while IFS= read -r node; do
    if [[ -n "$node" ]]; then
      SECTIONS+=("$node")
    fi
  done <<< "$ASSESSMENT_NODES"
fi

# 4. Patterns paragraph
PATTERNS=$(build_patterns_paragraph)
if [[ -n "$PATTERNS" ]]; then
  SECTIONS+=("$PATTERNS")
fi

# 5. IO paragraph
IO=$(build_io_paragraph)
if [[ -n "$IO" ]]; then
  SECTIONS+=("$IO")
fi

# 6. Verdict paragraph
VERDICT=$(build_verdict_paragraph)
if [[ -n "$VERDICT" ]]; then
  SECTIONS+=("$VERDICT")
fi

# Build content array from sections
CONTENT="["
for i in "${!SECTIONS[@]}"; do
  if [[ $i -gt 0 ]]; then
    CONTENT="$CONTENT,"
  fi
  CONTENT="$CONTENT${SECTIONS[$i]}"
done
CONTENT="$CONTENT]"

# Assemble final ADF doc
jq -n --argjson content "$CONTENT" '{
  "version": 1,
  "type": "doc",
  "content": $content
}'
