#!/usr/bin/env bash
set -euo pipefail

# commit-preparer.sh - Prepare commits from experiment branches

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$AGENTS_DIR")"

sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed_inplace "$@"
    else
        sed -i "$@"
    fi
}

TASK_ID="${1:-}"
shift || true

EXPERIMENT=""
MODE="patch"
DRY_RUN=false
CUSTOM_MESSAGE=""

usage() {
    cat <<EOF
Usage: $(basename "$0") <task-id> --experiment <name> [options]

Prepare commits from an experiment branch to the main working branch.

Options:
    --experiment <name>   Experiment to prepare (e.g., experiment-a)
    --squash              Squash all commits into one
    --cherry-pick         Cherry-pick commits individually
    --patch               Create a patch file (default)
    --dry-run             Show what would be done without doing it
    --message <msg>       Custom commit message (for squash)

Examples:
    $(basename "$0") TASK-001 --experiment experiment-a
    $(basename "$0") TASK-001 --experiment experiment-a --squash
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --experiment) EXPERIMENT="$2"; shift 2 ;;
        --squash) MODE="squash"; shift ;;
        --cherry-pick) MODE="cherry-pick"; shift ;;
        --patch) MODE="patch"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --message) CUSTOM_MESSAGE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$TASK_ID" || -z "$EXPERIMENT" ]] && usage

EXPERIMENT_DIR="$AGENTS_DIR/playgrounds/$TASK_ID/$EXPERIMENT"
BRANCH_NAME="agents/$TASK_ID/$EXPERIMENT"
PLAN_FILE="$AGENTS_DIR/plans/$TASK_ID.plan.md"

if [[ ! -d "$EXPERIMENT_DIR" ]]; then
    echo "Error: Experiment directory not found: $EXPERIMENT_DIR"
    exit 1
fi

BASE_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

echo "=== Commit Preparation ==="
echo "Task:       $TASK_ID"
echo "Experiment: $EXPERIMENT"
echo "Mode:       $MODE"
echo "Base:       $BASE_BRANCH"
echo ""

cd "$EXPERIMENT_DIR"
COMMITS=$(git log --oneline "$BASE_BRANCH".."$BRANCH_NAME" 2>/dev/null || echo "")

if [[ -z "$COMMITS" ]]; then
    echo "No commits to prepare (experiment has no changes from base)"
    exit 0
fi

echo "Commits to prepare:"
echo "$COMMITS"
echo ""

echo "Changed files:"
git diff --stat "$BASE_BRANCH".."$BRANCH_NAME"
echo ""

if $DRY_RUN; then
    echo "[DRY RUN] Would prepare commits using mode: $MODE"
    exit 0
fi

case "$MODE" in
    patch)
        PATCH_FILE="$AGENTS_DIR/playgrounds/$TASK_ID/$EXPERIMENT.patch"
        echo "Creating patch file: $PATCH_FILE"
        git format-patch "$BASE_BRANCH".."$BRANCH_NAME" --stdout > "$PATCH_FILE"
        echo ""
        echo "To apply:"
        echo "  git am $PATCH_FILE"
        ;;
    squash)
        if [[ -z "$CUSTOM_MESSAGE" ]]; then
            if [[ -f "$PLAN_FILE" ]]; then
                GOAL=$(grep -A 5 "^## Goal" "$PLAN_FILE" | tail -n +2 | head -5 | sed '/^$/d' | head -1)
                CUSTOM_MESSAGE="$GOAL"
            else
                CUSTOM_MESSAGE="$TASK_ID: Changes from $EXPERIMENT"
            fi
        fi

        MSG_FILE="$AGENTS_DIR/playgrounds/$TASK_ID/$EXPERIMENT-commit-msg.txt"
        cat > "$MSG_FILE" <<EOF
$CUSTOM_MESSAGE

Task: $TASK_ID
Experiment: $EXPERIMENT

Changes:
$(git diff --stat "$BASE_BRANCH".."$BRANCH_NAME" | tail -1)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF

        echo "Commit message prepared: $MSG_FILE"
        echo ""
        cat "$MSG_FILE"
        echo ""
        echo "To apply squashed:"
        echo "  git checkout $BASE_BRANCH"
        echo "  git merge --squash $BRANCH_NAME"
        echo "  git commit -F $MSG_FILE"
        ;;
    cherry-pick)
        echo "Cherry-pick commands:"
        git log --oneline --reverse "$BASE_BRANCH".."$BRANCH_NAME" | while read -r HASH MSG; do
            echo "  git cherry-pick $HASH  # $MSG"
        done
        ;;
esac

if [[ -f "$PLAN_FILE" ]]; then
    sed_inplace 's/- \[ \] Commit prepared/- [x] Commit prepared/' "$PLAN_FILE" 2>/dev/null || true
    sed_inplace 's/- \[ \] Commit message drafted/- [x] Commit message drafted/' "$PLAN_FILE" 2>/dev/null || true
fi

echo ""
echo "=== Preparation Complete ==="
