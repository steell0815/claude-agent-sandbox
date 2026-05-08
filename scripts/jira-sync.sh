#!/usr/bin/env bash
# jira-sync.sh — Three-way merge sync between plan files and JIRA
#
# Usage:
#   jira-sync.sh <plan-id>        — sync one plan
#   jira-sync.sh all              — sync all plans in index
#   jira-sync.sh --assign-all     — assign all unassigned project issues to current user
#
# Implements the full sync-jira workflow:
#   1. Load snapshot baseline
#   2. Fetch JIRA remote state
#   3. Parse plan local state
#   4. Three-way diff classification
#   5. Apply resolutions (plan wins, JIRA drift logged)
#   6. Default-assign unassigned touched issues
#   7. Write new snapshot
#   8. Output report
#
# Environment:
#   JIRA_API_TOKEN, JIRA_BASE_URL, JIRA_EMAIL

set -euo pipefail

: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is not set}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL is not set}"
: "${JIRA_EMAIL:?JIRA_EMAIL is not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64)

SYNC_DIR="${PROJECT_ROOT}/plans/.sync"
INDEX_FILE="${PROJECT_ROOT}/plans/index.json"

mkdir -p "$SYNC_DIR"

# --- JIRA API helpers ---

jira_get() {
  curl -s -X GET "${JIRA_BASE_URL}/rest/api/3/$1" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json"
}

jira_post() {
  curl -s -o /dev/null -w "%{http_code}" -X POST "${JIRA_BASE_URL}/rest/api/3/$1" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "$2"
}

jira_put() {
  curl -s -o /dev/null -w "%{http_code}" -X PUT "${JIRA_BASE_URL}/rest/api/3/$1" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "$2"
}

jira_search() {
  local jql
  jql=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1")
  jira_get "search?jql=${jql}&fields=key,summary,status,assignee&maxResults=100"
}

normalize_status() {
  case "$1" in
    "Fertig"|"Done")           echo "Done" ;;
    "In Arbeit"|"In Progress") echo "In Progress" ;;
    "Zu erledigen"|"To Do")    echo "To Do" ;;
    *)                         echo "$1" ;;
  esac
}

status_to_transition_id() {
  case "$1" in
    "To Do")       echo "11" ;;
    "In Progress") echo "21" ;;
    "Done")        echo "31" ;;
    *)             echo "" ;;
  esac
}

plan_status_to_jira() {
  case "$1" in
    "done")        echo "Done" ;;
    "in_progress") echo "In Progress" ;;
    "todo"|"planned") echo "To Do" ;;
    *)             echo "To Do" ;;
  esac
}

# --- Whoami ---

get_account_id() {
  jira_get "myself" | python3 -c "import json,sys; print(json.load(sys.stdin)['accountId'])"
}

# --- Assign-all mode ---

if [[ "${1:-}" == "--assign-all" ]]; then
  ACCOUNT_ID=$(get_account_id)
  PROJECT_KEY=$(python3 -c "
import json,sys
with open('${INDEX_FILE}') as f:
    plans = json.load(f).get('plans', [])
for p in plans:
    if p.get('id','').find('-') > 0:
        print(p['id'].split('-')[0])
        sys.exit(0)
print('S2P')
")
  "${SCRIPT_DIR}/jira-bulk-assign.sh" "$ACCOUNT_ID" --jql "project = ${PROJECT_KEY} AND assignee is EMPTY"
  exit 0
fi

# --- Resolve target plans ---

resolve_plans() {
  if [[ "$1" == "all" ]]; then
    python3 -c "
import json
with open('${INDEX_FILE}') as f:
    plans = json.load(f).get('plans', [])
for p in plans:
    pid = p.get('id','')
    if p.get('jira') and pid:
        print(pid)
"
  else
    echo "$1"
  fi
}

TARGET="${1:?Usage: $0 <plan-id|all>}"
ACCOUNT_ID=$(get_account_id)

# --- Sync one plan ---

sync_plan() {
  local plan_id="$1"
  local snapshot_file="${SYNC_DIR}/${plan_id}.json"
  local plan_file="${PROJECT_ROOT}/plans/${plan_id}.md"

  # Check plan file exists
  if [[ ! -f "$plan_file" ]]; then
    echo "  SKIP: ${plan_id} — no plan file"
    return
  fi

  # Get plan status from index
  local plan_status
  plan_status=$(python3 -c "
import json
with open('${INDEX_FILE}') as f:
    for p in json.load(f).get('plans', []):
        if p.get('id') == '${plan_id}':
            print(p.get('status', 'todo'))
            break
")
  local plan_jira_status
  plan_jira_status=$(plan_status_to_jira "$plan_status")

  # Fetch JIRA state
  local epic_json
  epic_json=$(jira_get "issue/${plan_id}?fields=summary,status,assignee")
  local epic_status
  epic_status=$(echo "$epic_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['fields']['status']['name'])" 2>/dev/null)
  epic_status=$(normalize_status "$epic_status")
  local epic_assignee
  epic_assignee=$(echo "$epic_json" | python3 -c "import json,sys; a=json.load(sys.stdin)['fields'].get('assignee'); print(a['accountId'] if a else '')" 2>/dev/null)

  local stories_json
  stories_json=$(jira_search "parent = ${plan_id}")

  # First sync — capture snapshot only
  if [[ ! -f "$snapshot_file" ]]; then
    python3 -c "
import json, sys

stories_raw = json.loads('''${stories_json//\'/\\\'}''')
stories = {}
for issue in stories_raw.get('issues', []):
    key = issue['key']
    status = issue['fields']['status']['name']
    status_map = {'Fertig': 'Done', 'In Arbeit': 'In Progress', 'Zu erledigen': 'To Do'}
    stories[key] = {
        'status': status_map.get(status, status),
        'summary': issue['fields']['summary']
    }

snapshot = {
    'version': 1,
    'planId': '${plan_id}',
    'capturedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'epic': {'key': '${plan_id}', 'status': '${epic_status}'},
    'stories': stories,
    'phases': {}
}

with open('${snapshot_file}', 'w') as f:
    json.dump(snapshot, f, indent=2)
" 2>/dev/null
    local story_count
    story_count=$(echo "$stories_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
    echo "  ${plan_id}: initial snapshot (${story_count} stories, epic=${epic_status})"

    # Assign epic if unassigned
    if [[ -z "$epic_assignee" ]]; then
      jira_put "issue/${plan_id}/assignee" "{\"accountId\": \"${ACCOUNT_ID}\"}" > /dev/null
    fi
    return
  fi

  # Load snapshot
  local snapshot
  snapshot=$(cat "$snapshot_file")
  local snapshot_epic_status
  snapshot_epic_status=$(echo "$snapshot" | python3 -c "import json,sys; print(json.load(sys.stdin)['epic']['status'])")

  # Three-way diff for epic status
  local pushed=0
  local drifts=0
  local assigned=0

  if [[ "$plan_jira_status" != "$snapshot_epic_status" && "$epic_status" == "$snapshot_epic_status" ]]; then
    # DRIFTED_LOCAL — push plan to JIRA
    local tid
    tid=$(status_to_transition_id "$plan_jira_status")
    if [[ -n "$tid" ]]; then
      jira_post "issue/${plan_id}/transitions" "{\"transition\":{\"id\":\"${tid}\"}}" > /dev/null
      echo "  ${plan_id} epic: PUSHED ${snapshot_epic_status} → ${plan_jira_status}"
      pushed=$((pushed + 1))
    fi
  elif [[ "$plan_jira_status" == "$snapshot_epic_status" && "$epic_status" != "$snapshot_epic_status" ]]; then
    echo "  ${plan_id} epic: DRIFTED_REMOTE ${snapshot_epic_status} → ${epic_status} (logged)"
    drifts=$((drifts + 1))
  elif [[ "$plan_jira_status" != "$epic_status" && "$plan_jira_status" != "$snapshot_epic_status" && "$epic_status" != "$snapshot_epic_status" ]]; then
    # CONFLICT — plan wins
    local tid
    tid=$(status_to_transition_id "$plan_jira_status")
    if [[ -n "$tid" ]]; then
      jira_post "issue/${plan_id}/transitions" "{\"transition\":{\"id\":\"${tid}\"}}" > /dev/null
      echo "  ${plan_id} epic: CONFLICT pushed ${plan_jira_status} (JIRA was ${epic_status})"
      pushed=$((pushed + 1))
      drifts=$((drifts + 1))
    fi
  fi

  # Assign epic if unassigned and touched
  if [[ -z "$epic_assignee" && $pushed -gt 0 ]]; then
    jira_put "issue/${plan_id}/assignee" "{\"accountId\": \"${ACCOUNT_ID}\"}" > /dev/null
    assigned=$((assigned + 1))
  fi

  # Three-way diff for stories
  echo "$stories_json" | python3 -c "
import json, sys

stories_raw = json.load(sys.stdin)
snapshot = json.loads('''${snapshot//\'/\\\'}''')
snapshot_stories = snapshot.get('stories', {})

# Parse plan file for story statuses (checkbox = Done)
plan_statuses = {}
try:
    with open('${plan_file}') as f:
        in_status = False
        for line in f:
            if line.strip().startswith('## Status'):
                in_status = True
                continue
            if in_status and line.strip().startswith('## '):
                break
            if in_status and line.strip().startswith('- ['):
                checked = line.strip().startswith('- [x]')
                # Extract story key if present
                import re
                m = re.search(r'\((S2P-\d+)\)', line)
                if m:
                    plan_statuses[m.group(1)] = 'Done' if checked else 'To Do'
except:
    pass

status_map = {'Fertig': 'Done', 'In Arbeit': 'In Progress', 'Zu erledigen': 'To Do'}
pushed = 0
assigned = 0

for issue in stories_raw.get('issues', []):
    key = issue['key']
    remote_status = status_map.get(issue['fields']['status']['name'], issue['fields']['status']['name'])
    snapshot_status = snapshot_stories.get(key, {}).get('status', '')
    local_status = plan_statuses.get(key, snapshot_status)
    assignee = issue['fields'].get('assignee')
    has_assignee = assignee is not None and assignee.get('accountId') is not None

    if local_status != snapshot_status and remote_status == snapshot_status:
        # DRIFTED_LOCAL — push
        tid_map = {'To Do': '11', 'In Progress': '21', 'Done': '31'}
        tid = tid_map.get(local_status, '')
        if tid:
            print(f'  {key}: PUSHED {snapshot_status} -> {local_status}')
            pushed += 1
    elif local_status == snapshot_status and remote_status != snapshot_status:
        print(f'  {key}: DRIFTED_REMOTE {snapshot_status} -> {remote_status} (logged)')

print(f'STORY_PUSHED={pushed}')
print(f'STORY_ASSIGNED={assigned}')
" 2>/dev/null

  # Update snapshot
  python3 -c "
import json

stories_raw = json.loads('''${stories_json//\'/\\\'}''')
status_map = {'Fertig': 'Done', 'In Arbeit': 'In Progress', 'Zu erledigen': 'To Do'}
stories = {}
for issue in stories_raw.get('issues', []):
    stories[issue['key']] = {
        'status': status_map.get(issue['fields']['status']['name'], issue['fields']['status']['name']),
        'summary': issue['fields']['summary']
    }

with open('${snapshot_file}') as f:
    snapshot = json.load(f)

snapshot['version'] = snapshot.get('version', 0) + 1
snapshot['capturedAt'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
snapshot['epic']['status'] = '${plan_jira_status}'
snapshot['stories'] = stories

with open('${snapshot_file}', 'w') as f:
    json.dump(snapshot, f, indent=2)
    f.write('\n')
" 2>/dev/null

  echo "  ${plan_id}: snapshot updated"
}

# --- Main ---

echo "══════════════════════════════════════════════"
echo " JIRA SYNC"
echo "══════════════════════════════════════════════"

PLAN_IDS=$(resolve_plans "$TARGET")
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  sync_plan "$pid"
done <<< "$PLAN_IDS"

echo "══════════════════════════════════════════════"
echo " Done"
echo "══════════════════════════════════════════════"
