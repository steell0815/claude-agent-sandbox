#!/usr/bin/env bash
# plan-init.sh — Scaffold a plan file and register in index
#
# Usage:
#   plan-init.sh "<feature-name>"              — creates plan from name
#   plan-init.sh "PROJ-123"                    — detects JIRA key, fetches ticket, creates plan
#   plan-init.sh "PROJ-123" --no-jira          — uses key as name without JIRA fetch
#
# Output: JSON with plan metadata
#   {"id": "PROJ-123", "file": "plans/PROJ-123.md", "title": "...", "jiraFetched": true}
#
# Environment (optional, for JIRA integration):
#   JIRA_API_TOKEN, JIRA_BASE_URL, JIRA_EMAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source error code library (fallback-safe for pre-scaffold environments)
# shellcheck source=lib/error-codes.sh
source "${SCRIPT_DIR}/lib/error-codes.sh" 2>/dev/null || true

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <feature-name-or-jira-key> [--no-jira]" >&2
  exit 1
fi

INPUT="$1"
NO_JIRA="${2:-}"

is_jira_key() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

fetch_jira_ticket() {
  local key="$1"
  if [[ -z "${JIRA_API_TOKEN:-}" || -z "${JIRA_BASE_URL:-}" || -z "${JIRA_EMAIL:-}" ]]; then
    echo ""
    return
  fi
  local auth
  auth=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)
  curl -s -X GET \
    "${JIRA_BASE_URL}/rest/api/3/issue/${key}?fields=summary,status,description" \
    -H "Authorization: Basic ${auth}" \
    -H "Content-Type: application/json" 2>/dev/null
}

if is_jira_key "$INPUT"; then
  PLAN_ID="$INPUT"
  PLAN_FILE="plans/${PLAN_ID}.md"

  if [[ "$NO_JIRA" != "--no-jira" ]]; then
    JIRA_RESPONSE=$(fetch_jira_ticket "$PLAN_ID")
    if [[ -n "$JIRA_RESPONSE" ]]; then
      TITLE=$(echo "$JIRA_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['fields']['summary'])" 2>/dev/null || echo "$PLAN_ID")
      JIRA_FETCHED="true"
    else
      TITLE="$PLAN_ID"
      JIRA_FETCHED="false"
    fi
  else
    TITLE="$PLAN_ID"
    JIRA_FETCHED="false"
  fi

  JIRA_URL="${JIRA_BASE_URL:-https://example.atlassian.net}/browse/${PLAN_ID}"
else
  TITLE="$INPUT"
  PLAN_ID="$(slugify "$TITLE")"
  PLAN_FILE="plans/$(date +%Y-%m-%d)-${PLAN_ID}.md"
  JIRA_FETCHED="false"
  JIRA_URL=""
fi

ABS_PATH="${PROJECT_ROOT}/${PLAN_FILE}"
mkdir -p "$(dirname "$ABS_PATH")"

if [[ -f "$ABS_PATH" ]]; then
  echo "{\"error\": \"Plan file already exists: ${PLAN_FILE}\"}" >&2
  type cb_error_stderr &>/dev/null && cb_error_stderr "CB-S001" "$ABS_PATH"
  exit 1
fi

if [[ -n "$JIRA_URL" ]]; then
  cat > "$ABS_PATH" << PLANEOF
# Plan: ${PLAN_ID} — ${TITLE}

## JIRA

- **Epic**: [${PLAN_ID}](${JIRA_URL}) ${TITLE}
- **Stories**:

## Context

<!-- LLM: Write context here -->

## Phases

### Phase 1: TBD

## Verification

## Status

- [ ] Phase 1: TBD
PLANEOF
else
  cat > "$ABS_PATH" << PLANEOF
# Plan: ${TITLE}

## Context

<!-- LLM: Write context here -->

## Phases

### Phase 1: TBD

## Verification

## Status

- [ ] Phase 1: TBD
PLANEOF
fi

echo "{\"id\": \"${PLAN_ID}\", \"file\": \"${PLAN_FILE}\", \"title\": \"${TITLE}\", \"jiraFetched\": ${JIRA_FETCHED}}"
