#!/usr/bin/env bash
# commit-helper.sh — Detect unplanned work and create result files
#
# Usage:
#   commit-helper.sh check-unplanned          — returns JSON: {"inProgress": bool, "planId": "...", "needsResult": bool}
#   commit-helper.sh create-result "<title>"   — creates result file + registers in index, outputs path
#
# Requires: scripts/plan-index.sh in the project root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLAN_INDEX="${PROJECT_ROOT}/scripts/plan-index.sh"

if [[ ! -x "$PLAN_INDEX" ]]; then
  echo "Error: plan-index.sh not found at ${PLAN_INDEX}" >&2
  exit 1
fi

cmd_check_unplanned() {
  local plans
  plans=$("$PLAN_INDEX" list 2>/dev/null)

  local in_progress_id
  in_progress_id=$(echo "$plans" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data:
    if p.get('status') == 'in_progress':
        print(p['id'])
        sys.exit(0)
print('')
" 2>/dev/null)

  if [[ -n "$in_progress_id" ]]; then
    echo "{\"inProgress\": true, \"planId\": \"${in_progress_id}\", \"needsResult\": false}"
  else
    echo "{\"inProgress\": false, \"planId\": null, \"needsResult\": true}"
  fi
}

cmd_create_result() {
  local title="$1"
  local slug
  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  local date_prefix
  date_prefix=$(date +%Y-%m-%d)
  local result_file="plans/results/${date_prefix}-${slug}.md"
  local abs_path="${PROJECT_ROOT}/${result_file}"

  mkdir -p "$(dirname "$abs_path")"

  cat > "$abs_path" << RESULTEOF
# ${title} - Implementation Result

## Summary

What was implemented and why.

## Changes Made

- \`path/to/file\` - Description of changes

## Decisions

- Decision 1: Rationale

## Testing

- Tests added/modified

## Quality Gates

- [ ] Unit tests pass
- [ ] Lint passes
- [ ] Format check passes
RESULTEOF

  "$PLAN_INDEX" add "$title" "" "unplanned" "$result_file" > /dev/null 2>&1

  echo "{\"resultFile\": \"${result_file}\", \"title\": \"${title}\"}"
}

case "${1:-}" in
  check-unplanned)
    cmd_check_unplanned
    ;;
  create-result)
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 create-result \"<title>\"" >&2
      exit 1
    fi
    cmd_create_result "$2"
    ;;
  *)
    echo "Usage: $0 {check-unplanned|create-result <title>}" >&2
    exit 1
    ;;
esac
