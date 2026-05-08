#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") <snapshot-json> <local-json> <remote-json>

Perform field-level three-way merge on flat JSON objects.
Each argument is a path to a JSON file (or - for stdin on the first arg).

Output: JSON with fields array (classification + action per key) and summary counts.
EOF
    exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -ne 3 ]]; then
    usage
fi

read_json() {
    local path="$1"
    if [[ "$path" == "-" ]]; then
        cat
    else
        cat "$path"
    fi
}

snapshot_json=$(read_json "$1")
local_json=$(read_json "$2")
remote_json=$(read_json "$3")

snapshot_empty=$(echo "$snapshot_json" | jq 'length == 0')

jq -n \
    --argjson snapshot "$snapshot_json" \
    --argjson local "$local_json" \
    --argjson remote "$remote_json" \
    --argjson snapshot_empty "$snapshot_empty" \
'
def classify(snap; loc; rem; snap_empty):
    if snap_empty then
        { classification: "IN_SYNC", action: "none" }
    elif loc == snap and rem == snap then
        { classification: "IN_SYNC", action: "none" }
    elif loc == snap and rem != snap then
        { classification: "DRIFTED_REMOTE", action: "log" }
    elif loc != snap and rem == snap then
        { classification: "DRIFTED_LOCAL", action: "push" }
    elif loc == rem then
        { classification: "IN_SYNC", action: "none" }
    else
        { classification: "CONFLICT", action: "push_and_log" }
    end;

(
    ([$snapshot | keys[]] + [$local | keys[]] + [$remote | keys[]])
    | unique
) as $all_keys |

[
    $all_keys[] | . as $k |
    ($snapshot[$k] // null) as $snap |
    ($local[$k] // null) as $loc |
    ($remote[$k] // null) as $rem |
    classify($snap; $loc; $rem; $snapshot_empty) as $result |
    {
        key: $k,
        classification: $result.classification,
        snapshot: ($snap // "null" | if . == "null" and ($snap | . == null) then null else $snap end),
        local: ($loc // "null" | if . == "null" and ($loc | . == null) then null else $loc end),
        remote: ($rem // "null" | if . == "null" and ($rem | . == null) then null else $rem end),
        action: $result.action
    }
] as $fields |

{
    fields: $fields,
    summary: {
        inSync: ([$fields[] | select(.classification == "IN_SYNC")] | length),
        driftedLocal: ([$fields[] | select(.classification == "DRIFTED_LOCAL")] | length),
        driftedRemote: ([$fields[] | select(.classification == "DRIFTED_REMOTE")] | length),
        conflict: ([$fields[] | select(.classification == "CONFLICT")] | length)
    }
}
'
