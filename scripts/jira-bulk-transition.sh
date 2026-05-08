#!/usr/bin/env bash
# jira-bulk-transition.sh — Transition JIRA issues in bulk
#
# Usage:
#   jira-bulk-transition.sh <transition-id> <issue-key>...
#   jira-bulk-transition.sh <transition-id> --jql "project = PROJ AND status = 'To Do'"
#
# Common transition IDs (vary by project — use jira_get_transitions to discover):
#   11 = To Do, 21 = In Progress, 31 = Done
#
# Environment:
#   JIRA_API_TOKEN — API token (required)
#   JIRA_BASE_URL  — e.g., https://yourorg.atlassian.net (required)
#   JIRA_EMAIL     — e.g., user@example.com (required)

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <transition-id> <issue-key>..." >&2
  echo "       $0 <transition-id> --jql \"<jql-query>\"" >&2
  exit 1
fi

: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is not set}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL is not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL is not set}"

AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)
TRANSITION_ID="$1"
shift

resolve_keys() {
  if [[ "$1" == "--jql" ]]; then
    local jql="$2"
    local start=0
    local total=1
    while [[ $start -lt $total ]]; do
      local response
      response=$(curl -s -X GET \
        "${JIRA_BASE_URL}/rest/api/3/search?jql=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$jql")&fields=key&startAt=${start}&maxResults=100" \
        -H "Authorization: Basic ${AUTH}" \
        -H "Content-Type: application/json")
      total=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")
      echo "$response" | python3 -c "import json,sys; [print(i['key']) for i in json.load(sys.stdin)['issues']]"
      start=$((start + 100))
    done
  else
    for key in "$@"; do echo "$key"; done
  fi
}

keys=$(resolve_keys "$@")
count=0
failed=0

while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${JIRA_BASE_URL}/rest/api/3/issue/${key}/transitions" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{\"transition\": {\"id\": \"${TRANSITION_ID}\"}}")
  if [[ "$http_code" == "204" ]]; then
    count=$((count + 1))
  else
    echo "FAILED: ${key} (HTTP ${http_code})" >&2
    failed=$((failed + 1))
  fi
done <<< "$keys"

echo "Transitioned ${count} issues (transition=${TRANSITION_ID})${failed:+ (${failed} failed)}"
