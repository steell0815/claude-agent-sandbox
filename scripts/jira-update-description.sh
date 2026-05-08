#!/usr/bin/env bash
# jira-update-description.sh — Update a JIRA issue description with ADF JSON
#
# Usage:
#   jira-update-description.sh <issue-key> <adf-json-file>
#   echo '{"version":1,...}' | jira-update-description.sh <issue-key> -
#
# The ADF JSON must be a valid Atlassian Document Format document.
# See: https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
#
# Why this exists:
#   The JIRA MCP tool's description field only accepts plain text (converted to
#   ADF paragraphs). Markdown syntax renders as raw text. This script calls the
#   JIRA REST API v3 directly to push native ADF with headings, tables, code
#   blocks, status lozenges, and emoji nodes.
#
# Environment (configure for your instance):
#   JIRA_API_TOKEN — API token (required)
#   JIRA_BASE_URL  — e.g., https://yourorg.atlassian.net (required)
#   JIRA_EMAIL     — e.g., user@example.com (required)

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <issue-key> <adf-json-file|->" >&2
  exit 1
fi

ISSUE_KEY="$1"
ADF_SOURCE="$2"

# Validate required environment variables
for VAR in JIRA_API_TOKEN JIRA_BASE_URL JIRA_EMAIL; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Error: ${VAR} is not set" >&2
    exit 1
  fi
done

# Read ADF JSON from file or stdin
if [[ "$ADF_SOURCE" == "-" ]]; then
  ADF_JSON=$(cat)
else
  if [[ ! -f "$ADF_SOURCE" ]]; then
    echo "Error: File not found: $ADF_SOURCE" >&2
    exit 1
  fi
  ADF_JSON=$(cat "$ADF_SOURCE")
fi

# Build the request payload
PAYLOAD=$(jq -n --argjson adf "$ADF_JSON" '{"fields": {"description": $adf}}')

# Base64 encode credentials
AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)

# Call JIRA REST API v3
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/jira-response-$$.json -X PUT \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "OK: ${ISSUE_KEY} description updated"
else
  echo "Error: HTTP ${HTTP_CODE}" >&2
  cat /tmp/jira-response-$$.json >&2
  rm -f /tmp/jira-response-$$.json
  exit 1
fi

rm -f /tmp/jira-response-$$.json
