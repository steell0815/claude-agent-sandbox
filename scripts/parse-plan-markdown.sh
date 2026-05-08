#!/usr/bin/env bash
# parse-plan-markdown.sh — Parse a plan markdown file and output structured JSON
#
# Usage:
#   parse-plan-markdown.sh <plan-file>
#
# Output: JSON to stdout with title, goal, stories, assessment, jiraEpicKey

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <plan-file>" >&2
  exit 1
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Error: File not found: $PLAN_FILE" >&2
  exit 1
fi

CONTENT=$(cat "$PLAN_FILE")

extract_title() {
  # Match: # Title text (first H1)
  echo "$CONTENT" | grep -m1 '^# ' | sed 's/^# //'
}

extract_section() {
  local heading="$1"
  local in_section=false
  local result=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+"$heading" ]] || [[ "$line" == "## $heading" ]]; then
      in_section=true
      continue
    fi
    if $in_section && [[ "$line" =~ ^##[[:space:]] ]]; then
      break
    fi
    if $in_section; then
      result+="${line}"$'\n'
    fi
  done <<< "$CONTENT"
  echo "$result"
}

extract_goal() {
  local goal_text
  goal_text=$(extract_section "Goal")
  if [[ -z "$(echo "$goal_text" | tr -d '[:space:]')" ]]; then
    goal_text=$(extract_section "Summary")
  fi
  if [[ -z "$(echo "$goal_text" | tr -d '[:space:]')" ]]; then
    goal_text=$(extract_section "Context")
  fi
  # Trim leading/trailing blank lines
  # Remove leading blank lines, then remove trailing blank lines
  goal_text=$(echo "$goal_text" | sed '/./,$!d')
  # Remove trailing blank lines using awk (portable)
  echo "$goal_text" | awk '/^[[:space:]]*$/{blank++; next} {for(i=0;i<blank;i++) print ""; blank=0; print}'
}

extract_stories() {
  local status_section
  status_section=$(extract_section "Status")
  if [[ -z "$(echo "$status_section" | tr -d '[:space:]')" ]]; then
    status_section=$(extract_section "Implementation Phases")
  fi
  if [[ -z "$(echo "$status_section" | tr -d '[:space:]')" ]]; then
    echo "[]"
    return
  fi

  local stories_json="[]"

  # Regex patterns stored in variables to avoid bash parsing issues with parentheses
  local re_subphase_jira='\([A-Z][A-Z0-9]+-[0-9]+'
  local re_subphase_line='^[[:space:]]+-[[:space:]]\[([ xX])\][[:space:]]*([0-9]+[a-z]?):[[:space:]]*(.*)'
  local re_jira_parens='([^(]*)\(([A-Z][A-Z0-9]+-[0-9]+)\)(.*)'
  local re_toplevel_phase='^-[[:space:]]\[([ xX])\][[:space:]]Phase[[:space:]]([^:]+):[[:space:]]*(.*)'
  local re_jira_key_only='\(([A-Z][A-Z0-9]+-[0-9]+)\)'

  # Determine mode: count JIRA keys at each level; use the level with more keys
  local toplevel_jira_count=0
  local subphase_jira_count=0
  local has_subphase_jira=false
  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[[:space:]]+- && "$line" =~ $re_toplevel_phase ]]; then
      if [[ "${BASH_REMATCH[3]}" =~ $re_subphase_jira ]]; then
        toplevel_jira_count=$((toplevel_jira_count + 1))
      fi
    fi
    if [[ "$line" =~ ^[[:space:]]+- && "$line" =~ $re_subphase_jira ]]; then
      subphase_jira_count=$((subphase_jira_count + 1))
    fi
  done <<< "$status_section"
  # Use sub-phase mode when sub-phases have strictly more JIRA keys than top-level
  if [[ $subphase_jira_count -gt $toplevel_jira_count ]]; then
    has_subphase_jira=true
  fi

  while IFS= read -r line; do
    if $has_subphase_jira; then
      # Sub-phase mode: extract indented lines with JIRA keys as the story items
      # Format:   - [ ] 1a: Value objects (S2P-129) — description
      if [[ "$line" =~ $re_subphase_line ]]; then
        local check_char="${BASH_REMATCH[1]}"
        local phase="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        local checked=false
        if [[ "$check_char" == "x" || "$check_char" == "X" ]]; then
          checked=true
        fi

        local jira_key="null"
        local label="$rest"
        if [[ "$rest" =~ $re_jira_parens ]]; then
          label="${BASH_REMATCH[1]}"
          jira_key="${BASH_REMATCH[2]}"
        fi

        # Trim trailing whitespace
        while [[ "$label" =~ [[:space:]]$ ]]; do label="${label%?}"; done

        stories_json=$(echo "$stories_json" | jq \
          --arg phase "$phase" \
          --arg label "$label" \
          --arg jira_key "$jira_key" \
          --argjson checked "$checked" \
          '. + [{"phase": $phase, "label": $label, "jiraKey": (if $jira_key == "null" then null else $jira_key end), "checked": $checked}]')
      fi
      # Also extract top-level phases with JIRA keys but no sub-items
      # Format: - [ ] Phase 3: Stack trace sanitization (S2P-135) — description
      if [[ ! "$line" =~ ^[[:space:]]+- && "$line" =~ $re_toplevel_phase ]]; then
        local check_char="${BASH_REMATCH[1]}"
        local phase="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        local jira_key="null"
        if [[ "$rest" =~ $re_jira_key_only ]]; then
          jira_key="${BASH_REMATCH[1]}"
          local checked=false
          if [[ "$check_char" == "x" || "$check_char" == "X" ]]; then
            checked=true
          fi
          local label="$rest"
          if [[ "$rest" =~ $re_jira_parens ]]; then
            label="${BASH_REMATCH[1]}"
          fi
          while [[ "$label" =~ [[:space:]]$ ]]; do label="${label%?}"; done

          stories_json=$(echo "$stories_json" | jq \
            --arg phase "$phase" \
            --arg label "$label" \
            --arg jira_key "$jira_key" \
            --argjson checked "$checked" \
            '. + [{"phase": $phase, "label": $label, "jiraKey": (if $jira_key == "null" then null else $jira_key end), "checked": $checked}]')
        fi
      fi
    else
      # Original mode: top-level checkboxes only
      # Skip indented lines (sub-tasks) — only process top-level checkboxes
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        continue
      fi
      # Match: - [x] or - [ ] followed by Phase info
      if [[ "$line" =~ ^-[[:space:]]\[([ xX])\][[:space:]]Phase[[:space:]]([^:]+):[[:space:]]*(.*) ]]; then
        local check_char="${BASH_REMATCH[1]}"
        local phase="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        local checked=false
        if [[ "$check_char" == "x" || "$check_char" == "X" ]]; then
          checked=true
        fi

        # Extract JIRA key from parentheses: (PROJ-123 Status)
        local jira_key="null"
        local label="$rest"
        # Pattern: label text (PROJ-123 optional-status)
        if [[ "$rest" =~ ^(.*)[[:space:]]*\(([A-Z][A-Z0-9]+-[0-9]+)[[:space:]].*\)$ ]]; then
          label="${BASH_REMATCH[1]}"
          jira_key="${BASH_REMATCH[2]}"
        elif [[ "$rest" =~ ^(.*)[[:space:]]*\(([A-Z][A-Z0-9]+-[0-9]+)\)$ ]]; then
          label="${BASH_REMATCH[1]}"
          jira_key="${BASH_REMATCH[2]}"
        fi

        # Trim trailing whitespace from label
        while [[ "$label" =~ [[:space:]]$ ]]; do label="${label%?}"; done

        stories_json=$(echo "$stories_json" | jq \
          --arg phase "$phase" \
          --arg label "$label" \
          --arg jira_key "$jira_key" \
          --argjson checked "$checked" \
          '. + [{"phase": $phase, "label": $label, "jiraKey": (if $jira_key == "null" then null else $jira_key end), "checked": $checked}]')
      fi
    fi
  done <<< "$status_section"

  echo "$stories_json"
}

extract_assessment() {
  local assessment_section
  assessment_section=$(extract_section "Implementation Readiness Assessment")
  if [[ -z "$(echo "$assessment_section" | tr -d '[:space:]')" ]]; then
    echo "null"
    return
  fi

  # Extract composite score: **Composite Score:** 1.9 / 5.0 — BAND
  local composite="0" band="UNKNOWN"
  local composite_line
  composite_line=$(echo "$assessment_section" | grep -m1 '\*\*Composite Score:\*\*' || true)
  if [[ -n "$composite_line" ]]; then
    # Pattern: **Composite Score:** X.X / 5.0 — BAND (Label)
    if [[ "$composite_line" =~ \*\*Composite\ Score:\*\*[[:space:]]*([0-9]+\.?[0-9]*)[[:space:]]*/[[:space:]]*5\.0[[:space:]]*—[[:space:]]*([A-Z]+) ]]; then
      composite="${BASH_REMATCH[1]}"
      band="${BASH_REMATCH[2]}"
    fi
  fi

  # Extract dimensions from markdown table
  local dimensions_json="[]"
  local in_table=false
  local header_passed=false

  while IFS= read -r line; do
    # Detect table start (header row with | # | Dimension | ...)
    if [[ "$line" =~ ^\|[[:space:]]*#[[:space:]]*\| ]]; then
      in_table=true
      continue
    fi
    # Skip separator row (|---|---|...)
    if $in_table && [[ "$line" =~ ^\|[[:space:]]*-+[[:space:]]*\| ]]; then
      header_passed=true
      continue
    fi
    # End of table
    if $in_table && $header_passed && [[ ! "$line" =~ ^\| ]]; then
      break
    fi
    # Parse data rows
    if $in_table && $header_passed && [[ "$line" =~ ^\| ]]; then
      # Split by | but handle pipes in rationale carefully
      # Format: | N | Dimension Name | Score | Rationale |
      # Strategy: extract first 3 fields by first 3 pipe delimiters,
      # then everything remaining is the rationale
      local stripped
      stripped=$(echo "$line" | sed 's/^|//; s/|$//')

      # Extract field 1 (number), field 2 (name), field 3 (score)
      # by matching the first three pipe-delimited segments
      local field2 field3 rationale
      field2=$(echo "$stripped" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      field3=$(echo "$stripped" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      # Rationale is everything after the 3rd pipe delimiter (may contain pipes)
      # Count the first 3 pipe positions and take the rest
      local pipe_count=0
      local rationale_start=0
      for ((i=0; i<${#stripped}; i++)); do
        if [[ "${stripped:$i:1}" == "|" ]]; then
          ((pipe_count++))
          if [[ $pipe_count -eq 3 ]]; then
            rationale_start=$((i + 1))
            break
          fi
        fi
      done
      rationale="${stripped:$rationale_start}"
      rationale=$(echo "$rationale" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [[ -n "$field2" && -n "$field3" ]]; then
        dimensions_json=$(echo "$dimensions_json" | jq \
          --arg name "$field2" \
          --argjson score "$field3" \
          --arg rationale "$rationale" \
          '. + [{"name": $name, "score": $score, "rationale": $rationale}]')
      fi
    fi
  done <<< "$assessment_section"

  # Extract patterns from ### Patterns Required
  local patterns_json="[]"
  local in_patterns=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^###[[:space:]]+Patterns ]]; then
      in_patterns=true
      continue
    fi
    if $in_patterns && [[ "$line" =~ ^### ]]; then
      break
    fi
    if $in_patterns && [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      local pattern_text="${BASH_REMATCH[1]}"
      patterns_json=$(echo "$patterns_json" | jq --arg p "$pattern_text" '. + [$p]')
    fi
  done <<< "$assessment_section"

  # Extract IO boundaries from ### IO Boundaries
  local io_json="[]"
  local in_io=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^###[[:space:]]+IO[[:space:]]+Boundar ]]; then
      in_io=true
      continue
    fi
    if $in_io && [[ "$line" =~ ^### ]]; then
      break
    fi
    if $in_io && [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      local io_text="${BASH_REMATCH[1]}"
      io_json=$(echo "$io_json" | jq --arg i "$io_text" '. + [$i]')
    fi
  done <<< "$assessment_section"

  # Extract verdict from ### Readiness Verdict
  local verdict=""
  local in_verdict=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^###[[:space:]]+Readiness[[:space:]]+Verdict ]]; then
      in_verdict=true
      continue
    fi
    if $in_verdict && [[ "$line" =~ ^### ]]; then
      break
    fi
    if $in_verdict && [[ -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
      # Strip bold markers
      local clean_line
      clean_line=$(echo "$line" | sed 's/\*\*//g')
      if [[ -z "$verdict" ]]; then
        verdict="$clean_line"
      else
        verdict="$verdict $clean_line"
      fi
    fi
  done <<< "$assessment_section"

  jq -n \
    --argjson composite "$composite" \
    --arg band "$band" \
    --argjson dimensions "$dimensions_json" \
    --argjson patterns "$patterns_json" \
    --argjson io "$io_json" \
    --arg verdict "$verdict" \
    '{"composite": $composite, "band": $band, "dimensions": $dimensions, "patterns": $patterns, "io": $io, "verdict": $verdict}'
}

extract_jira_epic_key() {
  # First try: dedicated ## JIRA section
  local jira_section
  jira_section=$(extract_section "JIRA")
  if [[ -n "$(echo "$jira_section" | tr -d '[:space:]')" ]]; then
    local epic_key
    epic_key=$(echo "$jira_section" | grep -oE '\[([A-Z][A-Z0-9]+-[0-9]+)\]' | head -1 | tr -d '[]' || true)
    if [[ -n "$epic_key" ]]; then
      echo "\"$epic_key\""
      return
    fi
  fi

  # Fallback: inline **JIRA:** [PROJ-N](url) in header metadata
  local inline_key
  inline_key=$(echo "$CONTENT" | grep -m1 '^\*\*JIRA:\*\*' | grep -oE '\[([A-Z][A-Z0-9]+-[0-9]+)\]' | head -1 | tr -d '[]' || true)
  if [[ -n "$inline_key" ]]; then
    echo "\"$inline_key\""
    return
  fi

  echo "null"
}

TITLE=$(extract_title)
GOAL=$(extract_goal)
STORIES=$(extract_stories)
ASSESSMENT=$(extract_assessment)
JIRA_EPIC_KEY=$(extract_jira_epic_key)

jq -n \
  --arg title "$TITLE" \
  --arg goal "$GOAL" \
  --argjson stories "$STORIES" \
  --argjson assessment "$ASSESSMENT" \
  --argjson jiraEpicKey "$JIRA_EPIC_KEY" \
  '{"title": $title, "goal": $goal, "stories": $stories, "assessment": $assessment, "jiraEpicKey": $jiraEpicKey}'
