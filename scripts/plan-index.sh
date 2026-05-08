#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INDEX_FILE="$PROJECT_ROOT/plans/index.json"

# Source error code library (fallback-safe for pre-scaffold environments)
# shellcheck source=lib/error-codes.sh
source "${SCRIPT_DIR}/lib/error-codes.sh" 2>/dev/null || true

ensure_jq() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed" >&2
        type cb_error_stderr &>/dev/null && cb_error_stderr "CB-S010"
        exit 1
    fi
}

ensure_index_exists() {
    if [[ ! -f "$INDEX_FILE" ]]; then
        mkdir -p "$(dirname "$INDEX_FILE")"
        echo '{"version":"1.0.0","plans":[]}' > "$INDEX_FILE"
    fi
}

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
            od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
    fi
}

iso_date() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

VALID_STATUSES="planned in_progress done unplanned"

validate_status() {
    local status="$1"
    for valid in $VALID_STATUSES; do
        if [[ "$status" == "$valid" ]]; then
            return 0
        fi
    done
    echo "Error: Invalid status '$status'. Must be one of: $VALID_STATUSES" >&2
    type cb_error_stderr &>/dev/null && cb_error_stderr "CB-P003"
    exit 1
}

cmd_add() {
    local title="$1"
    local file="$2"
    local status="${3:-planned}"
    local result_file="${4:-}"

    ensure_jq
    ensure_index_exists

    local id
    id=$(generate_uuid)
    local created_at
    created_at=$(iso_date)

    local new_plan
    if [[ -n "$result_file" ]]; then
        new_plan=$(jq -n \
            --arg id "$id" \
            --arg title "$title" \
            --arg file "$file" \
            --arg status "$status" \
            --arg createdAt "$created_at" \
            --arg resultFile "$result_file" \
            '{id: $id, title: $title, file: $file, status: $status, createdAt: $createdAt, completedAt: null, resultFile: $resultFile}')
    else
        new_plan=$(jq -n \
            --arg id "$id" \
            --arg title "$title" \
            --arg file "$file" \
            --arg status "$status" \
            --arg createdAt "$created_at" \
            '{id: $id, title: $title, file: $file, status: $status, createdAt: $createdAt, completedAt: null}')
    fi

    jq --argjson plan "$new_plan" '.plans += [$plan]' "$INDEX_FILE" > "$INDEX_FILE.tmp"
    mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo "$id"
}

cmd_update_status() {
    local id="$1"
    local status="$2"

    validate_status "$status"
    ensure_jq
    ensure_index_exists

    local completed_at="null"
    if [[ "$status" == "done" ]]; then
        completed_at="\"$(iso_date)\""
    fi

    jq --arg id "$id" \
       --arg status "$status" \
       --argjson completedAt "$completed_at" \
       '(.plans[] | select(.id == $id)) |= (
           .status = $status |
           if $completedAt != null then .completedAt = $completedAt else . end
       )' "$INDEX_FILE" > "$INDEX_FILE.tmp"
    mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo "Updated plan $id to status: $status"
}

cmd_find() {
    local title="$1"

    ensure_jq
    ensure_index_exists

    jq --arg title "$title" \
       '.plans[] | select(.title | ascii_downcase | contains($title | ascii_downcase))' \
       "$INDEX_FILE"
}

cmd_get() {
    local id="$1"

    ensure_jq
    ensure_index_exists

    local result
    result=$(jq --arg id "$id" '.plans[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$result" ]]; then
        echo "Error: No plan found with ID: $id" >&2
        type cb_error_stderr &>/dev/null && cb_error_stderr "CB-P002"
        exit 1
    fi

    echo "$result"
}

cmd_remove() {
    local id="$1"

    ensure_jq
    ensure_index_exists

    local exists
    exists=$(jq --arg id "$id" '[.plans[] | select(.id == $id)] | length' "$INDEX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo "Error: No plan found with ID: $id" >&2
        type cb_error_stderr &>/dev/null && cb_error_stderr "CB-P002"
        exit 1
    fi

    jq --arg id "$id" '.plans |= map(select(.id != $id))' "$INDEX_FILE" > "$INDEX_FILE.tmp"
    mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo "Removed plan $id"
}

cmd_list() {
    ensure_jq
    ensure_index_exists
    jq '.plans' "$INDEX_FILE"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [arguments]

Commands:
  add <title> <file> [status] [result_file]  Add plan to index
  get <id>                                   Get plan by ID
  update-status <id> <status>                Update plan status
  remove <id>                                Remove plan from index
  find <title>                               Find plan by partial title match
  list                                       List all plans as JSON

Status values: planned, in_progress, done, unplanned
EOF
    exit 1
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi

    local command="$1"
    shift

    case "$command" in
        add)
            if [[ $# -lt 2 ]]; then
                echo "Error: add requires title and file arguments" >&2
                usage
            fi
            cmd_add "$@"
            ;;
        get)
            if [[ $# -lt 1 ]]; then
                echo "Error: get requires id argument" >&2
                usage
            fi
            cmd_get "$@"
            ;;
        update-status)
            if [[ $# -lt 2 ]]; then
                echo "Error: update-status requires id and status arguments" >&2
                usage
            fi
            cmd_update_status "$@"
            ;;
        remove)
            if [[ $# -lt 1 ]]; then
                echo "Error: remove requires id argument" >&2
                usage
            fi
            cmd_remove "$@"
            ;;
        find)
            if [[ $# -lt 1 ]]; then
                echo "Error: find requires title argument" >&2
                usage
            fi
            cmd_find "$@"
            ;;
        list)
            cmd_list
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            usage
            ;;
    esac
}

main "$@"
