#!/usr/bin/env bash
set -euo pipefail

# plan-tracker.sh - Track and update progress in plan.md files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"

sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed_inplace "$@"
    else
        sed -i "$@"
    fi
}

TASK_ID="${1:-}"
ACTION="${2:-}"
ITEM="${3:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <task-id> [action] [item]

Show and update progress in plan files.

Actions:
    (none)              Show full progress report
    --check <pattern>   Mark matching item(s) as done [x]
    --uncheck <pattern> Mark matching item(s) as not done [ ]
    --summary           Show summary statistics only
    --pending           List only pending items
    --agents            List items by agent

Examples:
    $(basename "$0") TASK-001
    $(basename "$0") TASK-001 --check "Implement domain"
    $(basename "$0") TASK-001 --pending
EOF
    exit 1
}

[[ -z "$TASK_ID" ]] && usage

PLAN_FILE="$AGENTS_DIR/plans/$TASK_ID.plan.md"

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Error: Plan file not found: $PLAN_FILE"
    exit 1
fi

show_progress() {
    echo "=== Progress: $TASK_ID ==="
    echo ""

    TOTAL=$(grep -c '^\s*- \[' "$PLAN_FILE" || echo 0)
    DONE=$(grep -c '^\s*- \[x\]' "$PLAN_FILE" || echo 0)
    PENDING=$((TOTAL - DONE))

    if [[ $TOTAL -gt 0 ]]; then
        PERCENT=$((DONE * 100 / TOTAL))
    else
        PERCENT=0
    fi

    BAR_WIDTH=40
    FILLED=$((PERCENT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))

    printf "["
    printf "%${FILLED}s" | tr ' ' '#'
    printf "%${EMPTY}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)\n" "$PERCENT" "$DONE" "$TOTAL"

    echo ""
    echo "Done:    $DONE"
    echo "Pending: $PENDING"
    echo ""

    echo "--- By Section ---"
    while IFS= read -r line; do
        if [[ "$line" =~ ^##\  ]]; then
            echo ""
            echo "${line#\#\# }"
        elif [[ "$line" =~ ^\s*-\ \[ ]]; then
            if [[ "$line" =~ \[x\] ]]; then
                STATUS="[x]"
            else
                STATUS="[ ]"
            fi
            ITEM_TEXT="${line#*] }"
            echo "  $STATUS $ITEM_TEXT"
        fi
    done < "$PLAN_FILE"
}

show_summary() {
    TOTAL=$(grep -c '^\s*- \[' "$PLAN_FILE" || echo 0)
    DONE=$(grep -c '^\s*- \[x\]' "$PLAN_FILE" || echo 0)

    if [[ $TOTAL -gt 0 ]]; then
        PERCENT=$((DONE * 100 / TOTAL))
    else
        PERCENT=0
    fi

    echo "$TASK_ID: $DONE/$TOTAL ($PERCENT%)"
}

show_pending() {
    echo "=== Pending Items: $TASK_ID ==="
    grep '^\s*- \[ \]' "$PLAN_FILE" | sed 's/^[[:space:]]*- \[ \] /  [ ] /'
}

show_by_agents() {
    echo "=== Items by Agent: $TASK_ID ==="

    for AGENT in "@backend-agent" "@frontend-agent" "@acceptance-agent" "@backend-validator" "@frontend-validator" "@dsl-validator"; do
        ITEMS=$(grep -A 20 "$AGENT" "$PLAN_FILE" | grep '^\s*- \[' | head -10 || true)
        if [[ -n "$ITEMS" ]]; then
            echo ""
            echo "--- ${AGENT#@} ---"
            echo "$ITEMS" | while read -r line; do
                if [[ "$line" =~ \[x\] ]]; then
                    STATUS="[x]"
                else
                    STATUS="[ ]"
                fi
                ITEM_TEXT="${line#*] }"
                echo "  $STATUS $ITEM_TEXT"
            done
        fi
    done
}

check_item() {
    [[ -z "$ITEM" ]] && usage

    # shellcheck disable=SC2016
    ESCAPED=$(printf '%s\n' "$ITEM" | sed 's/[[\.*^$()+?{|]/\\&/g')

    if grep -q "- \[ \].*$ESCAPED" "$PLAN_FILE"; then
        sed_inplace "s/- \[ \]\(.*$ESCAPED\)/- [x]\1/" "$PLAN_FILE"
        echo "Checked: $ITEM"
        show_summary
    else
        echo "No pending item matching: $ITEM"
        exit 1
    fi
}

uncheck_item() {
    [[ -z "$ITEM" ]] && usage

    # shellcheck disable=SC2016
    ESCAPED=$(printf '%s\n' "$ITEM" | sed 's/[[\.*^$()+?{|]/\\&/g')

    if grep -q "- \[x\].*$ESCAPED" "$PLAN_FILE"; then
        sed_inplace "s/- \[x\]\(.*$ESCAPED\)/- [ ]\1/" "$PLAN_FILE"
        echo "Unchecked: $ITEM"
        show_summary
    else
        echo "No checked item matching: $ITEM"
        exit 1
    fi
}

case "$ACTION" in
    "") show_progress ;;
    --summary) show_summary ;;
    --pending) show_pending ;;
    --agents) show_by_agents ;;
    --check) check_item ;;
    --uncheck) uncheck_item ;;
    *) usage ;;
esac
