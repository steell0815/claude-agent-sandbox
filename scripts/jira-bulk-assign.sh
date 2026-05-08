#!/usr/bin/env bash
# jira-bulk-assign.sh — Assign JIRA issues to a user in bulk
#
# Usage:
#   jira-bulk-assign.sh <account-id> <issue-key>...
#   jira-bulk-assign.sh <account-id> --jql "project = PROJ AND assignee is EMPTY"
#
# Why this exists:
#   Assigning issues one by one via MCP tool calls wastes LLM tokens on
#   mechanical work. This script does the same via REST API in a single
#   Bash invocation — zero token cost for the loop.
#
# Environment (configure for your instance):
#   JIRA_API_TOKEN — API token (required)
#   JIRA_BASE_URL  — e.g., https://yourorg.atlassian.net (required)
#   JIRA_EMAIL     — e.g., user@example.com (required)

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <account-id> <issue-key>..." >&2
  echo "       $0 <account-id> --jql \"<jql-query>\"" >&2
  exit 1
fi

: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is not set}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL is not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL is not set}"

AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)
ACCOUNT_ID="$1"
shift

resolve_keys() {
  if [[ "$1" == "--jql" ]]; then
    local jql="$2"
    local start=0
    local total=1
    while [[ $start -lt $total ]]; do
      local response
      response=$(curl -s -X GET \
        "${JIRA_BASE_URL}/rest/api/3/search?jql=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$jql'))")&fields=key&startAt=${start}&maxResults=100" \
        -H "Authorization: Basic ${AUTH}" \
        -H "Content-Type: application/json")
      total=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")
      echo "$response" | python3 -c "import json,sys; [print(i['key']) for i in json.load(sys.stdin)['issues']]"
      start=$((start + 100))
    done
  else
    for key in "$@"; do
      echo "$key"
    done
  fi
}

keys=$(resolve_keys "$@")
count=0
failed=0

while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "${JIRA_BASE_URL}/rest/api/3/issue/${key}/assignee" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{\"accountId\": \"${ACCOUNT_ID}\"}")
  if [[ "$http_code" == "204" ]]; then
    count=$((count + 1))
  else
    echo "FAILED: ${key} (HTTP ${http_code})" >&2
    failed=$((failed + 1))
  fi
done <<< "$keys"

echo "Assigned ${count} issues to ${ACCOUNT_ID}${failed:+ (${failed} failed)}"
