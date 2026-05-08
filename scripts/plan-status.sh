#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source error code library (fallback-safe for pre-scaffold environments)
# shellcheck source=lib/error-codes.sh
source "${SCRIPT_DIR}/lib/error-codes.sh" 2>/dev/null || true

usage() {
    cat <<EOF
Usage: $(basename "$0")

Display the status of all implementation plans grouped by status.

Shows a table with columns: ID (first 8 chars), Title, Created
Followed by a summary count of plans in each status.
EOF
    exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    type cb_error_stderr &>/dev/null && cb_error_stderr "CB-S010"
    exit 1
fi

plans_json=$("$SCRIPT_DIR/plan-index.sh" list)

plan_count=$(echo "$plans_json" | jq 'length')

if [[ "$plan_count" -eq 0 ]]; then
    echo "No plans found."
    exit 0
fi

print_group() {
    local status="$1"
    local label="$2"

    local group
    group=$(echo "$plans_json" | jq -r --arg s "$status" \
        '[.[] | select(.status == $s)] | sort_by(.createdAt) | reverse')

    local count
    count=$(echo "$group" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        return
    fi

    echo ""
    echo "=== $label ($count) ==="
    printf "%-10s %-50s %s\n" "ID" "Title" "Created"
    printf "%-10s %-50s %s\n" "--------" "--------------------------------------------------" "----------"

    echo "$group" | jq -r '.[] | [.id[0:8], .title, (.createdAt[0:10] // "unknown")] | @tsv' | \
        while IFS=$'\t' read -r id title created; do
            printf "%-10s %-50s %s\n" "$id" "$title" "$created"
        done
}

print_group "in_progress" "In Progress"
print_group "planned" "Planned"
print_group "done" "Done"
print_group "unplanned" "Unplanned"

in_progress=$(echo "$plans_json" | jq '[.[] | select(.status == "in_progress")] | length')
planned=$(echo "$plans_json" | jq '[.[] | select(.status == "planned")] | length')
done_count=$(echo "$plans_json" | jq '[.[] | select(.status == "done")] | length')
unplanned=$(echo "$plans_json" | jq '[.[] | select(.status == "unplanned")] | length')

echo ""
echo "Summary: $in_progress in progress, $planned planned, $done_count done, $unplanned unplanned"
