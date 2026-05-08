#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source error code library (fallback-safe for pre-scaffold environments)
# shellcheck source=lib/error-codes.sh
source "${SCRIPT_DIR}/lib/error-codes.sh" 2>/dev/null || true

usage() {
    cat <<EOF
Usage: $(basename "$0") <plan-id-or-title>

Mark an implementation plan as done.

Arguments:
  plan-id-or-title    UUID of the plan, or a title substring to search for

The plan must currently have status "planned" or "in_progress".
If a title is given and matches multiple plans, an error is shown.
EOF
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

input="$1"

is_uuid() {
    local val="$1"
    [[ ${#val} -eq 36 ]] && [[ "$val" =~ ^[0-9a-fA-F-]+$ ]]
}

if is_uuid "$input"; then
    plan=$("$SCRIPT_DIR/plan-index.sh" get "$input")
    id="$input"
else
    matches=$("$SCRIPT_DIR/plan-index.sh" find "$input")
    match_count=$(echo "$matches" | jq -s 'length')

    if [[ "$match_count" -eq 0 ]]; then
        echo "Error: No plan found matching title: $input" >&2
        type cb_error_stderr &>/dev/null && cb_error_stderr "CB-P002"
        exit 1
    fi

    if [[ "$match_count" -gt 1 ]]; then
        echo "Error: Multiple plans match title '$input':" >&2
        echo "$matches" | jq -s -r '.[] | "  \(.id[0:8])  \(.title)"' >&2
        type cb_error_stderr &>/dev/null && cb_error_stderr "CB-P002"
        exit 1
    fi

    plan=$(echo "$matches" | jq -s '.[0]')
    id=$(echo "$plan" | jq -r '.id')
fi

status=$(echo "$plan" | jq -r '.status')
title=$(echo "$plan" | jq -r '.title')

if [[ "$status" != "planned" && "$status" != "in_progress" ]]; then
    echo "Error: Plan '$title' has status '$status' — can only complete plans with status 'planned' or 'in_progress'" >&2
    exit 1
fi

"$SCRIPT_DIR/plan-index.sh" update-status "$id" "done" > /dev/null

echo "Completed: $title ($id)"
