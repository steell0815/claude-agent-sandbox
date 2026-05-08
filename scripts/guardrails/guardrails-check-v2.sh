#!/usr/bin/env bash
# guardrails-check-v2.sh --- Pattern-file-driven guardrails engine
#
# Loads .patterns files (RULE|GLOB|REGEX|MODE), runs grep against
# staged/changed files, collects CB-G0xx violations.
#
# Usage:
#   guardrails-check-v2.sh [--stack <ts-node|java-spring|auto>] [--scope <staged|unstaged|branch|files>] [FILES...]
#
# Output: Result envelope JSON
#   Success: {"success":true,"data":{"violations":[],"warnings":[]}}
#   Failure: {"success":false,"errors":[...],"warnings":[...]}
#
# Exit code: 0 = clean (or advisory-only), 1 = blocking violations found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DIR="${SCRIPT_DIR}/patterns"
LIB_DIR="${SCRIPT_DIR}/../lib"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source error-codes.sh for CB-G0xx lookup
# shellcheck source=../lib/error-codes.sh
source "${LIB_DIR}/error-codes.sh" 2>/dev/null || true
# shellcheck source=../lib/result.sh
source "${LIB_DIR}/result.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

STACK="auto"
SCOPE="staged"
FILE_LIST=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)  STACK="$2";  shift 2 ;;
    --scope)  SCOPE="$2";  shift 2 ;;
    --)       shift; FILE_LIST+=("$@"); break ;;
    -*)       echo "Unknown option: $1" >&2; exit 1 ;;
    *)        FILE_LIST+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Stack auto-detection
# ---------------------------------------------------------------------------

detect_stack() {
  if [[ -f "${PROJECT_ROOT}/package.json" ]]; then
    echo "ts-node"
  elif [[ -f "${PROJECT_ROOT}/pom.xml" ]]; then
    echo "java-spring"
  else
    echo "common"
  fi
}

if [[ "$STACK" == "auto" ]]; then
  STACK="$(detect_stack)"
fi

# ---------------------------------------------------------------------------
# Get changed files based on scope
# ---------------------------------------------------------------------------

get_changed_files() {
  case "$SCOPE" in
    staged)
      git -C "$PROJECT_ROOT" diff --cached --name-only 2>/dev/null
      ;;
    unstaged)
      git -C "$PROJECT_ROOT" diff --name-only 2>/dev/null
      ;;
    branch)
      local base
      base="$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || echo "HEAD~1")"
      git -C "$PROJECT_ROOT" diff --name-only "${base}..HEAD" 2>/dev/null
      ;;
    files)
      for f in "${FILE_LIST[@]}"; do
        echo "$f"
      done
      ;;
    *)
      echo "Unknown scope: $SCOPE" >&2
      exit 1
      ;;
  esac
}

# Read changed files into array
CHANGED_FILES=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  CHANGED_FILES+=("$f")
done < <(get_changed_files)

# Early exit if no changed files
if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  printf '{"success":true,"data":{"violations":[],"warnings":[]}}\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Glob-to-regex conversion (pure Bash, no external tools)
# ---------------------------------------------------------------------------

glob_to_regex() {
  local glob="$1"
  local regex=""
  local i=0
  local len=${#glob}
  local ch

  while [[ $i -lt $len ]]; do
    ch="${glob:$i:1}"
    case "$ch" in
      '*')
        if [[ $((i + 1)) -lt $len ]] && [[ "${glob:$((i+1)):1}" == "*" ]]; then
          # ** matches any path segments
          if [[ $((i + 2)) -lt $len ]] && [[ "${glob:$((i+2)):1}" == "/" ]]; then
            regex+="(.*/)?"; i=$((i + 3))
          else
            regex+=".*"; i=$((i + 2))
          fi
        else
          regex+="[^/]*"; i=$((i + 1))
        fi
        ;;
      '?')
        regex+="[^/]"; i=$((i + 1))
        ;;
      '.')
        regex+="\\."; i=$((i + 1))
        ;;
      '(')
        regex+="("; i=$((i + 1))
        ;;
      ')')
        regex+=")"; i=$((i + 1))
        ;;
      '|')
        regex+="|"; i=$((i + 1))
        ;;
      '+')
        regex+="\\+"; i=$((i + 1))
        ;;
      '{')
        regex+="("; i=$((i + 1))
        ;;
      '}')
        regex+=")"; i=$((i + 1))
        ;;
      ',')
        regex+="|"; i=$((i + 1))
        ;;
      '^')
        regex+="\\^"; i=$((i + 1))
        ;;
      '$')
        regex+="\\$"; i=$((i + 1))
        ;;
      '[')
        regex+="["; i=$((i + 1))
        ;;
      ']')
        regex+="]"; i=$((i + 1))
        ;;
      '\\')
        regex+="\\\\"; i=$((i + 1))
        ;;
      *)
        regex+="$ch"; i=$((i + 1))
        ;;
    esac
  done

  echo "^${regex}$"
}

# Test if a file path matches a glob pattern
file_matches_glob() {
  local filepath="$1"
  local glob="$2"
  local regex
  regex="$(glob_to_regex "$glob")"
  # Use grep -qE for regex matching
  echo "$filepath" | grep -qE "$regex" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Load pattern files
# ---------------------------------------------------------------------------

PATTERN_LINES=()

load_patterns() {
  local pattern_file="$1"
  [[ ! -f "$pattern_file" ]] && return
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    PATTERN_LINES+=("$line")
  done < "$pattern_file"
}

# Always load common patterns
load_patterns "${PATTERNS_DIR}/common.patterns"

# Load stack-specific patterns
case "$STACK" in
  ts-node)     load_patterns "${PATTERNS_DIR}/ts-node.patterns" ;;
  java-spring) load_patterns "${PATTERNS_DIR}/java-spring.patterns" ;;
esac

# Early exit if no patterns loaded
if [[ ${#PATTERN_LINES[@]} -eq 0 ]]; then
  printf '{"success":true,"data":{"violations":[],"warnings":[]}}\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Scan files against patterns
# ---------------------------------------------------------------------------

BLOCKING_JSON=()
ADVISORY_JSON=()

rule_to_code() {
  local rule="$1"
  local num="${rule#IF-}"
  # Strip leading zeros to avoid octal interpretation, then re-pad
  num=$((10#$num))
  printf 'CB-G%03d' "$num"
}

build_violation_json() {
  local code="$1"
  local file="$2"
  local line_num="$3"
  local match_text="$4"
  local recovery="$5"

  local esc_code esc_file esc_match esc_recovery
  esc_code="$(json_escape "$code")"
  esc_file="$(json_escape "$file")"
  esc_match="$(json_escape "$match_text")"
  esc_recovery="$(json_escape "$recovery")"

  printf '{"code":"%s","message":"%s","file":"%s","line":%s,"recovery":"%s"}' \
    "$esc_code" "$esc_match" "$esc_file" "$line_num" "$esc_recovery"
}

get_recovery() {
  local code="$1"
  if declare -f cb_recovery >/dev/null 2>&1; then
    cb_recovery "$code" 2>/dev/null || echo "See ERROR-CODES.md for guidance"
  else
    echo "See ERROR-CODES.md for guidance"
  fi
}

# Process each pattern line against each changed file
for pattern_line in "${PATTERN_LINES[@]}"; do
  # Parse DSL: RULE|GLOB|REGEX|MODE
  # REGEX may contain pipe characters, so we extract fields carefully:
  #   field 1 = RULE (before first |)
  #   field 2 = GLOB (between first and second |)
  #   last field = MODE (after last |)
  #   middle = REGEX (everything between second | and last |)
  rule="${pattern_line%%|*}"
  local_rest="${pattern_line#*|}"
  glob="${local_rest%%|*}"
  local_rest2="${local_rest#*|}"
  mode="${local_rest2##*|}"
  # REGEX is everything between glob and mode
  regex="${local_rest2%|*}"

  # Validate fields
  [[ -z "$rule" ]] && continue
  [[ -z "$glob" ]] && continue
  [[ -z "$regex" ]] && continue
  mode="${mode:-block}"

  code="$(rule_to_code "$rule")"
  recovery="$(get_recovery "$code")"

  # Filter changed files by glob
  for filepath in "${CHANGED_FILES[@]}"; do
    if ! file_matches_glob "$filepath" "$glob"; then
      continue
    fi

    local_path="${PROJECT_ROOT}/${filepath}"
    [[ ! -f "$local_path" ]] && continue

    # Run grep for the regex pattern against the file
    while IFS=: read -r line_num match_text; do
      [[ -z "$line_num" ]] && continue

      # Truncate long match text
      if [[ ${#match_text} -gt 80 ]]; then
        match_text="${match_text:0:80}..."
      fi

      violation_json="$(build_violation_json "$code" "$filepath" "$line_num" "$match_text" "$recovery")"

      if [[ "$mode" == "advisory" ]]; then
        ADVISORY_JSON+=("$violation_json")
      else
        BLOCKING_JSON+=("$violation_json")
      fi
    done < <(grep -nE "$regex" "$local_path" 2>/dev/null || true)
  done
done

# ---------------------------------------------------------------------------
# Build output envelope
# ---------------------------------------------------------------------------

_join_json_array() {
  # Joins arguments into a JSON array string
  if [[ $# -eq 0 ]]; then
    echo "[]"
    return
  fi
  local first=1
  local result="["
  for item in "$@"; do
    if [[ $first -eq 1 ]]; then
      first=0
    else
      result+=","
    fi
    result+="$item"
  done
  result+="]"
  echo "$result"
}

errors_json="$(_join_json_array "${BLOCKING_JSON[@]+"${BLOCKING_JSON[@]}"}")"
warnings_json="$(_join_json_array "${ADVISORY_JSON[@]+"${ADVISORY_JSON[@]}"}")"

if [[ ${#BLOCKING_JSON[@]} -gt 0 ]]; then
  printf '{"success":false,"errors":%s,"warnings":%s}\n' "$errors_json" "$warnings_json"
  exit 1
else
  printf '{"success":true,"data":{"violations":[],"warnings":%s}}\n' "$warnings_json"
  exit 0
fi
