#!/usr/bin/env bash
# assessment-publish.sh — Build ADF from assessment scores and push to JIRA
#
# Usage:
#   assessment-publish.sh <plan-id> <scores-json-file>
#   echo '{"scores":[...]}' | assessment-publish.sh <plan-id> -
#
# The scores JSON must contain:
#   {
#     "compositeScore": 2.2,
#     "band": "BLUE",
#     "dimensions": [
#       {"name": "Cognitive Complexity", "score": 3, "rationale": "..."},
#       ...
#     ],
#     "patterns": ["pattern 1", "pattern 2"],
#     "ioBoundaries": ["PostgreSQL"],
#     "verdict": "BLUE — Manageable complexity..."
#   }
#
# Environment:
#   JIRA_API_TOKEN, JIRA_BASE_URL, JIRA_EMAIL

set -euo pipefail

: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is not set}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL is not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL is not set}"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <plan-id> <scores-json-file|->" >&2
  exit 1
fi

PLAN_ID="$1"
SCORES_INPUT="$2"

if [[ "$SCORES_INPUT" == "-" ]]; then
  SCORES_JSON=$(cat)
else
  SCORES_JSON=$(cat "$SCORES_INPUT")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_DESC_SCRIPT="${SCRIPT_DIR}/jira-update-description.sh"

if [[ ! -x "$JIRA_DESC_SCRIPT" ]]; then
  JIRA_DESC_SCRIPT="$HOME/.claude/scripts/jira-update-description.sh"
fi

if [[ ! -x "$JIRA_DESC_SCRIPT" ]]; then
  echo "Error: jira-update-description.sh not found" >&2
  exit 1
fi

ADF_JSON=$(python3 -c "
import json, sys

scores = json.loads('''${SCORES_JSON}''')
composite = scores['compositeScore']
band = scores['band']
dimensions = scores.get('dimensions', [])
patterns = scores.get('patterns', [])
io_boundaries = scores.get('ioBoundaries', [])
verdict = scores.get('verdict', '')

band_emoji = {
    'GREEN': ':green_circle:', 'BLUE': ':blue_circle:',
    'YELLOW': ':yellow_circle:', 'ORANGE': ':orange_circle:', 'RED': ':red_circle:'
}.get(band, ':white_circle:')

content = []

# Heading
content.append({'type': 'heading', 'attrs': {'level': 2}, 'content': [
    {'type': 'text', 'text': 'Implementation Readiness Assessment'}
]})

# Composite score
content.append({'type': 'paragraph', 'content': [
    {'type': 'text', 'text': f'Composite: {composite} / 5.0 — '},
    {'type': 'emoji', 'attrs': {'shortName': band_emoji}},
    {'type': 'text', 'text': f' {band}', 'marks': [{'type': 'strong'}]}
]})

# Bar chart
if dimensions:
    bars = []
    for d in dimensions:
        filled = '■' * d['score']
        empty = '□' * (5 - d['score'])
        warn = ' ⚠' if d['score'] >= 4 else ''
        bars.append(f\"{d['name']:30s} {filled}{empty} {d['score']}/5{warn}\")
    chart = '\n'.join(bars)
    content.append({'type': 'codeBlock', 'attrs': {'language': 'text'}, 'content': [
        {'type': 'text', 'text': chart}
    ]})

# Patterns
if patterns:
    content.append({'type': 'paragraph', 'content': [
        {'type': 'text', 'text': 'Patterns: ', 'marks': [{'type': 'strong'}]},
        {'type': 'text', 'text': ', '.join(patterns)}
    ]})

# IO Boundaries
if io_boundaries:
    content.append({'type': 'paragraph', 'content': [
        {'type': 'text', 'text': 'IO Boundaries: ', 'marks': [{'type': 'strong'}]},
        {'type': 'text', 'text': ', '.join(io_boundaries)}
    ]})

# Verdict
if verdict:
    content.append({'type': 'paragraph', 'content': [
        {'type': 'text', 'text': 'Verdict: ', 'marks': [{'type': 'strong'}]},
        {'type': 'text', 'text': verdict}
    ]})

adf = {'version': 1, 'type': 'doc', 'content': content}
print(json.dumps(adf))
")

echo "$ADF_JSON" | "$JIRA_DESC_SCRIPT" "$PLAN_ID" -

echo "Assessment published to ${PLAN_ID}"
